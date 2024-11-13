variable "app_name" {}

variable "oauth_scopes" {
  type    = list(string)
  default = []
}

variable "refresh_token_validity" {
  type = number
  default = 30
}
