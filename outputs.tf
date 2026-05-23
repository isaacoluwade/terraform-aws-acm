output "certificate_arns" {
  description = "Map of cert key to primary-region ARN. Use for ALB / API Gateway / EKS Ingress listeners."
  value       = { for k, c in aws_acm_certificate.this : k => c.arn }
}

output "certificate_domains" {
  description = "Map of cert key to primary domain name. Convenient when wiring DNS or HOST headers downstream."
  value       = { for k, c in aws_acm_certificate.this : k => c.domain_name }
}

output "certificate_status" {
  description = "Map of cert key to ACM status (e.g. ISSUED). Reflects the primary-region certificate."
  value       = { for k, c in aws_acm_certificate.this : k => c.status }
}

output "regional_certificate_arns" {
  description = "Nested map: cert_key -> region -> ARN. Includes the primary region and any also_in_regions copies (currently us-east-1)."
  value       = local.cert_arns_by_region
}

output "validation_record_fqdns" {
  description = "Map of cert key to the validation record FQDNs returned by aws_acm_certificate_validation. Useful for debugging."
  value       = { for k, v in aws_acm_certificate_validation.this : k => v.validation_record_fqdns }
}

output "region" {
  description = "Echo of the input region. Convenient when wiring multiple modules in a composition."
  value       = var.region
}
