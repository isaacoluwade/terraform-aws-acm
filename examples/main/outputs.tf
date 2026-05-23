output "cert_arn" {
  description = "ARN of the issued cert. Use in an ALB listener config."
  value       = module.acm.certificate_arns["main"]
}

output "ingress_annotation_snippet" {
  description = "Copy-pasteable Ingress annotation block referencing the issued cert."
  value       = <<-EOT
    annotations:
      kubernetes.io/ingress.class: alb
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
      alb.ingress.kubernetes.io/certificate-arn: ${module.acm.certificate_arns["main"]}
  EOT
}
