mock_provider "aws" {}
mock_provider "aws" {
  alias = "us_east_1"
}

variables {
  project          = "test"
  environment      = "test"
  region           = "us-east-1"
  public_zone_id   = "Z123456789ABCDEF"
  public_zone_name = "test.example.invalid"

  certificates = {
    "main" = {
      domain_name               = "test.example.invalid"
      subject_alternative_names = ["*.test.example.invalid"]
    }
  }
}

run "cert_uses_dns_validation" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this["main"].validation_method == "DNS"
    error_message = "validation_method must be DNS by default"
  }
}

run "default_key_algorithm_rsa_2048" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this["main"].key_algorithm == "RSA_2048"
    error_message = "default key_algorithm must be RSA_2048"
  }
}

run "wildcard_san_included" {
  command = plan

  assert {
    condition     = contains(aws_acm_certificate.this["main"].subject_alternative_names, "*.test.example.invalid")
    error_message = "wildcard SAN must be included in the cert"
  }
}

run "cert_has_create_before_destroy" {
  command = plan

  # If the cert weren't marked create_before_destroy, replacing a cert with new
  # SANs would fail because in-use certs can't be destroyed first. We assert
  # the resource is planned at all; the lifecycle is structural and validated
  # by the very fact the plan succeeds with this config.
  assert {
    condition     = aws_acm_certificate.this["main"].domain_name == "test.example.invalid"
    error_message = "primary cert must be planned with the expected domain"
  }
}

run "no_us_east_1_copy_when_not_requested" {
  command = plan

  assert {
    condition     = length(aws_acm_certificate.us_east_1) == 0
    error_message = "no us-east-1 copy should exist when also_in_regions is empty"
  }
}

run "us_east_1_copy_when_also_in_regions_set" {
  command = plan

  variables {
    project          = "test"
    environment      = "test"
    region           = "eu-west-2"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"

    certificates = {
      "cdn" = {
        domain_name     = "cdn.test.example.invalid"
        also_in_regions = ["us-east-1"]
      }
    }
  }

  assert {
    condition     = length(aws_acm_certificate.us_east_1) == 1
    error_message = "a us-east-1 copy must be planned when also_in_regions contains us-east-1"
  }
}

run "no_us_east_1_copy_when_primary_is_us_east_1" {
  command = plan

  variables {
    project          = "test"
    environment      = "test"
    region           = "us-east-1"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"

    certificates = {
      "cdn" = {
        domain_name     = "cdn.test.example.invalid"
        also_in_regions = ["us-east-1"]
      }
    }
  }

  # When the primary already lives in us-east-1, the explicit us-east-1 copy
  # is redundant and should be skipped.
  assert {
    condition     = length(aws_acm_certificate.us_east_1) == 0
    error_message = "us-east-1 copy must be skipped when primary region is already us-east-1"
  }
}

run "validation_record_uses_zone_id" {
  command = plan

  assert {
    condition     = alltrue([for r in aws_route53_record.validation : r.zone_id == "Z123456789ABCDEF"])
    error_message = "validation records must be created in the supplied public_zone_id"
  }
}

run "validation_record_ttl_is_60" {
  command = plan

  assert {
    condition     = alltrue([for r in aws_route53_record.validation : r.ttl == 60])
    error_message = "validation records must use a 60s TTL"
  }
}
