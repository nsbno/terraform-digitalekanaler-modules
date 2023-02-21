data "aws_ssm_parameter" "user_pool" {
  name = "/digitalekanaler/common-services/microservices-auth/pool-id"
}

data "aws_kms_key" "application_key" {
  key_id = var.kms_key
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
}

resource "aws_ssm_parameter" "client_id" {
  count = local.should_add_secret_to_secrets_manager
  name  = "/config/${var.app_name}/oauth2/clientId"
  type  = "String"

  value = aws_cognito_user_pool_client.this.id
}

resource "aws_ssm_parameter" "client_secret" {
  count = local.should_add_secret_to_secrets_manager
  name  = "/config/${var.app_name}/oath2/clientSecret"
  type  = "SecureString"
  key_id = data.aws_kms_key.application_key.id
  value = aws_cognito_user_pool_client.this.client_secret
}

locals {
  should_add_secret_to_secrets_manager = var.store_credentials ? 1 : 0
}
