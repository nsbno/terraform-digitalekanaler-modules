data "aws_ssm_parameter" "api_gw" {
  name = "/digitalekanaler/common-services/microservices-api/api-id"
}

resource "aws_apigatewayv2_route" "this" {
  api_id    = nonsensitive(data.aws_ssm_parameter.api_gw.value)
  route_key = "ANY /services/${var.service_name}/{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_apigatewayv2_integration" "this" {
  api_id = nonsensitive(data.aws_ssm_parameter.api_gw.value)

  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = "https://${var.domain_name}"

  request_parameters = {
    "overwrite:path"        = "${var.context_path}/$request.path.proxy"
    "overwrite:header.host" = var.domain_name
  }
}
