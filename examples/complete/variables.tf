variable "project" {
  type        = string
  description = "Project name passed through to the module."
  default     = "example"
}

variable "environment" {
  type        = string
  description = "Environment name passed through to the module."
  default     = "dev"
}

variable "region" {
  type        = string
  description = "Primary AWS region. CloudFront copy is always us-east-1."
  default     = "eu-west-2"
}

variable "public_zone_id" {
  type        = string
  description = "Route 53 public zone ID — must be a real zone you own."
}

variable "public_zone_name" {
  type        = string
  description = "DNS name of the Route 53 public zone — must be a real domain you own."
}
