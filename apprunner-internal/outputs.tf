output "application_name" {
  value = var.application_name
}

output "task_role_name" {
  description = "The name of the task role"
  value       = aws_iam_role.task_role.name
}

output "task_role_arn" {
  description = "The arn  of the task role"
  value       = aws_iam_role.task_role.arn
}

output "vpc_id" {
  value = data.aws_vpc.shared.id
}

output "private_subnet_ids" {
  value = data.aws_subnets.private_subnets.ids
}

output "security_group_id" {
  value = aws_security_group.apprunner_security_group.id
}
