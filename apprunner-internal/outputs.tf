output "security_group_id" {
  value = aws_security_group.apprunner_security_group.id
}

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
