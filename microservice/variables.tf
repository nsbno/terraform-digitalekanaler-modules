variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "image" {
  type = string
}

variable "port" {
  type = number
}

variable "environment_variables" {
  type = map(string)
}

variable "min_capacity" {
  type = number
}

variable "max_capacity" {
  type = number
}

variable "internal_domain_name" {
  type = string
}

variable "external_domain_name" {
  type = string
}

variable "environment_secrets" {
  type = map(string)
}

variable "manual_environment_secrets" {
  type = map(string)
}

variable "external_environment_secrets" {
  type = map(string)
}
