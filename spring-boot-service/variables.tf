variable "name" {
  type = string
}

variable "port" {
  type    = number
  default = 8080
}

variable "autoscaling" {
  type = object({
    min_number_of_instances = optional(number, 1)
    max_number_of_instances = optional(number, 1)
    metric_type             = optional(string, "ECSServiceAverageCPUUtilization")
    target                  = optional(number, 50)
  })
}

variable "cpu" {
  type    = number
  default = 2048
}

variable "memory" {
  type    = number
  default = 4096
}

variable "datadog_tags" {
  type = object({
    version     = string
    environment = string
  })
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

variable "environment" {
  type = map(string)
}

variable "secrets" {
  type = map(string)
}

variable "extra_java_tool_options" {
  type    = string
  default = ""
}
