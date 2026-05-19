variable "app_name" {}

variable "oauth_scopes" {
  type    = list(string)
  default = []
}

variable "refresh_token_validity" {
  type = number
  default = 30
}


variable "token_validity_units" {
  description = "Time units for token validity."
  type = object({
    access_token  = optional(string, "hours")
    id_token      = optional(string, "hours")
    refresh_token = optional(string, "days")
  })

  default = {}

  validation {
    condition = alltrue([
      for unit in values(var.token_validity_units) :
      contains(["seconds", "minutes", "hours", "days"], unit)
    ])
    error_message = "Valid values for token validity units are: seconds, minutes, hours, or days."
  }
}
