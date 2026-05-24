locals {
  # S-1 fix: explicit region→short-code map (no derivation tricks).
  # Adding a new region = adding a line here.
  region_code_map = {
    "us-east-1"      = "use1"
    "us-east-2"      = "use2"
    "us-west-1"      = "usw1"
    "us-west-2"      = "usw2"
    "eu-west-1"      = "euw1"
    "eu-west-2"      = "euw2"
    "eu-west-3"      = "euw3"
    "eu-central-1"   = "euc1"
    "eu-north-1"     = "eun1"
    "eu-south-1"     = "eus1"
    "ap-southeast-1" = "apse1"
    "ap-southeast-2" = "apse2"
    "ap-northeast-1" = "apne1"
    "ap-northeast-2" = "apne2"
    "ap-northeast-3" = "apne3"
    "ap-south-1"     = "aps1"
    "ap-east-1"      = "ape1"
    "ca-central-1"   = "cac1"
    "ca-west-1"      = "caw1"
    "sa-east-1"      = "sae1"
    "me-south-1"     = "mes1"
    "me-central-1"   = "mec1"
    "af-south-1"     = "afs1"
  }
  region_code = local.region_code_map[var.region]

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

  # AC-C1 fix: the previous version's for_each key included the computed
  # `dvo.resource_record_name`, which is unknown at plan time for new certs
  # ("Invalid for_each argument: keys depend on values that cannot be
  # determined until apply"). The fix keys for_each off (cert, domain) tuples
  # derived from var.certificates inputs — both fully known at plan time.
  # The DVO attributes (record name/type/value) are looked up inside the
  # aws_route53_record resource body, where computed values are allowed.
  validation_entries = {
    for entry in flatten([
      for k, c in var.certificates : [
        for d in distinct(concat([c.domain_name], c.subject_alternative_names)) : {
          cert_key = k
          domain   = d
        }
      ]
    ]) : "${entry.cert_key}::${entry.domain}" => entry
  }

  us_east_1_validation_entries = {
    for entry in flatten([
      for k, c in var.certificates : [
        for d in distinct(concat([c.domain_name], c.subject_alternative_names)) : {
          cert_key = k
          domain   = d
        }
      ] if contains(c.also_in_regions, "us-east-1") && var.region != "us-east-1"
    ]) : "${entry.cert_key}::us-east-1::${entry.domain}" => entry
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
  for_each = local.validation_entries

  zone_id = var.public_zone_id
  # AC-C1: look up the matching DVO at apply time. Each pluck filters the
  # cert's domain_validation_options for the entry whose domain_name matches
  # our static (cert_key, domain) tuple.
  name = one([
    for dvo in aws_acm_certificate.this[each.value.cert_key].domain_validation_options :
    dvo.resource_record_name if dvo.domain_name == each.value.domain
  ])
  type = one([
    for dvo in aws_acm_certificate.this[each.value.cert_key].domain_validation_options :
    dvo.resource_record_type if dvo.domain_name == each.value.domain
  ])
  records = [one([
    for dvo in aws_acm_certificate.this[each.value.cert_key].domain_validation_options :
    dvo.resource_record_value if dvo.domain_name == each.value.domain
  ])]
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
  for_each = local.us_east_1_validation_entries

  zone_id = var.public_zone_id
  name = one([
    for dvo in aws_acm_certificate.us_east_1[each.value.cert_key].domain_validation_options :
    dvo.resource_record_name if dvo.domain_name == each.value.domain
  ])
  type = one([
    for dvo in aws_acm_certificate.us_east_1[each.value.cert_key].domain_validation_options :
    dvo.resource_record_type if dvo.domain_name == each.value.domain
  ])
  records = [one([
    for dvo in aws_acm_certificate.us_east_1[each.value.cert_key].domain_validation_options :
    dvo.resource_record_value if dvo.domain_name == each.value.domain
  ])]
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
