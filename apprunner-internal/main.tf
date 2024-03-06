locals {
  use_vpc_connector = (length(var.vpc_config.subnet_ids) > 0 && length(var.vpc_config.security_groups) > 0)
}


##################################
#                                #
# AppRunner service              #
#                                #
##################################

resource "aws_apprunner_service" "service" {
  service_name = var.name_prefix

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.ecr_access_role.arn
    }
    image_repository {
      image_identifier      = "${aws_ecr_repository.ecr.repository_url}:${var.image_tag}"
      image_repository_type = "ECR"
      image_configuration {
        port                          = var.application_port
        runtime_environment_variables = var.environment_variables
        runtime_environment_secrets   = var.environment_secrets
      }
    }
    auto_deployments_enabled = var.auto_deployment
  }

  instance_configuration {
    cpu               = var.cpu
    memory            = var.memory
    instance_role_arn = aws_iam_role.task_role.arn
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.autoscaling.arn

  # TODO Kan vi gjøre dette annerledes?
  dynamic "network_configuration" {
    for_each = local.use_vpc_connector ? aws_apprunner_vpc_connector.service : []

    content {
      egress_configuration {
        egress_type       = "VPC"
        vpc_connector_arn = try(network_configuration.value.arn, null)
      }
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role.ecr_access_role
  ]
}

resource "aws_apprunner_vpc_connector" "service" {
  count              = local.use_vpc_connector ? 1 : 0
  vpc_connector_name = var.name_prefix
  subnets            = var.vpc_config.subnet_ids
  security_groups    = var.vpc_config.security_groups

  tags = var.tags
}

resource "aws_apprunner_auto_scaling_configuration_version" "autoscaling" {
  auto_scaling_configuration_name = "limited-scaling"
  max_concurrency                 = var.auto_scaling.max_concurrency
  min_size                        = var.auto_scaling.min_instances
  max_size                        = var.auto_scaling.max_instances

  tags = var.tags
}

##################################
#                                #
# ECR                            #
#                                #
##################################
resource "aws_ecr_repository" "ecr" {
  name = "${var.name_prefix}-internal-${var.application_name}"
}

resource "aws_ecr_lifecycle_policy" "keep_last_100_images" {
  repository = aws_ecr_repository.ecr.name
  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last N images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 100
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}

##################################
#                                #
# Task role                      #
#                                #
##################################

resource "aws_iam_role" "task_role" {
  name               = "${var.name_prefix}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json

  tags = var.tags
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
  name               = "${var.name_prefix}-access-role"
  assume_role_policy = data.aws_iam_policy_document.access_assume_policy.json

  tags = var.tags
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
    resources = [aws_ecr_repository.ecr.arn]
  }
  statement {
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "access_policy" {
  name   = "${var.name_prefix}-access-policy"
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
  name = var.domain_name.zone
}

resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.domain_name.name
  type    = "CNAME"
  ttl     = 3600
  records = [aws_apprunner_service.service.service_url]
}

resource "aws_apprunner_custom_domain_association" "service" {
  domain_name          = aws_route53_record.record.name
  service_arn          = aws_apprunner_service.service.arn
  enable_www_subdomain = false
}

# TODO vil dette funke? Er gjort slik i Vy-IT sin modul: https://github.com/nsbno/terraform-aws-apprunner-service/blob/master/main.tf#L188
resource "aws_route53_record" "validation" {
  name = aws_apprunner_custom_domain_association.service.certificate_validation_records[0].name
  records = [
    aws_apprunner_custom_domain_association.service.certificate_validation_records[0]
  ]
  ttl     = 3600
  type    = aws_apprunner_custom_domain_association.service.certificate_validation_records[0].type
  zone_id = data.aws_route53_zone.zone.zone_id

  depends_on = [
    aws_apprunner_custom_domain_association.service
  ]
}
