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

output "service_connect_namespace_arn" {
  value       = local.service_connect_namespace_arn
  description = "ARN of the Service Connect namespace (null if Service Connect is not enabled)"
}

output "service_connect_dns_name" {
  value       = var.enable_service_connect ? "${var.name}.${local.service_connect_namespace_name}" : null
  description = "The DNS name for accessing this service via Service Connect"
}

output "service_connect_url" {
  value       = var.enable_service_connect ? "http://${var.name}.${local.service_connect_namespace_name}" : null
  description = "The full HTTP URL for accessing this service via Service Connect"
}

