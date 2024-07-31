variable "application_name" {
  description = "The name of the application"
  type        = string
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}

variable "cpu" {
  description = "The number of CPU units available to the application (1024|2048)"
  type        = string
  default     = "1024"
}

variable "memory" {
  description = "The amount of memory in MB available to the application (2048|3072|4096)"
  type        = string
  default     = "2048"
}

variable "auto_scaling" {
  description = "Autoscaling configuration"
  type        = object({
    min_instances   = number
    max_instances   = number
    max_concurrency = number
  })
  default = {
    min_instances   = 1
    max_instances   = 2
    max_concurrency = 100
  }
}

variable "application_port" {
  type        = number
  description = "The port the application is running on"
}

variable "ecr_repository_name" {
  type    = string
}

variable "environment_variables" {
  description = "Environment variables that is passed to the container"
  type        = map(string)
  default     = {}
}

variable "environment_secrets" {
  description = "Secrets and parameters available to your service as environment variables. Set the value to the ARN of a secret in Parameter Store or Secrets Manager."
  type        = map(string)
  default     = {}
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "service_account_id" {
  type = string
}

variable "environment" {
  type        = string
  description = "The name of the environment that your service is running in (examples: test, stage, prod)."

  validation {
    condition     = contains(["test", "stage", "service", "prod"], var.environment)
    error_message = "The only valid environments are test, stage, service and prod."
  }
}

variable "subnet_placement" {
  type = string
  description = "Which subnets to place the app in (public, private)"
  default = "private"

  validation {
    condition = contains(["public", "private"], var.subnet_placement)
    error_message = "The only valid subnets are public, or private"
  }
}
