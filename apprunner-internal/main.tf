locals {
  shared_config = nonsensitive(jsondecode(data.aws_ssm_parameter.shared_config.value))
  subnet_ids      = nonsensitive(local.shared_config.private_subnet_ids)
}

module "apprunner" {
  source      = "github.com/nsbno/terraform-aws-apprunner-service?ref=1.0.0"
  name_prefix = "${var.name_prefix}-${var.application_name}"

  auto_deployment  = true
  application_port = "${var.app_port}"

  vpc_config = {
    subnet_ids      = local.subnet_ids
    security_groups = [aws_security_group.apprunner_security_group.id]
  }

  environment_variables = {
    POSTGRES_HOST                = module.database.endpoint
    POSTGRES_PORT                = module.database.port
    RAILYARD_ARTIFACTS_S3_BUCKET = aws_s3_bucket.railyard-artifacts.bucket
    LOG_LEVEL                    = "debug"
  }

  environment_secrets = {
    POSTGRES_USER              = aws_ssm_parameter.rds_username.arn
    GITHUB_APP_ID              = aws_ssm_parameter.github_app_id.arn
    GITHUB_CLIENT_ID           = aws_ssm_parameter.github_client_id.arn
    POSTGRES_PASSWORD          = aws_ssm_parameter.rds_password.arn
    GITHUB_CLIENT_SECRET       = aws_ssm_parameter.github_client_secret.arn
    GITHUB_PRIVATE_KEY_CONTENT = aws_ssm_parameter.github_private_key_content.arn
    CIRCLECI_AUTH_TOKEN        = aws_ssm_parameter.circleci_auth_token.arn
    BACKEND_SECRET             = aws_ssm_parameter.backend_secret.arn
  }

  ecr_arn = data.aws_ecr_repository.ecr.arn
  ecr_url = data.aws_ecr_repository.ecr.repository_url

  domain_name = {
    name = "railyard.vylabs.io"
    zone = "vylabs.io"
  }
}
