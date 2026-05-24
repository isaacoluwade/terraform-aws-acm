# Changelog

All notable changes to this module are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/), versioning follows
[SemVer](https://semver.org/).

## [2.0.0] - 2026-05-24

### Breaking changes

- **Region short-code derivation rewritten** (S-1 fix). The `region_code`
  local previously derived its value from a substring formula that produced
  non-canonical codes (`us-east-1` → `useast1`, `eu-west-2` → `euwest2`,
  `ap-southeast-1` → `apsoutheast1`). v2.0.0 replaces it with an explicit
  `region_code_map` lookup, giving the canonical short codes
  (`use1`, `euw2`, `apse1`, ...). **Every resource name and every `Name`
  tag in this module shifts as a result.** Consumers upgrading from
  v1.x will see destroy+recreate on first apply.

  See [`UPGRADE_GUIDE.md`](../UPGRADE_GUIDE.md) at the workspace root for
  the recommended per-environment cutover sequence.
- **DNS validation `for_each` keys reworked** (AC-C1 fix). Previously
  keyed on `aws_acm_certificate.this[*].domain_validation_options[].resource_record_name`
  — a computed attribute unknown at plan time for new certs. This caused
  `Invalid for_each argument: keys depend on values that cannot be
  determined until apply` errors on any first-time apply with a
  non-empty `var.certificates`. v2.0.0 derives the keys from a static
  `(cert_key, domain)` tuple built from `var.certificates` inputs
  (apex + SANs). DVO attributes are looked up at apply time inside the
  resource body via `one([for dvo in ... if dvo.domain_name == ...])`.

  Migration: no input-shape change. Apply-time behavior fixed: new
  certs now apply cleanly without the workaround of running `apply`
  twice.

## [1.0.0] - 2026-05-22

### Added

- Initial release of `terraform-aws-acm`.
- Issues ACM certificates with DNS validation against a Route 53 public zone.
- Multi-cert support via the `certificates` map (each entry can have its own
  `domain_name`, `subject_alternative_names`, and `also_in_regions`).
- Optional us-east-1 copy via `also_in_regions = ["us-east-1"]` for CloudFront
  consumers (provider alias `aws.us_east_1` is required when this is used).
- `aws_acm_certificate_validation` ensures the apply blocks until the cert is
  ISSUED, not just PENDING_VALIDATION.
- `create_before_destroy` lifecycle so cert replacement (e.g. adding a SAN)
  doesn't disrupt in-flight references.
- Configurable `key_algorithm` (RSA_2048 default; EC alternatives supported).
- Native `terraform test` suite covering defaults, naming, and validation.
- Terratest verifying real ACM issuance against a Route 53 zone fixture.
- `examples/main/` minimal single-cert consumer and `examples/complete/` with
  wildcard + SAN + us-east-1 CloudFront copy.

### Module contract

- Required inputs: `project`, `environment`, `region`, `public_zone_id`,
  `public_zone_name`, `certificates`.
- Optional inputs: `validation_method` (default `DNS`), `key_algorithm`
  (default `RSA_2048`), `tags`.
- Required providers: default `aws` for the primary region plus
  `aws.us_east_1` (configuration_aliases). The aliased provider can point at
  the same region as the primary when no cert requests a us-east-1 copy.
- Outputs: `certificate_arns`, `certificate_domains`, `certificate_status`,
  `regional_certificate_arns`, `validation_record_fqdns`, `region`.

[1.0.0]: https://github.com/example/terraform-aws-acm/releases/tag/v1.0.0
