output "task_role_name" {
  value = module.task.task_role_name
}

output "security_group_id" {
  value = module.task.security_group_id
}

output "task_execution_role_name" {
  value = module.task.task_execution_role_name
}

output "application_key_id" {
  value = aws_kms_key.application_key.id
}
