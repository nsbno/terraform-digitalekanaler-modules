locals {
  name_prefix          = "digitalekanaler"
  shared_config        = nonsensitive(jsondecode(data.aws_ssm_parameter.shared_config.value))
  service_account_id   = "184465511165"
  internal_domain_name = "${var.name}.${local.shared_config.internal_hosted_zone_name}"
}

#########################################
#                                       #
# Fargate Task                          #
#                                       #
#########################################
module "task" {
  source             = "github.com/nsbno/terraform-aws-ecs-service?ref=0.12.1"
  application_name   = "${local.name_prefix}-${var.name}"
  vpc_id             = local.shared_config.vpc_id
  private_subnet_ids = local.shared_config.private_subnet_ids
  cluster_id         = local.shared_config.ecs_cluster_id

  cpu    = 2048
  memory = 4096

  application_container = {
    name     = "${local.name_prefix}-${var.name}"
    image    = var.docker_image
    port     = var.port
    protocol = "HTTP"
    cpu      = 0

    environment = merge(
      {
        DD_ENV               = var.datadog_tags.environment
        DD_SERVICE           = var.name
        DD_VERSION           = var.datadog_tags.version
        DD_LOGS_INJECTION    = "true"
        DD_TRACE_SAMPLE_RATE = "1"
        JAVA_TOOL_OPTIONS    = "-javaagent:/application/dd-java-agent.jar ${var.extra_java_tool_options}"
      },
      var.environment
    )

    secrets = var.secrets

    extra_options = {
      dockerLabels = {
        "com.datadoghq.tags.env"     = var.datadog_tags.environment
        "com.datadoghq.tags.service" = var.name
        "com.datadoghq.tags.version" = var.datadog_tags.version
      }
      logConfiguration = {
        logDriver = "awsfirelens",
        options = {
          Name       = "datadog",
          Host       = "http-intake.logs.datadoghq.eu",
          TLS        = "on"
          dd_service = var.name,
          dd_source  = "java",
          dd_tags    = "${var.name}:fluentbit",
          provider   = "ecs"
        }
        secretOptions = [{
          name      = "apikey",
          valueFrom = data.aws_ssm_parameter.datadog_apikey.arn
        }]
      }
    }
  }

  deployment_minimum_healthy_percent = 100
  autoscaling = {
    min_capacity = var.autoscaling.min_number_of_instances
    max_capacity = var.autoscaling.max_number_of_instances
    metric_type  = var.autoscaling.metric_type
    target_value = tostring(var.autoscaling.target)
  }

  sidecar_containers = [
    {
      name              = "datadog-agent"
      image             = "datadog/agent:latest"
      cpu               = 20
      memory_soft_limit = 256
      memory_hard_limit = 384

      environment = {
        DD_ENV                         = var.datadog_tags.environment
        DD_SERVICE                     = var.name
        ECS_FARGATE                    = "true"
        DD_SITE                        = "datadoghq.eu"
        DD_APM_ENABLED                 = "true"
        DD_APM_IGNORE_RESOURCES        = "/health"
        DD_DOGSTATSD_NON_LOCAL_TRAFFIC = "true"
        DD_CHECKS_TAG_CARDINALITY      = "orchestrator"
        DD_DOGSTATSD_TAG_CARDINALITY   = "orchestrator"
      }

      secrets = {
        DD_API_KEY = data.aws_ssm_parameter.datadog_apikey.arn,
      }

      extra_options = {
        mountPoints = []
        volumesFrom = []
        portMappings = [{
          containerPort = 8125
          hostPort      = 8125
          protocol      = "udp"
        }]
      }
    },
    {
      name              = "log-router"
      image             = nonsensitive(data.aws_ssm_parameter.log_router_image.value)
      essential         = true
      cpu               = 0
      memory_soft_limit = 100

      extra_options = {
        user        = "0"
        mountPoints = []
        volumesFrom = []
        firelensConfiguration = {
          type = "fluentbit"
          options = {
            "enable-ecs-log-metadata" = "true"
            "config-file-type"        = "file"
            "config-file-value"       = "/fluent-bit/configs/parse-json.conf"
          }
        }
      }
    }
  ]

  lb_health_check = {
    port = var.port
    path = "/health"
  }

  lb_listeners = [
    {
      listener_arn      = local.shared_config.lb_listener_arn
      security_group_id = local.shared_config.lb_security_group_id
      conditions = [
        { host_header = var.public_load_balancer_domain_name },
      ]
    },
    {
      listener_arn      = local.shared_config.lb_internal_listener_arn
      security_group_id = local.shared_config.lb_internal_security_group_id
      conditions = [
        { host_header = local.internal_domain_name },
      ]
    }
  ]

  propagate_tags = "TASK_DEFINITION"
}

#########################################
#                                       #
# Encryption key                        #
#                                       #
#########################################
resource "aws_kms_key" "application_key" {
  description = "Key for ${local.name_prefix}-${var.name}"
}

resource "aws_kms_alias" "application_key_alias" {
  name          = "alias/${local.name_prefix}-${var.name}"
  target_key_id = aws_kms_key.application_key.id
}

#########################################
#                                       #
# Internal load balancer integration    #
#                                       #
#########################################
resource "aws_route53_record" "internal_vydev_io_record" {
  zone_id = data.aws_route53_zone.internal_vydev_io_zone.id
  name    = local.internal_domain_name
  type    = "A"

  alias {
    evaluate_target_health = false
    name                   = data.aws_lb.internal_lb.dns_name
    zone_id                = data.aws_lb.internal_lb.zone_id
  }
}

module "api_gateway" {
  source       = "github.com/nsbno/terraform-digitalekanaler-modules?ref=0.0.2/microservice-apigw-proxy"
  service_name = var.name
  domain_name  = local.internal_domain_name
  listener_arn = local.shared_config.lb_internal_listener_arn
}