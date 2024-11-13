data "aws_ssm_parameter" "user_pool" {
  name = "/digitalekanaler/common-services/microservices-auth/pool-id"
}

resource "aws_cognito_user_pool_client" "this" {
  name                          = var.app_name
  user_pool_id                  = data.aws_ssm_parameter.user_pool.value
  generate_secret               = true
  prevent_user_existence_errors = "ENABLED"

  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
  explicit_auth_flows                  = []

  allowed_oauth_flows  = ["client_credentials"]
  allowed_oauth_scopes = var.oauth_scopes

  refresh_token_validity = var.refresh_token_validity
}
