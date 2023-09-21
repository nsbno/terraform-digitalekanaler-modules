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

data "aws_lb" "internal_lb" {
  arn = local.shared_config.lb_internal_arn
}

data "aws_route53_zone" "internal_vydev_io_zone" {
  name         = local.shared_config.internal_hosted_zone_name
  private_zone = true
}
