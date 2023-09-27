output "task_role_name" {
  value = module.task.task_role_name
}

output "task_role_arn" {
  value = module.task.task_role_arn
}

output "task_execution_role_name" {
  value = module.task.task_execution_role_name
}

output "security_group_id" {
  value = module.task.security_group_id
}

output "application_key_id" {
  value = aws_kms_key.application_key.id
}

output "application_key_arn" {
  value = aws_kms_key.application_key.arn
}
