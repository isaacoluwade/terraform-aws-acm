# `examples/main` — minimal ACM cert

Issues a single ACM certificate for the supplied Route 53 zone, validated via
DNS records placed in the same zone.

## Apply

```bash
terraform init
terraform apply \
  -var public_zone_id=Z123456789ABCDEF \
  -var public_zone_name=example.com
```

Outputs `cert_arn` and an `ingress_annotation_snippet` you can paste into
a Kubernetes Ingress manifest.

## Tear down

```bash
terraform destroy
```

> The apply blocks until ACM marks the cert `ISSUED`. With DNS validation
> against a delegated zone this is usually 30-90 seconds.
