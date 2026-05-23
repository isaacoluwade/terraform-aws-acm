locals {
  region_code = format(
    "%s%s",
    substr(replace(var.region, "-", ""), 0, length(replace(var.region, "-", "")) - 1),
    substr(var.region, length(var.region) - 1, 1),
  )

  primary_name = "${var.project}-${var.environment}-${local.region_code}"

  module_version = trimspace(file("${path.module}/VERSION"))

  default_tags = {
    Project       = var.project
    Environment   = var.environment
    Region        = var.region
    ManagedBy     = "terraform"
    Module        = "terraform-aws-acm"
    ModuleVersion = local.module_version
  }

  tags = merge(var.tags, local.default_tags)

  # Certs that explicitly want a us-east-1 copy via also_in_regions.
  # The module supports a single aliased provider (aws.us_east_1) because
  # CloudFront's us-east-1 requirement is the dominant cross-region case.
  certs_in_us_east_1 = {
    for k, c in var.certificates : k => c
    if contains(c.also_in_regions, "us-east-1") && var.region != "us-east-1"
  }

  # Validation records (one per DVO across both primary + us-east-1 copies).
  primary_validation_records = {
    for dvo in flatten([
      for k, c in aws_acm_certificate.this : [
        for opt in c.domain_validation_options : {
          cert_key = k
          name     = opt.resource_record_name
          type     = opt.resource_record_type
          value    = opt.resource_record_value
        }
      ]
    ]) : "${dvo.cert_key}::${dvo.name}" => dvo
  }

  us_east_1_validation_records = {
    for dvo in flatten([
      for k, c in aws_acm_certificate.us_east_1 : [
        for opt in c.domain_validation_options : {
          cert_key = k
          name     = opt.resource_record_name
          type     = opt.resource_record_type
          value    = opt.resource_record_value
        }
      ]
    ]) : "${dvo.cert_key}::us-east-1::${dvo.name}" => dvo
  }

  # Nested map: cert_key -> region -> ARN. Always includes the primary region;
  # also includes us-east-1 when also_in_regions covers it.
  cert_arns_by_region = {
    for k, c in var.certificates : k => merge(
      { (var.region) = aws_acm_certificate.this[k].arn },
      contains(c.also_in_regions, "us-east-1") && var.region != "us-east-1" ? {
        "us-east-1" = aws_acm_certificate.us_east_1[k].arn
      } : {},
    )
  }
}

# ---------------------------------------------------------------------------
# Primary-region certificate
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "this" {
  for_each = var.certificates

  domain_name               = each.value.domain_name
  subject_alternative_names = each.value.subject_alternative_names
  validation_method         = var.validation_method
  key_algorithm             = var.key_algorithm

  tags = merge(local.tags, {
    Name = "${local.primary_name}-${each.key}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = local.primary_validation_records

  zone_id         = var.public_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  for_each = var.certificates

  certificate_arn = aws_acm_certificate.this[each.key].arn

  validation_record_fqdns = [
    for dvo in aws_acm_certificate.this[each.key].domain_validation_options :
    dvo.resource_record_name
  ]

  depends_on = [aws_route53_record.validation]
}

# ---------------------------------------------------------------------------
# us-east-1 copy (for CloudFront and other us-east-1-only services)
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "us_east_1" {
  for_each = local.certs_in_us_east_1

  provider = aws.us_east_1

  domain_name               = each.value.domain_name
  subject_alternative_names = each.value.subject_alternative_names
  validation_method         = var.validation_method
  key_algorithm             = var.key_algorithm

  tags = merge(local.tags, {
    Name   = "${local.primary_name}-${each.key}-use1"
    Region = "us-east-1"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation_us_east_1" {
  for_each = local.us_east_1_validation_records

  zone_id         = var.public_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "us_east_1" {
  for_each = local.certs_in_us_east_1

  provider = aws.us_east_1

  certificate_arn = aws_acm_certificate.us_east_1[each.key].arn

  validation_record_fqdns = [
    for dvo in aws_acm_certificate.us_east_1[each.key].domain_validation_options :
    dvo.resource_record_name
  ]

  depends_on = [aws_route53_record.validation_us_east_1]
}
