variable "project" {
  type        = string
  description = "Project / platform name. Drives primary_name and the Project tag on every resource. Lowercase letters, digits, and hyphens only; 3-12 characters."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,12}$", var.project))
    error_message = "project must be 3-12 chars, lowercase letters, digits, and hyphens only."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod, ci-*). Drives primary_name and the Environment tag. Lowercase letters, digits, and hyphens only."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment must be lowercase letters, digits, and hyphens only."
  }
}

variable "region" {
  type        = string
  description = "Primary AWS region (e.g. us-east-1). The region the primary ACM certificate is issued in."

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "region must look like 'us-east-1', 'eu-west-2', etc."
  }
}

variable "public_zone_id" {
  type        = string
  description = "Route 53 public zone ID used to host DNS validation records for the certificates."

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.public_zone_id))
    error_message = "public_zone_id must look like a Route 53 hosted zone ID (e.g. Z123456789ABCDEF)."
  }
}

variable "public_zone_name" {
  type        = string
  description = "DNS name of the Route 53 public zone (e.g. mtkp.example.com). Used in tags and outputs for diagnostics."
}

variable "certificates" {
  type = map(object({
    domain_name               = string
    subject_alternative_names = optional(list(string), [])
    also_in_regions           = optional(list(string), [])
  }))
  description = "Map of cert key to certificate definition. Each cert is issued in the primary region; additional copies are issued in each region in also_in_regions (CloudFront wants us-east-1)."

  validation {
    condition = alltrue([
      for c in var.certificates :
      can(regex("^(\\*\\.)?([a-z0-9-]+\\.)+[a-z]{2,}$", c.domain_name))
    ])
    error_message = "domain_name must be a valid FQDN (optionally with a leading *. wildcard)."
  }

  validation {
    condition = alltrue([
      for c in var.certificates : alltrue([
        for san in c.subject_alternative_names :
        can(regex("^(\\*\\.)?([a-z0-9-]+\\.)+[a-z]{2,}$", san))
      ])
    ])
    error_message = "every subject_alternative_names entry must be a valid FQDN (optionally with a leading *. wildcard)."
  }

  validation {
    condition = alltrue([
      for c in var.certificates : alltrue([
        for r in c.also_in_regions :
        can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", r))
      ])
    ])
    error_message = "also_in_regions entries must be valid AWS regions (e.g. 'us-east-1')."
  }
}

variable "validation_method" {
  type        = string
  description = "ACM validation method. DNS is the only supported value in this module — email validation is operationally unworkable (manual click-through, no auto-renewal)."
  default     = "DNS"

  validation {
    condition     = var.validation_method == "DNS"
    error_message = "validation_method must be 'DNS'. Email validation is not supported by this module."
  }
}

variable "key_algorithm" {
  type        = string
  description = "Key algorithm for the ACM certificate. RSA_2048 is the safe default for broad client compatibility; EC_prime256v1 / EC_secp384r1 are valid for modern-only consumers."
  default     = "RSA_2048"

  validation {
    condition     = contains(["RSA_2048", "EC_prime256v1", "EC_secp384r1"], var.key_algorithm)
    error_message = "key_algorithm must be one of: RSA_2048, EC_prime256v1, EC_secp384r1."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to merge with the module's default tag spine. Keys that conflict with the spine are overridden by the spine."
  default     = {}
}
