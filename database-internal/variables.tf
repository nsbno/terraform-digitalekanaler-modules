variable "name_prefix" {
  type    = string
  default = "digitalekanaler"
}

variable "application_name" {
  type        = string
  description = "A short and lowercase name for the service (examples: ticket, booking, smartpris). Must be unique to the service."
}

variable "database_name" {
  type        = string
  description = "A short and lowercase name for the database"
}
