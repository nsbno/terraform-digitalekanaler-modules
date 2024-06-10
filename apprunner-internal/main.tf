terraform {
  required_version = ">= 1.4.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.39.1"
    }
    vy = {
      source  = "nsbno/vy"
      version = "0.4.0"
    }
  }
}

locals {
  zone        = var.environment == "prod" ? "digital-common-services.vydev.io" : "${var.environment}.digital-common-services.vydev.io"
  domain_name = "${var.application_name}.${local.zone}"
  docker_image = "${data.vy_artifact_version.ecr.store}/${data.vy_artifact_version.ecr.path}@${data.vy_artifact_version.ecr.version}"
}


##################################
#                                #
# AppRunner service              #
#                                #
##################################

resource "aws_apprunner_service" "service" {
  depends_on = [ aws_iam_role.ecr_access_role ]
  service_name = var.application_name

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.ecr_access_role.arn
    }
    image_repository {
      image_identifier      = local.docker_image
      image_repository_type = "ECR"
      image_configuration {
        port                          = var.application_port
        runtime_environment_variables = var.environment_variables
        runtime_environment_secrets   = var.environment_secrets
      }
    }
    auto_deployments_enabled = false
  }

  instance_configuration {
    cpu               = var.cpu
    memory            = var.memory
    instance_role_arn = aws_iam_role.task_role.arn
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.autoscaling.arn

  network_configuration {
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.service.arn
    }
  }
}

data "vy_artifact_version" "ecr" {
  application = "${var.name_prefix}-${var.application_name}"
}

data "aws_ecr_image" "ecr" {
  repository_name = var.ecr_repository_name
  registry_id     = var.service_account_id
  image_digest    = data.vy_artifact_version.ecr.version
}

data "aws_vpc" "shared" {
  tags = {
    Name = "shared"
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }
  tags = {
    Tier = "Private"
    Name = "shared-private"
  }
}

resource "aws_security_group" "apprunner_security_group" {
  name   = "${var.application_name}-sg"
  vpc_id = data.aws_vpc.shared.id
}

resource "aws_apprunner_vpc_connector" "service" {
  vpc_connector_name = var.application_name
  subnets            = data.aws_subnets.private_subnets.ids
  security_groups    = [aws_security_group.apprunner_security_group.id]
}

resource "aws_apprunner_auto_scaling_configuration_version" "autoscaling" {
  auto_scaling_configuration_name = "limited-scaling"
  max_concurrency                 = var.auto_scaling.max_concurrency
  min_size                        = var.auto_scaling.min_instances
  max_size                        = var.auto_scaling.max_instances
}


##################################
#                                #
# Task role                      #
#                                #
##################################

resource "aws_iam_role" "task_role" {
  name               = "${var.application_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json
}

data "aws_iam_policy_document" "task_assume_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["tasks.apprunner.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}


##################################
#                                #
# Access role                    #
#                                #
##################################

resource "aws_iam_role" "ecr_access_role" {
  name               = "${var.application_name}-access-role"
  assume_role_policy = data.aws_iam_policy_document.access_assume_policy.json
}

data "aws_iam_policy_document" "access_assume_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["build.apprunner.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "access_policy" {
  statement {
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
    ]
    resources = [data.aws_ecr_repository.ecr.arn]
  }
  statement {
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "access_policy" {
  name   = "${var.application_name}-access-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.access_policy.json
}

resource "aws_iam_role_policy_attachment" "access_role_policy_attachment" {
  role       = aws_iam_role.ecr_access_role.name
  policy_arn = aws_iam_policy.access_policy.arn
}

##################################
#                                #
# Custom domain name             #
#                                #
##################################

data "aws_route53_zone" "zone" {
  name = local.zone
}

resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = local.domain_name
  type    = "CNAME"
  ttl     = 300
  records = [aws_apprunner_service.service.service_url]
}

resource "aws_apprunner_custom_domain_association" "service" {
  domain_name          = aws_route53_record.record.name
  service_arn          = aws_apprunner_service.service.arn
  enable_www_subdomain = false
}

# ugly workaround to make terraform evaluate the length at runtime and not at plan time, since the records don't exist before then. ugh.
resource "aws_route53_record" "validation" {
  name    = tolist(aws_apprunner_custom_domain_association.service.certificate_validation_records)[0].name
  type    = tolist(aws_apprunner_custom_domain_association.service.certificate_validation_records)[0].type
  zone_id = data.aws_route53_zone.zone.zone_id
  records = [tolist(aws_apprunner_custom_domain_association.service.certificate_validation_records)[0].value]
  ttl     = 3600
}
