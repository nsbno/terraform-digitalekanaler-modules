data "aws_iam_policy_document" "apprunner_policy_document" {
  statement {
    actions = ["ssm:GetParameters"]

    resources = [
      aws_ssm_parameter.rds_username.arn,
      aws_ssm_parameter.rds_password.arn
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
  role       = var.task_role_name
  policy_arn = aws_iam_policy.apprunner_policy.arn
}
