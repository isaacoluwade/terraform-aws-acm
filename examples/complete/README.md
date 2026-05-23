# `examples/complete` — wildcard + CloudFront copy

Issues two ACM certificates against the supplied Route 53 zone:

1. `platform` — a primary-region cert with the apex domain and a wildcard SAN.
   Use this on ALBs and Kubernetes Ingresses.
2. `cloudfront` — a cert in the primary region *and* a copy in us-east-1
   (via `also_in_regions = ["us-east-1"]`). CloudFront only accepts certs in
   us-east-1, so the copy is what you wire into the distribution.

## Apply

```bash
terraform init
terraform apply \
  -var public_zone_id=Z123456789ABCDEF \
  -var public_zone_name=example.com
```

## Outputs of interest

- `platform_cert_arn` — wildcard cert in your primary region.
- `cloudfront_cert_arn_us_east_1` — paste this into a CloudFront
  `viewer_certificate.acm_certificate_arn` block.

## Tear down

```bash
terraform destroy
```

> The apply blocks until every cert is `ISSUED`. With both a primary-region
> cert and a us-east-1 copy this is usually under two minutes.
