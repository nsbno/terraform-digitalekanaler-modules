locals {
  name_prefix        = "digitalekanaler"
  shared_config      = nonsensitive(jsondecode(data.aws_ssm_parameter.shared_config.value))
  service_account_id = "184465511165"
  current_region     = data.aws_region.current.name
}

module "task" {
  source             = "github.com/nsbno/terraform-aws-ecs-service?ref=0.9.0"
  name_prefix        = "${local.name_prefix}-${var.name}"
  vpc_id             = local.shared_config.vpc_id
  private_subnet_ids = local.shared_config.private_subnet_ids
  cluster_id         = local.shared_config.ecs_cluster_id

  cpu    = 2048
  memory = 4096

  application_container = {
    name     = "${local.name_prefix}-${var.name}"
    image    = var.image
    port     = var.port
    protocol = "HTTP"
    cpu      = 0

    environment = merge({
      DD_ENV               = var.environment
      DD_SERVICE           = var.name
      DD_VERSION           = var.image
      DD_SERVICE_MAPPING   = "postgresql:ticket, kafka:ticket"
      DD_LOGS_INJECTION    = "true"
      DD_TRACE_SAMPLE_RATE = "1"

      JAVA_TOOL_OPTIONS = "-javaagent:/application/dd-java-agent.jar -XX:FlightRecorderOptions=stackdepth=256 -Xmx1024m -Xms1024m"
    }, var.environment_variables)

    secrets = var.secrets

    extra_options = {
      dockerLabels = {
        "com.datadoghq.tags.env"     = var.environment
        "com.datadoghq.tags.service" = var.name
        "com.datadoghq.tags.version" = var.image
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
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
    metric_type  = "ECSServiceAverageCPUUtilization"
    target_value = "50"
  }

  sidecar_containers = [
    {
      name              = "datadog-agent"
      image             = "datadog/agent:latest"
      cpu               = 20
      memory_soft_limit = 256
      memory_hard_limit = 384

      environment = {
        DD_ENV                         = var.environment
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
      image             = data.aws_ssm_parameter.log_router_image.value
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
        { host_header = var.external_domain_name },
      ]
    },
    {
      listener_arn      = local.shared_config.lb_internal_listener_arn
      security_group_id = local.shared_config.lb_internal_security_group_id
      conditions = [
        { host_header = var.internal_domain_name },
      ]
    }
  ]

  propagate_tags = "TASK_DEFINITION"
}

resource "aws_ssm_parameter" "manuel_environment_secrets" {
  for_each = var.manual_environment_secrets

  name  = each.value
  type  = "SecureString"
  value = "null"

  key_id = var.key_id

  lifecycle {
    ignore_changes = [value]
  }

}
