data "aws_region" "current" {}

data "aws_kms_alias" "common_config_key" {
  name = "alias/common_config_key"
}

data "aws_ssm_parameter" "shared_config" {
  name = "/digitalekanaler/shared-config"
}

data "aws_ssm_parameter" "datadog_apikey" {
  name = "/external/datadog/apikey"
}

data "aws_ssm_parameter" "log_router_image" {
  name = "/aws/service/aws-for-fluent-bit/stable"
}

data "aws_ssm_parameter" "external_environment_secrets" {
  for_each = var.external_environment_secrets
  name     = each.value
}
