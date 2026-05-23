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
      domain_name = "test.example.invalid"
    }
  }
}

run "cert_name_tag_follows_primary_name" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this["main"].tags["Name"] == "test-test-use1-main"
    error_message = "cert Name tag should be $${primary_name}-$${cert_key}"
  }
}

run "all_resources_carry_module_tag" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this["main"].tags["Module"] == "terraform-aws-acm"
    error_message = "cert must carry the Module=terraform-aws-acm tag"
  }
}

run "all_resources_carry_project_tag" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this["main"].tags["Project"] == "test"
    error_message = "cert must carry the Project tag"
  }

  assert {
    condition     = aws_acm_certificate.this["main"].tags["Environment"] == "test"
    error_message = "cert must carry the Environment tag"
  }

  assert {
    condition     = aws_acm_certificate.this["main"].tags["ManagedBy"] == "terraform"
    error_message = "cert must carry ManagedBy=terraform tag"
  }
}

run "consumer_tags_do_not_override_spine" {
  command = plan

  variables {
    project          = "test"
    environment      = "test"
    region           = "us-east-1"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"

    certificates = {
      "main" = {
        domain_name = "test.example.invalid"
      }
    }

    tags = {
      Module = "evil-override"
      Owner  = "platform-team"
    }
  }

  assert {
    condition     = aws_acm_certificate.this["main"].tags["Module"] == "terraform-aws-acm"
    error_message = "consumer tags must not override the Module tag from the spine"
  }

  assert {
    condition     = aws_acm_certificate.this["main"].tags["Owner"] == "platform-team"
    error_message = "consumer-provided non-spine tags must be applied"
  }
}

run "region_compression_eu_west_2" {
  command = plan

  variables {
    project          = "test"
    environment      = "test"
    region           = "eu-west-2"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"

    certificates = {
      "main" = {
        domain_name = "test.example.invalid"
      }
    }
  }

  assert {
    condition     = aws_acm_certificate.this["main"].tags["Name"] == "test-test-euw2-main"
    error_message = "region compression should produce 'euw2' from 'eu-west-2'"
  }
}

run "region_compression_ap_southeast_1" {
  command = plan

  variables {
    project          = "test"
    environment      = "test"
    region           = "ap-southeast-1"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"

    certificates = {
      "main" = {
        domain_name = "test.example.invalid"
      }
    }
  }

  assert {
    condition     = aws_acm_certificate.this["main"].tags["Name"] == "test-test-apsoutheast1-main"
    error_message = "region compression should preserve the trailing digit"
  }
}

run "us_east_1_copy_carries_region_tag" {
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
    condition     = aws_acm_certificate.us_east_1["cdn"].tags["Region"] == "us-east-1"
    error_message = "us-east-1 copy must carry Region=us-east-1 tag, not the input region"
  }
}
