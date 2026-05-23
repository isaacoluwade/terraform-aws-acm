# terraform-aws-acm

Issue ACM certificates with DNS validation against a Route 53 public zone,
with optional us-east-1 copies for CloudFront and other us-east-1-only
services.

This is module 9 of 10 in the [AWS MTKP Terraform Module Library](../projects/1-aws-mtkp-terraform-module-library/).

## Usage

```hcl
module "acm" {
  source = "git::https://github.com/<org>/terraform-aws-acm.git?ref=v1.0.0"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project     = "mtkp"
  environment = "prod"
  region      = "eu-west-2"

  public_zone_id   = module.route53.public_zone_id
  public_zone_name = module.route53.public_zone_name

  certificates = {
    "platform" = {
      domain_name               = "mtkp.example.com"
      subject_alternative_names = ["*.mtkp.example.com"]
    }
    "cloudfront" = {
      domain_name     = "cdn.mtkp.example.com"
      also_in_regions = ["us-east-1"]
    }
  }

  tags = {
    Owner = "platform-team"
  }
}
```

The module always requires two provider configurations: the default `aws`
provider for the primary region and an `aws.us_east_1` alias. When no cert
requests `also_in_regions = ["us-east-1"]`, the aliased provider can point
at the same region as the primary — its resources will not be materialized.

## Operational defaults

- Validation: DNS only. Email validation is unsupported (manual click-through,
  no auto-renewal — operationally unworkable for platform certs).
- Key algorithm: `RSA_2048` by default (broad client compatibility).
  EC alternatives (`EC_prime256v1`, `EC_secp384r1`) are accepted.
- Lifecycle: `create_before_destroy` on every cert. Replacing a cert (new SAN,
  new domain) creates the new one, swaps references, then destroys the old.
- Validation wait: `aws_acm_certificate_validation` blocks the apply until the
  cert is `ISSUED`, so downstream resources never reference a pending cert.
- Renewal: automatic via ACM. The module does nothing on renewal; the DNS
  validation records persist and ACM revalidates continuously.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project` | `string` | — | Required. 3-12 chars, lowercase letters/digits/hyphens. |
| `environment` | `string` | — | Required. Lowercase letters/digits/hyphens. |
| `region` | `string` | — | Required. Primary AWS region for cert issuance. |
| `public_zone_id` | `string` | — | Required. Route 53 hosted zone ID for DNS validation records. |
| `public_zone_name` | `string` | — | Required. DNS name of the Route 53 zone. |
| `certificates` | `map(object)` | — | Required. Map of cert key to `{ domain_name, subject_alternative_names, also_in_regions }`. |
| `validation_method` | `string` | `"DNS"` | Only `DNS` is supported. |
| `key_algorithm` | `string` | `"RSA_2048"` | One of `RSA_2048`, `EC_prime256v1`, `EC_secp384r1`. |
| `tags` | `map(string)` | `{}` | Consumer-specific tags merged with the module's spine. |

## Outputs

| Name | Description |
|------|-------------|
| `certificate_arns` | Map of cert key to primary-region ARN. |
| `certificate_domains` | Map of cert key to primary domain name. |
| `certificate_status` | Map of cert key to ACM status (ISSUED after apply). |
| `regional_certificate_arns` | Nested map: cert_key -> region -> ARN. |
| `validation_record_fqdns` | Map of cert key to validation-record FQDNs. |
| `region` | Echo of the input region. |

## Examples

- [`examples/main`](./examples/main) — single cert in the primary region.
- [`examples/complete`](./examples/complete) — wildcard + SAN cert with a
  us-east-1 copy for CloudFront.

## Testing

Three layers per the [testing pyramid](../projects/1-aws-mtkp-terraform-module-library/01-foundations/04-the-testing-pyramid.md):

```bash
# Layer 1 — static analysis (sub-second)
terraform fmt -check -recursive
tflint --config .tflint.hcl
checkov --config-file .checkov.yaml -d .

# Layer 2 — unit tests with mock_provider (<5s)
terraform test

# Layer 3 — integration tests against real AWS + Route 53 (post-merge only)
cd terratest/test && go test -v -timeout 30m ./...
```

The integration test requires a real Route 53 zone — set
`TEST_ROUTE53_ZONE_ID` and `TEST_ROUTE53_ZONE_NAME` in the CI environment.

## Versioning

See [CHANGELOG.md](./CHANGELOG.md). Tag `v<MAJOR>.<MINOR>.<PATCH>` is the
immutable artifact; the `VERSION` file mirrors the tag and CI enforces
agreement at release.
