locals {
  shared_config        = nonsensitive(jsondecode(data.aws_ssm_parameter.shared_config.value))
  internal_domain_name = "${var.name}.${local.shared_config.internal_hosted_zone_name}"

  datadog_agent_cpu         = 64
  log_router_cpu            = 64
  application_cpu           = var.cpu - local.datadog_agent_cpu - local.log_router_cpu
  datadog_agent_soft_memory = 256
  log_router_soft_memory    = 100

  name_with_prefix = var.name_prefix == "" ? var.name : "${var.name_prefix}-${var.name}"

  api_gateway_path = coalesce(var.custom_api_gateway_path, var.name)

  datadog_agent_sidecar_container = {
    name              = "datadog-agent"
    image             = "datadog/agent:latest"
    cpu               = local.datadog_agent_cpu
    memory_soft_limit = local.datadog_agent_soft_memory

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
      DD_CMD_PORT                    = tostring(var.datadog_agent_cmd_port)
    }

    secrets = {
      DD_API_KEY = data.aws_ssm_parameter.datadog_apikey.arn,
    }

    extra_options = {
      mountPoints    = []
      volumesFrom    = []
      systemControls = []
    }

    health_check = {
      retries : 3,
      timeout : 5,
      interval : 10,
      startPeriod : 15
      command = [
        "CMD-SHELL",
        "agent health"
      ]
    }
  }

  log_router_sidecar_container = {
    name              = "log-router"
    image             = nonsensitive(data.aws_ssm_parameter.log_router_image.value)
    essential         = false
    cpu               = local.log_router_cpu
    memory_soft_limit = local.log_router_soft_memory

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
      systemControls = []
    }
  }
}

#########################################
#                                       #
# Fargate Task                          #
#                                       #
#########################################

resource "terraform_data" "no_spot_in_prod" {
  lifecycle {
    precondition {
      condition     = var.use_spot == false || var.environment != "prod"
      error_message = "You can not use spot instances in prod."
    }
  }
}

module "task" {
  source             = "github.com/nsbno/terraform-aws-ecs-service?ref=0.14.4"
  depends_on         = [terraform_data.no_spot_in_prod]
  application_name   = local.name_with_prefix
  vpc_id             = local.shared_config.vpc_id
  private_subnet_ids = local.shared_config.private_subnet_ids
  cluster_id         = var.use_spot ? local.shared_config.ecs_spot_cluster_id : local.shared_config.ecs_cluster_id
  use_spot           = var.use_spot
  cpu                = var.cpu
  memory             = var.memory

  wait_for_steady_state             = var.wait_for_steady_state
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  ecs_service_timeouts = {
    create = var.service_timeouts.create
    update = var.service_timeouts.update
    delete = var.service_timeouts.delete
  }

  application_container = {
    name     = local.name_with_prefix
    image    = var.docker_image
    port     = var.port
    protocol = "HTTP"
    cpu      = local.application_cpu
    health_check = var.health_check_override == null ? null : {
      retries : 5,
      command : [
        "CMD-SHELL",
        "wget --no-verbose --tries=1 --spider http://localhost:${var.port}/health || exit 1"
      ],
      timeout : var.health_check_override.timeout,
      interval : var.health_check_override.interval,
      startPeriod : try(var.health_check_override.startPeriod, null)
    }

    environment = merge(
      {
        DD_ENV               = var.datadog_tags.environment
        DD_SERVICE           = var.name
        DD_VERSION           = var.datadog_tags.version
        DD_LOGS_INJECTION    = "true"
        DD_TRACE_SAMPLE_RATE = "1"

        JAVA_TOOL_OPTIONS = var.disable_datadog_agent ? var.extra_java_tool_options : "-javaagent:/application/dd-java-agent.jar ${var.extra_java_tool_options}"

        VY_DATADOG_AGENT_ENABLED = var.disable_datadog_agent ? "false" : "true"
      },
      var.environment_variables
    )

    secrets = var.environment_secrets

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
      mountPoints    = []
      volumesFrom    = []
      systemControls = []
    }
  }

  deployment_minimum_healthy_percent = var.autoscaling.minimum_healthy_percent

  autoscaling = {
    min_capacity = var.autoscaling.min_number_of_instances
    max_capacity = var.autoscaling.max_number_of_instances
    metric_type  = length(var.custom_metrics) > 0 ? "" : var.autoscaling.metric_type
    target_value = tostring(var.autoscaling.target)
  }

  custom_metrics = var.custom_metrics

  sidecar_containers = concat(
    var.disable_datadog_agent ? [] : [local.datadog_agent_sidecar_container],
    [local.log_router_sidecar_container],
  )

  lb_health_check = {
    port              = var.port
    path              = "/health"
    interval          = 10
    healthy_threshold = 2
  }
  lb_deregistration_delay = var.lb_deregistration_delay

  lb_listeners = concat(
    var.deprecated_public_domain_name == null ? [] : [
      {
        listener_arn      = local.shared_config.lb_listener_arn
        security_group_id = local.shared_config.lb_security_group_id
        conditions = [
          { host_header = var.deprecated_public_domain_name },
        ]
      },
    ],
    [
      {
        listener_arn      = local.shared_config.lb_internal_listener_arn
        security_group_id = local.shared_config.lb_internal_security_group_id
        conditions = [
          { host_header = local.internal_domain_name },
        ]
      }
    ]
  )

  propagate_tags = "TASK_DEFINITION"

  lb_stickiness = var.lb_stickiness
}

#########################################
#                                       #
# Encryption key                        #
#                                       #
#########################################
resource "aws_kms_key" "application_key" {
  description = "Key for ${local.name_with_prefix}"
}

resource "aws_kms_alias" "application_key_alias" {
  name          = "alias/${local.name_with_prefix}"
  target_key_id = aws_kms_key.application_key.id
}

data "aws_kms_alias" "common_config_key" {
  name = "alias/common_config_key"
}

#########################################
#                                       #
# Policy to read secrets                #
#                                       #
#########################################

data "aws_iam_policy_document" "fargate_task_policy_document" {
  statement {
    actions = ["ssm:GetParameters"]

    resources = concat(values(var.environment_secrets), [data.aws_ssm_parameter.datadog_apikey.arn])
  }
  statement {
    actions = ["kms:Decrypt"]

    resources = [
      aws_kms_key.application_key.arn,
      data.aws_kms_alias.common_config_key.target_key_arn,
    ]
  }
}

resource "aws_iam_policy" "fargate_task_policy" {
  name        = "${local.name_with_prefix}-fargate-task-policy"
  description = "Policy for ${local.name_with_prefix} to read secrets"
  policy      = data.aws_iam_policy_document.fargate_task_policy_document.json
}

resource "aws_iam_role_policy_attachment" "fargate_task_policy_attachment" {
  role       = module.task.task_execution_role_name
  policy_arn = aws_iam_policy.fargate_task_policy.arn
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
  service_name = local.api_gateway_path
  domain_name  = local.internal_domain_name
  listener_arn = local.shared_config.lb_internal_listener_arn
}
