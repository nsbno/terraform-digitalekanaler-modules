variable "name_prefix" {
  description = "A prefix used for naming resources."
  type        = string
}

variable "application_name" {
  description = "The name of the application"
  type = string
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
  type = object({
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
  description = "The application port number"
  type        = number
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
  description = "The tag of the application image to deploy"
  type        = string
  default     = "latest"
}

variable "auto_deployment" {
  description = "Automatically deploy when a new image version is pushed to ECR"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "A map containing a domain and name of the associated hosted zone."
  type = object({
    name = string
    zone = string
  })
}

variable "vpc_config" {
  description = "Enable outbound VPC access for service"
  type = object({
    subnet_ids      = list(string)
    security_groups = list(string)
  })
  default = {
    subnet_ids      = []
    security_groups = []
  }
}
