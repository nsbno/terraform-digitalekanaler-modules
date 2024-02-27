variable "name_prefix" {
  type    = string
  default = "digitalekanaler"
}

variable "application_name" {
  type        = string
  description = "A short and lowercase name for the service (examples: ticket, booking, smartpris). Must be unique to the service."
}

variable "app_port" {
  type        = number
  description = "The port the application is running on"
}
