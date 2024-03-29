data "aws_ssm_parameter" "user_pool" {
  name = "/digitalekanaler/common-services/microservices-auth/pool-id"
}

resource "aws_cognito_resource_server" "this" {
  name         = var.resource_name
  identifier   = var.resource_identifier
  user_pool_id = data.aws_ssm_parameter.user_pool.value

  dynamic "scope" {
    for_each = var.oauth_scopes
    content {
      scope_name = scope.value["name"]
      scope_description = scope.value["description"]
    }
  }
}
