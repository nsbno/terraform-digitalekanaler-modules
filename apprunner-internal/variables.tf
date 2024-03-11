variable "application_name" {
  type        = string
  description = "A short and lowercase name for the service (examples: ticket, booking, smartpris). Must be unique to the service."
}

variable "application_port" {
  type        = number
  description = "The port the application is running on"
}

variable "ecr_repository_name" {
  type    = string
  default = null
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


variable "vpc_id" {
  type = string
}