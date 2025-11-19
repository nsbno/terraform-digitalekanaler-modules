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

variable "desired_count" {
  description = "The number of instances of the task definitions to place and keep running."
  type        = number
  default     = null
}

variable "autoscaling_capacity" {
  description = "The min and max number of instances to scale to."
  type = object({
    min = number
    max = number
  })
  default = { min = 1, max = 3 }
}

variable "autoscaling_policies" {
  description = "Enable autoscaling for the service"
  type = list(object({
    target_value       = optional(number)
    scale_in_cooldown  = optional(number)
    scale_out_cooldown = optional(number)

    predefined_metric_type = optional(string) # https://docs.aws.amazon.com/autoscaling/application/APIReference/API_PredefinedMetricSpecification.html
    resource_label         = optional(string) # only valid when predefined_metric_type is ALBRequestCountPerTarget

    custom_metrics = optional(list(object({
      label       = string
      id          = string
      expression  = optional(string)
      return_data = optional(bool)
      metric_stat = optional(object({
        stat = string
        metric = object({
          metric_name = string
          namespace   = string
          dimensions  = list(object({ name = string, value = string }))
        })
      }))
    })))
  }))
  default = []
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

variable "add_cloudfront_vpc_origin_integration" {
  type        = bool
  default     = false
  description = "Add listener rule in the internal ALB so cloudFront can communicate directly with ALB."
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

variable "environment_secrets_from_ssm" {
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

variable "force_new_deployment" {
  type        = bool
  default     = false
  description = "Terraform will force new deployment if set to true."
}

variable "deployment_minimum_healthy_percent" {
  default     = 100
  type        = number
  description = "The lower limit of the number of running tasks that must remain running and healthy in a service during a deployment"
}

variable "disable_datadog_agent" {
  type        = bool
  default     = false
  description = "Disable the DataDog agent. Disables metrics and APM in DataDog. Used for saving money in DataDog. The VY_DATADOG_AGENT_ENABLED environment variable is set to 'true' or 'false' in the application container."
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
    enabled         = optional(bool, true)
    cookie_duration = optional(number, 86400)
    cookie_name     = string
  })
  default     = null
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

variable "lb_slow_start" {
  type        = number
  default     = 0
  description = "The time period, in seconds, during which the load balancer allows the newly registered targets to warm up before sending them a full share of requests."
}

variable "lb_healthy_threshold" {
  type        = number
  default     = 3
  description = "Number of consecutive health check successes required by the load balancer before considering a target healthy. The range is 2-10. Defaults to 3."
}

variable "lb_unhealthy_threshold" {
  type        = number
  default     = 3
  description = "Number of consecutive health check failures required by the load balancer before considering a target unhealthy. The range is 2-10. Defaults to 3."
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

variable "repository_url" {
  description = "The URL of the ECR repository where the docker image is stored."
  type        = string
}

variable "rollback_window_in_minutes" {
  description = "The time window in minutes you are able to rollback your service. When it's > 0, you must use BLUE_GREEN strategy."
  type        = number
  default     = 0
}

variable "deployment_configuration_strategy" {
  description = "The deployment strategy to use for the service. Valid values are ROLLING, BLUE_GREEN"
  type        = string
  default     = "ROLLING"

  validation {
    condition     = contains(["ROLLING", "BLUE_GREEN"], var.deployment_configuration_strategy)
    error_message = "The deployment_strategy must be one of: ROLLING, BLUE_GREEN"
  }
}

variable "datadog_team_name" {
  type        = string
  description = "The team name that is used in the 'team' tag in DataDog."
}
