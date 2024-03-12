output "application_name" {
  value = var.application_name
}

output "task_role_name" {
  description = "The name of the task role"
  value       = module.apprunner.task_role_name
}

output "task_role_arn" {
  description = "The arn  of the task role"
  value       = module.apprunner.task_role_arn
}

output "vpc_id" {
  value = data.aws_vpc.shared.id
}

output "private_subnet_ids" {
  value = data.aws_subnets.private_subnets.id
}

output "security_group_id" {
  value = aws_security_group.apprunner_security_group.id
}
