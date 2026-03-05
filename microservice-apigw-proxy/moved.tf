moved {
  from = aws_apigatewayv2_route.this
  to   = aws_apigatewayv2_route.this[0]
}

moved {
  from = aws_apigatewayv2_integration.this
  to   = aws_apigatewayv2_integration.this[0]
}
