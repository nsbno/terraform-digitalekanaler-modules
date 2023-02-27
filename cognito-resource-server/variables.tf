variable "resource_name" {
  description = "A friendly name for the resource server."
  type        = string
}

variable "resource_identifier" {
  description = "The unique identifier for the resource server."
  type        = string
}

variable "oauth_scopes" {
  type = list(object({
    name        = string
    description = string
  }))
}
