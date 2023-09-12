locals {
  name_prefix          = "digitalekanaler"
  shared_config        = nonsensitive(jsondecode(data.aws_ssm_parameter.shared_config.value))
  service_account_id   = "184465511165"
  current_region       = data.aws_region.current.name
  internal_domain_name = "${var.name}.${local.shared_config.internal_hosted_zone_name}"

  all_environment_secrets = merge(
    aws_ssm_parameter.environment_secrets,
    aws_ssm_parameter.manual_environment_secrets,
    data.aws_ssm_parameter.external_environment_secrets,
  )

  image_tag = (
    aws_ssm_parameter.version.value == "latest"
    ? aws_ssm_parameter.version.value
    : "${aws_ssm_parameter.version.value}-SHA1"
  )
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
    image    = local.image_tag
    port     = var.port
    protocol = "HTTP"
    cpu      = 0

    environment = merge(
      {
        DD_ENV               = var.environment
        DD_SERVICE           = var.name
        DD_VERSION           = local.image_tag
        DD_SERVICE_MAPPING   = "postgresql:ticket, kafka:ticket"
        DD_LOGS_INJECTION    = "true"
        DD_TRACE_SAMPLE_RATE = "1"
        JAVA_TOOL_OPTIONS    = "-javaagent:/application/dd-java-agent.jar -XX:FlightRecorderOptions=stackdepth=256 -Xmx1024m -Xms1024m"
      },
      var.environment_variables
    )

    secrets = { for name, param in local.all_environment_secrets : name => param.arn }

    extra_options = {
      dockerLabels = {
        "com.datadoghq.tags.env"     = var.environment
        "com.datadoghq.tags.service" = var.name
        "com.datadoghq.tags.version" = local.image_tag
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
        { host_header = local.internal_domain_name },
      ]
    }
  ]

  propagate_tags = "TASK_DEFINITION"
}

resource "aws_ssm_parameter" "environment_secrets" {
  for_each = var.environment_secrets

  name   = "/config/${var.name}/${each.key}"
  type   = "SecureString"
  value  = each.value
  key_id = aws_kms_key.application_key.id
}

resource "aws_ssm_parameter" "manual_environment_secrets" {
  for_each = var.manual_environment_secrets

  name   = each.value
  type   = "SecureString"
  value  = "null"
  key_id = aws_kms_key.application_key.id

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_kms_key" "application_key" {
  description = "Key for ${local.name_prefix}-${var.name}"
}

data "aws_iam_policy_document" "task_execution_role" {
  statement {
    actions   = ["ssm:GetParameters"]
    resources = [for _, param in local.all_environment_secrets : param.arn]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.application_key.arn, data.aws_kms_alias.common_config_key.target_key_arn]
  }

  # TODO: What is this?
  statement {
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "task_execution_role" {
  name   = "${local.name_prefix}-${var.name}-ecs-task-policy"
  policy = data.aws_iam_policy_document.task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "task_execution_role" {
  role       = module.task.task_execution_role_name
  policy_arn = aws_iam_policy.task_execution_role.arn
}

module "api_gateway" {
  source       = "github.com/nsbno/terraform-digitalekanaler-modules?ref=0.0.2/microservice-apigw-proxy"
  service_name = var.name
  domain_name  = local.internal_domain_name
  listener_arn = local.shared_config.lb_internal_listener_arn
}


resource "aws_ssm_parameter" "version" {
  name      = "/${local.name_prefix}/versions/${local.name_prefix}-${var.name}"
  value     = "latest"
  type      = "String"
  overwrite = true
  lifecycle {
    ignore_changes = [value]
  }
}
