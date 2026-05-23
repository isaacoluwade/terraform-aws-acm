output "certificate_arns" {
  value = module.acm.certificate_arns
}

output "certificate_domains" {
  value = module.acm.certificate_domains
}

output "certificate_status" {
  value = module.acm.certificate_status
}

output "regional_certificate_arns" {
  value = module.acm.regional_certificate_arns
}

output "region" {
  value = module.acm.region
}
