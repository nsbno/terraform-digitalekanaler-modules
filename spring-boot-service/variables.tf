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
    minimum_healthy_percent = optional(number, 100)
  })
  description = "Settings that control how many instances your service is running on."
}

variable "cpu" {
  type        = number
  default     = 2048
  description = "The amount of CPU available to one instance of your service (a small fraction will be used for the sidecar containers that are responsible for monitoring)."
  validation {
    condition     = var.cpu >= 256
    error_message = "The log-router and datadog-agent use 64 cpu units each. In addition, you need some cpu units for your application. So the minimum total cpu is 256."
  }
}

variable "memory" {
  type        = number
  default     = 4096
  description = "The amount of memory available to one instance of your service (a small fraction will be used for the sidecar containers that are responsible for monitoring)."
}

variable "docker_image" {
  type        = string
  description = "The docker image of your service."
}

variable "deprecated_public_domain_name" {
  type        = string
  default     = null
  description = "Do not use this parameter unless you are absolutly sure about what it does. Adds a host-based listening rule in the public load balancer. Does not create a DNS record."
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

variable "environment" {
  type        = string
  description = "The name of the environment that your service is running in (examples: test, stage, prod)."

  validation {
    condition     = contains(["test", "stage", "service", "prod"], var.environment)
    error_message = "The only valid environments are test, stage, service and prod."
  }
}

variable "use_spot" {
  type        = bool
  default     = false
  description = "Whether to use spot instances in non-production environments."
}

variable "wait_for_steady_state" {
  type        = bool
  default     = true
  description = "Terraform waits until the new version of the task is rolled out and working, instead of exiting before the rollout."
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

variable "disable_datadog_agent" {
  type        = bool
  default     = false
  description = "Disable the DataDog agent. Disables metrics and APM in DataDog. Used for saving money in DataDog. The VY_DATADOG_AGENT_ENABLED environment variable is set to 'true' or 'false' in the application container."
}

variable "health_check" {
  type = object({
    healthy_treshold   = optional(number, 3)
    unhealthy_treshold = optional(number, 3)
    timout             = optional(number, 5)
    interval           = optional(number, 30)
  })

  default = {
    healthy_treshold   = 3
    unhealthy_treshold = 3
    timeout            = 5
    interval           = 30
  }
}
