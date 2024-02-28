resource "aws_kms_key" "application_key" {
  description = "Key for ${var.name_prefix}-${var.application_name} secrets in parameter store"
}

data "aws_iam_policy_document" "apprunner_policy_document" {
  statement {
    actions = ["ssm:GetParameters"]

    resources = [
      aws_ssm_parameter.github_app_id.arn,
      aws_ssm_parameter.github_client_id.arn,
      aws_ssm_parameter.github_client_secret.arn,
      aws_ssm_parameter.github_private_key_content.arn,
      aws_ssm_parameter.circleci_auth_token.arn,
      aws_ssm_parameter.backend_secret.arn
    ]
  }
  statement {
    actions = ["kms:Decrypt"]

    resources = [
      aws_kms_key.application_key.arn
    ]
  }
}

resource "aws_iam_policy" "apprunner_policy" {
  name   = "${var.name_prefix}-${var.application_name}-task-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.apprunner_policy_document.json
}

resource "aws_iam_role_policy_attachment" "apprunner_role_policy_attachment" {
  role       = module.apprunner.task_role_name
  policy_arn = aws_iam_policy.apprunner_policy.arn
}

resource "aws_ssm_parameter" "github_app_id" {
  name  = "/config/${var.application_name}/github_app_id"
  type  = "String"
  value = "null"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "github_client_id" {
  name  = "/config/${var.application_name}/github_client_id"
  type  = "String"
  value = "null"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "github_client_secret" {
  name   = "/config/${var.application_name}/github_client_secret"
  type   = "SecureString"
  value  = "null"
  key_id = aws_kms_key.application_key.id

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "github_private_key_content" {
  name   = "/config/${var.application_name}/github_private_key_content"
  type   = "SecureString"
  value  = "null"
  key_id = aws_kms_key.application_key.id

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "circleci_auth_token" {
  name   = "/config/${var.application_name}/circleci_auth_token"
  type   = "SecureString"
  value  = "null"
  key_id = aws_kms_key.application_key.id

  lifecycle {
    ignore_changes = [value]
  }
}

resource "random_password" "backend_secret" {
  length = 32
}

resource "aws_ssm_parameter" "backend_secret" {
  name   = "/config/${var.application_name}/backend_secret"
  type   = "SecureString"
  value  = random_password.backend_secret.result
  key_id = aws_kms_key.application_key.id
}
