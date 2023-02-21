variable "app_name" {}

variable "kms_key" {
  type = string
  description = "The name of the application kms key"
}

variable "oauth_scopes" {
  type    = list(string)
  default = []
}

variable "store_credentials" {
  default = true
}
