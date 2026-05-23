output "platform_cert_arn" {
  description = "Wildcard cert ARN in the primary region — for ALB / EKS Ingress."
  value       = module.acm.certificate_arns["platform"]
}

output "cloudfront_cert_arn_us_east_1" {
  description = "us-east-1 cert ARN for the CloudFront distribution."
  value       = module.acm.regional_certificate_arns["cloudfront"]["us-east-1"]
}

output "all_certificate_arns" {
  description = "Map of every issued cert's primary-region ARN."
  value       = module.acm.certificate_arns
}

output "all_regional_certificate_arns" {
  description = "Nested map of every cert by region (primary + us-east-1 where applicable)."
  value       = module.acm.regional_certificate_arns
}

output "certificate_status" {
  description = "ACM status of each cert. Should be ISSUED after apply."
  value       = module.acm.certificate_status
}
