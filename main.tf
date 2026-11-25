terraform {
  required_version = ">= 1.5"

  required_providers {
    sdwan = {
      source  = "CiscoDevNet/sdwan"
      version = ">= 0.7.0"
    }
  }
}

provider "sdwan" {
  url      = var.sdwan_url
  username = var.sdwan_username
  password = var.sdwan_password
}

module "sdwan" {
  source  = "netascode/nac-sdwan/sdwan"
  version = "1.4.0"

  yaml_directories = ["data"]
}