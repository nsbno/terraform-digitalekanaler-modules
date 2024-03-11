locals {
  ecr_repository_name = var.ecr_repository_name == null ? var.application_name : var.ecr_repository_name
}

module "apprunner" {
  source      = "github.com/nsbno/terraform-aws-apprunner-service?ref=1.0.0"
  name_prefix = var.application_name

  auto_deployment  = true
  application_port = tostring(var.application_port)

  vpc_config = {
    subnet_ids      = toset(data.aws_subnets.private.ids)
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

# TODO: Fix when new aws account is avalible
data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Tier = "Private"
  }
}

data "aws_ecr_repository" "ecr" {
  name = var.ecr_repository_name
}

resource "aws_security_group" "apprunner_security_group" {
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "allow_all_outgoing_traffic_from_apprunner" {
  security_group_id = aws_security_group.apprunner_security_group.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
