locals {
}

data "aws_lb" "internal_lb" {
  arn = local.shared_config.lb_internal_arn
}

data "aws_route53_zone" "internal_vydev_io_zone" {
  name         = local.shared_config.internal_hosted_zone_name
  private_zone = true
}

resource "aws_route53_record" "internal_vydev_io_record" {
  zone_id = data.aws_route53_zone.internal_vydev_io_zone.id
  name    = local.internal_domain_name
  type    = "A"

  alias {
    evaluate_target_health = false
    name                   = data.aws_lb.internal_lb.dns_name
    zone_id                = data.aws_lb.internal_lb.zone_id
  }
}
