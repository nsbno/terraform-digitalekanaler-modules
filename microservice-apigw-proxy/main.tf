data "aws_ssm_parameter" "api_gw" {
  name = "/digitalekanaler/common-services/microservices-api/api-id"
}

data "aws_ssm_parameter" "vpc_link_id" {
  name = "/digitalekanaler/common-services/microservices-api/vpc-link-id"
}

resource "aws_apigatewayv2_route" "this" {
  api_id    = data.aws_ssm_parameter.api_gw.value
  route_key = "ANY /services/${var.service_name}/{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_apigatewayv2_integration" "this" {
  api_id = data.aws_ssm_parameter.api_gw.value

  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.listener_arn

  connection_type = "VPC_LINK"
  connection_id   = data.aws_ssm_parameter.vpc_link_id.value

  tls_config {
    server_name_to_verify = var.domain_name
  }

  request_parameters = {
    "overwrite:path"        = "/$request.path.proxy"
    "overwrite:header.host" = var.domain_name
  }
}
