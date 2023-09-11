data "aws_ssm_parameter" "shared_config" {
  name = "/digitalekanaler/shared-config"
}

data "aws_region" "current" {}

data "aws_ssm_parameter" "datadog_apikey" {
  name = "/external/datadog/apikey"
}

data "aws_ssm_parameter" "log_router_image" {
  name = "/aws/service/aws-for-fluent-bit/stable"
}
