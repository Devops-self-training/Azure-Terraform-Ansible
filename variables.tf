variable "account_username" {
  default   = "Student"
  sensitive = false
  type      = string
}

variable "account_password" {
  default   = "P4$$w0rd!"
  sensitive = true
  type      = string
}
variable "location" {
  default = "southeastasia"
  type    = string
}
