data "aws_ssm_parameter" "api_gw" {
  name = "/digitalekanaler/common-services/microservices-api/api-id"
}

data "aws_ssm_parameter" "vpc_link_id" {
  name = "/digitalekanaler/common-services/microservices-api/vpc-link-id"
}

resource "aws_apigatewayv2_route" "this" {
  count     = var.remove_http_api_integration ? 0 : 1
  api_id    = data.aws_ssm_parameter.api_gw.value
  route_key = "ANY /services/${var.service_name}/{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.this[0].id}"
}

resource "aws_apigatewayv2_integration" "this" {
  count     = var.remove_http_api_integration ? 0 : 1
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
    "overwrite:path"        = "${var.context_path}/$request.path.proxy"
    "overwrite:header.host" = var.domain_name
  }
}


# Rest api gateway resources
data "aws_ssm_parameter" "rest_api_gw" {
  name = "/digitalekanaler/common-services/microservices-api/rest-api-id"
}

data "aws_api_gateway_resource" "services" {
  rest_api_id = data.aws_ssm_parameter.rest_api_gw.value
  path        = "/services"
}


resource "aws_api_gateway_resource" "service" {
  rest_api_id = data.aws_ssm_parameter.rest_api_gw.value
  parent_id   = data.aws_api_gateway_resource.services.id
  path_part   = var.service_name
}

resource "aws_api_gateway_resource" "service_proxy" {
  rest_api_id = data.aws_ssm_parameter.rest_api_gw.value
  parent_id   = aws_api_gateway_resource.service.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "service_any" {
  rest_api_id   = data.aws_ssm_parameter.rest_api_gw.value
  resource_id   = aws_api_gateway_resource.service_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy"  = true,
    "method.request.header.host" = true
  }
}

resource "aws_api_gateway_integration" "service" {
  rest_api_id = data.aws_ssm_parameter.rest_api_gw.value
  resource_id = aws_api_gateway_resource.service_proxy.id
  http_method = aws_api_gateway_method.service_any.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "https://${var.domain_name}/{proxy}"
  connection_type         = "VPC_LINK"
  connection_id           = data.aws_ssm_parameter.vpc_link_id.value

  request_parameters = {
    "integration.request.path.proxy"  = "method.request.path.proxy"
    "integration.request.header.host" = "'${var.domain_name}'"
  }
  integration_target = var.internal_alb_arn
}

resource "aws_api_gateway_deployment" "rest_apigw" {
  rest_api_id = data.aws_ssm_parameter.rest_api_gw.value

  triggers = {
    redeployment = sha1(jsonencode([
      data.aws_api_gateway_resource.services.id,
      aws_api_gateway_resource.service.id,
      aws_api_gateway_resource.service_proxy.id,
      aws_api_gateway_method.service_any.id,
      aws_api_gateway_integration.service.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "null_resource" "update_stage" {
  triggers = {
    deployment_id = aws_api_gateway_deployment.rest_apigw.id
  }

  provisioner "local-exec" {
    command = <<EOF
                if aws apigateway update-stage \
                  --rest-api-id ${data.aws_ssm_parameter.rest_api_gw.value} \
                  --stage-name rest_default \
                  --patch-operations op=replace,path=/deploymentId,value=${aws_api_gateway_deployment.rest_apigw.id} 2>&1; then
                  echo "SUCCESS: Stage 'rest_default' updated to deployment ID ${aws_api_gateway_deployment.rest_apigw.id}"
                else
                  echo "ERROR: Failed to update stage 'rest_default' to deployment ID ${aws_api_gateway_deployment.rest_apigw.id}" >&2
                  exit 1
                fi
                EOF
  }
}
