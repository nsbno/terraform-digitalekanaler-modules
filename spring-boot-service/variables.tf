variable "name" {
  type        = string
  description = "A short and lowercase name for the service (examples: ticket, booking, smartpris). Must be unique to the service."
}

variable "name_prefix" {
  type    = string
  default = "digitalekanaler"
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

variable "remove_api_gateway_integration" {
  type        = bool
  default     = false
  description = "Change listening rule in the internal load balancer to remove API-gateway integration."
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

variable "datadog_agent_cmd_port" {
  type        = number
  default     = 5001
  description = "Sets the DD_CMD_PORT environment variable in the datadog-agent sidecar"
}
variable "datadog_agent_version" {
  type        = string
  default     = "7.67.0-rc.3-full"
  description = "Sets image tag for datadog-agent sidecar"
}

variable "custom_api_gateway_path" {
  type        = string
  default     = null
  description = "By default, your service will be avaialable at /services/<name>. If you set this variable, it will be available at /services/<custom_api_gateway_path> intead."
}

variable "health_check_override" {
  type = object({
    interval    = optional(number)
    timeout     = optional(number)
    startPeriod = optional(number)
  })
  default = {
    interval    = 30
    timeout     = 5
    startPeriod = 90
  }
  description = "Override default health check parameters. This adds health check in ECS in addition to the load balancer, and can speed up your deployment"
}

variable "lb_stickiness" {
  type = object({
    type            = optional(string, "app_cookie")
    enabled         = optional(bool,   true)
    cookie_duration = optional(number, 86400)
    cookie_name     = string
  })
  default = null
  description = "Bind a user's session to a specific target"
}

variable "health_check_grace_period_seconds" {
  type        = number
  default     = 300
  description = "The time that ECS waits before it starts checking the health of the new task."
}

variable "lb_deregistration_delay" {
  type        = number
  default     = 300
  description = "The time that the load balancer waits before it deregisters a running task."
}

variable "lb_healthy_threshold" {
  type = number
  default = 3
  description = "Number of consecutive health check successes required by the load balancer before considering a target healthy. The range is 2-10. Defaults to 3."
}

variable "service_timeouts" {
  type = object({
    create = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default = {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
  description = "Timeouts for the service resource."
}

variable "custom_metrics" {
  description = "The custom metrics for autoscaling. Check https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy#create-target-tracking-scaling-policy-using-metric-math for more information."
  type = list(object({
    label = string
    id    = string
    expression  = optional(string)
    metric_stat = optional(object({
      metric = object({
        metric_name = string
        namespace   = string
        dimensions = list(object({
          name  = string
          value = string
        }))
      })
      stat = string
    }))
    return_data = bool
  }))
  default = []
}
