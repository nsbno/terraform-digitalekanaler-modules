variable "app_name" {
  description = "The name of the application the resource server is named after"
  type        = string
}

variable "oauth_scopes" {
  type = list(object({
    name        = string
    description = string
  }))
}
