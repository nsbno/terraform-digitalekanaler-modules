locals {
  shared_config = nonsensitive(jsondecode(data.aws_ssm_parameter.shared_config.value))
  vpc_id          = nonsensitive(local.shared_config.vpc_id)
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

  environment_variables = var.environment_variables

  environment_secrets = var.environment_secrets

  ecr_arn = data.aws_ecr_repository.ecr.arn
  ecr_url = data.aws_ecr_repository.ecr.repository_url

  domain_name = {
    name = "${var.application_name}.vylabs.io"
    zone = "vylabs.io"
  }
}

data "aws_ecr_repository" "ecr" {
  name = "${var.name_prefix}-${var.application_name}"
}

resource "aws_security_group" "apprunner_security_group" {
  vpc_id = local.vpc_id
}

resource "aws_security_group_rule" "allow_all_outgoing_traffic_from_apprunner" {
  security_group_id = aws_security_group.apprunner_security_group.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
