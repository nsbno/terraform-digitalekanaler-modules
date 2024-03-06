module "database" {
  depends_on = []
  source               = "github.com/nsbno/terraform-aws-rds-instance?ref=b88aef5"
  name_prefix          = var.application_name
  vpc_id               = var.vpc_id
  subnet_ids           = var.subnet_ids
  username             = aws_ssm_parameter.rds_username.value
  password             = aws_ssm_parameter.rds_password.value
  port                 = 5432
  database_name        = var.database_name
  engine               = "postgres"
  engine_version       = "15.2"
  instance_type        = "db.t4g.micro"
  allocated_storage    = 50
  multi_az             = false
  kms_key_id           = aws_kms_key.database_key.arn
  apply_immediately    = false
  deletion_protection  = true
  parameter_group_name = aws_db_parameter_group.disable_force_ssl.name
}

resource "aws_db_parameter_group" "disable_force_ssl" {
  name   = "disableforcessl"
  family = "postgres15"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_kms_key" "database_key" {
  description = "Key for digitalekanaler-${var.application_name} RDS instance"
}

resource "aws_kms_key" "application_key" {
  description = "Key for digitalekanaler-${var.application_name} secrets in parameter store"
}

resource "aws_ssm_parameter" "rds_username" {
  name  = "/config/${var.application_name}/rds-username"
  type  = "String"
  value = random_string.rds_username.result
}

resource "aws_ssm_parameter" "rds_password" {
  name   = "/config/${var.application_name}/rds-password"
  type   = "SecureString"
  value  = random_string.rds_password.result
  key_id = aws_kms_key.application_key.id
}

resource "random_string" "rds_username" {
  length  = 10
  special = false
  numeric = false
}

resource "random_string" "rds_password" {
  length  = 16
  special = false
}


resource "aws_security_group_rule" "allow_from_apprunner_to_db" {
  security_group_id        = module.database.security_group_id
  type                     = "ingress"
  from_port                = module.database.port
  to_port                  = module.database.port
  protocol                 = "tcp"
  source_security_group_id = var.security_group_id
}

resource "aws_security_group_rule" "allow_to_db_from_apprunner" {
  security_group_id        = module.database.security_group_id
  type                     = "egress"
  from_port                = module.database.port
  to_port                  = module.database.port
  protocol                 = "tcp"
  source_security_group_id = var.security_group_id
}
