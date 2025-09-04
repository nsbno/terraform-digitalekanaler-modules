locals {
  shared_config        = nonsensitive(jsondecode(data.aws_ssm_parameter.shared_config.value))
  internal_domain_name = "${var.name}.${local.shared_config.internal_hosted_zone_name}"

  datadog_agent_cpu = 64
  log_router_cpu    = 64
  application_cpu   = var.cpu - local.datadog_agent_cpu - local.log_router_cpu

  name_with_prefix = var.name_prefix == "" ? var.name : "${var.name_prefix}-${var.name}"

  api_gateway_path = coalesce(var.custom_api_gateway_path, var.name)
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
  source             = "github.com/nsbno/terraform-aws-ecs-service?ref=725fe2b"
  depends_on         = [terraform_data.no_spot_in_prod]
  service_name       = local.name_with_prefix
  vpc_id             = local.shared_config.vpc_id
  private_subnet_ids = local.shared_config.private_subnet_ids
  cluster_id         = var.use_spot ? local.shared_config.ecs_spot_cluster_id : local.shared_config.ecs_cluster_id
  use_spot           = var.use_spot
  cpu                = var.cpu
  memory             = var.memory

  enable_datadog                  = var.disable_datadog_agent ? false : true
  datadog_instrumentation_runtime = "jvm" # Can be jvm or node
  team_name_override              = var.datadog_team_name

  datadog_api_key_secret_arn = data.aws_secretsmanager_secret.datadog_api_key.arn

  rollback_window_in_minutes = var.rollback_window_in_minutes

  wait_for_steady_state             = var.wait_for_steady_state
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  ecs_service_timeouts = {
    create = var.service_timeouts.create
    update = var.service_timeouts.update
    delete = var.service_timeouts.delete
  }

  application_container = {
    name           = local.name_with_prefix
    repository_url = var.repository_url
    port           = var.port
    protocol       = "HTTP"
    cpu            = local.application_cpu
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
        VY_DATADOG_AGENT_ENABLED = var.disable_datadog_agent ? "false" : "true"
      },
      var.environment_variables
    )

    secrets          = var.environment_secrets
    secrets_from_ssm = var.environment_secrets_from_ssm
  }

  deployment_minimum_healthy_percent = var.autoscaling.minimum_healthy_percent

  autoscaling = {
    min_capacity = var.autoscaling.min_number_of_instances
    max_capacity = var.autoscaling.max_number_of_instances
    metric_type  = length(var.custom_metrics) > 0 ? "" : var.autoscaling.metric_type
    target_value = tostring(var.autoscaling.target)
  }

  custom_metrics = var.custom_metrics

  lb_health_check = {
    port              = var.port
    path              = "/health"
    interval          = 30
    healthy_threshold = var.lb_healthy_threshold
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
        test_listener_arn = local.shared_config.lb_internal_test_listener_arn
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
  source       = "github.com/nsbno/terraform-digitalekanaler-modules//microservice-apigw-proxy?ref=0.0.2"
  service_name = local.api_gateway_path
  domain_name  = local.internal_domain_name
  listener_arn = local.shared_config.lb_internal_listener_arn
}


##########################################
#                                       #
# DATADOG                               #
#                                       #
##########################################

data "aws_secretsmanager_secret" "datadog_api_key" {
  name = "datadog/api-key"
}

data "aws_iam_policy_document" "secrets_manager" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      data.aws_secretsmanager_secret.datadog_api_key.arn,
    ]
  }
}

resource "aws_iam_role_policy" "secrets_manager" {
  role   = module.task.task_execution_role_name
  policy = data.aws_iam_policy_document.secrets_manager.json
}
