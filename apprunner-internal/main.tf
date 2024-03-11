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

data "aws_ecr_repository" "ecr" {
  name = var.ecr_repository_name
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
