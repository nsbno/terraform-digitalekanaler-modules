variable "service_name" {
  description = "The name that the service will be exposed as in the API Gateway"
  type        = string
}

variable "domain_name" {
  description = "The domain name of the service being proxied"
  type        = string
}

variable "listener_arn" {
  description = "AWS ALB listener ARN"
  type        = string
}

variable "context_path" {
  type        = string
  description = "An optional context path that will prefix all requests to the service. Must start with / if defined"
  default     = ""

  validation {
    condition     = var.context_path == "" || can(regex("^/.", var.context_path))
    error_message = "Context path must start with /"
  }
}
