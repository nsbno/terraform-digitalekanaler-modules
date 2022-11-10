variable "service_name" {
  description = "The name that the service will be exposed as in the API Gateway"
  type        = string
}

variable "domain_name" {
  description = ""
  type        = string
}

variable "listener_arn" {
  description = ""
  type        = string
}
