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

  dynamic "token_validity_units" {
    # If null, return an empty list [], rendering the block 0 times.
    # If provided, return a list with one item, rendering the block 1 time.
    for_each = var.token_validity_units != null ? [var.token_validity_units] : []

    content {
      # 'token_validity_units.value' refers to the current item in the for_each loop
      access_token  = token_validity_units.value.access_token
      id_token      = token_validity_units.value.id_token
      refresh_token = token_validity_units.value.refresh_token
    }
  }
}
