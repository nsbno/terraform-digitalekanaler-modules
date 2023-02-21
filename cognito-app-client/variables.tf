variable "app_name" {}

variable "oauth_scopes" {
  type    = list(string)
  default = []
}
