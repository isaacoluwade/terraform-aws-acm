variable "project" {
  type    = string
  default = "tt"
}

variable "environment" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "public_zone_id" {
  type = string
}

variable "public_zone_name" {
  type = string
}

variable "domain_name" {
  type = string
}
