variable "application_name" {
  type = string
}

variable "environment" {
  type        = string
  description = "test, stage or prod"
}

variable "port_number" {
  type = number
}

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables that are not sensitive"
}

variable "environment_secrets" {
  type        = map(string)
  description = "Secrets available in terraform can be set directly"
}

variable "manual_environment_secrets" {
  type        = map(string)
  description = "Secrets that you want to set manually must be set through SSM Parameter Store"
}

variable "external_environment_secrets" {
  type        = map(string)
  description = "References to external secrets from SSM Parameter Store"
}

variable "min_number_of_instances" {
  type        = number
  description = "The minimum number of instances that fargate will spawn"
}

variable "max_number_of_instances" {
  type        = number
  description = "The maximum number of instances that fargate will spawn"
}

variable "datadog_version_tag" {
  type        = string
  description = "Datadog will tag traces and logs with a version tag to track deployments"
}

variable "docker_image" {
  type        = string
  description = "The docker image to run"
}

variable "public_load_balancer_domain_name" {
  type        = string
  description = "Do not use this unless you are still depending on our deprecated public load balancer"
  default     = null
}
