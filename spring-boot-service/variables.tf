variable "name" {
  type        = string
  description = "A short and lowercase name for the service (examples: ticket, booking, smartpris). Must be unique to the service."
}

variable "port" {
  type        = number
  default     = 8080
  description = "The port number that your service is listening for http requets on."
}

variable "autoscaling" {
  type = object({
    min_number_of_instances = optional(number, 3)
    max_number_of_instances = optional(number, 3)
    metric_type             = optional(string, "ECSServiceAverageCPUUtilization")
    target                  = optional(number, 50)
  })
  description = "Settings that control how many instances your service is running on."
}

variable "cpu" {
  type        = number
  default     = 2048
  description = "The amount of CPU available to one instance of your service (a small fraction will be used for the sidecar containers that are responsible for monitoring)."
  validation {
    condition     = var.datadog_tags.environment >= 256
    error_message = "The log-router and datadog-agent use 100 cpu units each. In addition, you need some cpu units for your application. So the minimum total cpu is 256."
  }
}

variable "memory" {
  type        = number
  default     = 4096
  description = "The amount of memory available to one instance of your service (a small fraction will be used for the sidecar containers that are responsible for monitoring)."
}

variable "datadog_tags" {
  type = object({
    version     = string
    environment = string
  })
  description = "All logs and traces in datadog should be tagged with version=<the short commit-sha> and environment=<name of environment>"
  validation {
    condition     = contains(["test", "stage", "prod"], var.datadog_tags.environment)
    error_message = "datadog_tags.environment must be one of 'test', 'stage' and 'prod'."
  }
}

variable "docker_image" {
  type        = string
  description = "The docker image of your service."
}

variable "public_load_balancer_domain_name" {
  type        = string
  default     = null
  description = "Do not use this parameter unless you are absolutly sure about what it does. A hostname pointing to our public load balancer."
}

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "A map of non-sensitive environment variables where the key is the name of the variable and the value is the value of the variable."
}

variable "environment_secrets" {
  type        = map(string)
  default     = {}
  description = "A map of non-sensitive environment variables where the key is the name of the variable and the value is the arn of an SSM parameter."
}

variable "extra_java_tool_options" {
  type        = string
  default     = ""
  description = "Extra options that you want to set in the JAVA_TOOL_OPTIONS variable in addition to the ones that this module sets."
}
