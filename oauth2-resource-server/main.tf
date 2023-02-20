data "aws_ssm_parameter" "user_pool" {
  name = "/digitalekanaler/common-services/microservices-m2m-auth/user-pool-id"
}

resource "aws_cognito_resource_server" "this" {
  identifier   = data.app_name
  name         = data.app_name
  user_pool_id = data.user_pool

  dynamic "scope" {
    for_each = var.oauth_scopes
    content {
      scope_name = scope.value["name"]
      scope_description = scope.value["description"]
    }
  }
}