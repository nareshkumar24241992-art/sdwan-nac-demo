variable "sdwan_url" {
  type        = string
  description = "Catalyst SD-WAN Manager URL (from DevNet sandbox Credentials)"
}

variable "sdwan_username" {
  type        = string
  sensitive   = true
  description = "vManage username"
}

variable "sdwan_password" {
  type        = string
  sensitive   = true
  description = "vManage password"
}