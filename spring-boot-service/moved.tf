moved {
  from = module.api_gateway.aws_apigatewayv2_integration.this
  to   = module.api_gateway.aws_apigatewayv2_integration.this[0]
}

moved {
  from = module.api_gateway.aws_apigatewayv2_route.this
  to   = module.api_gateway.aws_apigatewayv2_route.this[0]
}
