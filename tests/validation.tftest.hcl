mock_provider "aws" {}
mock_provider "aws" {
  alias = "us_east_1"
}

run "rejects_project_too_short" {
  command = plan

  variables {
    project          = "ab"
    environment      = "test"
    region           = "us-east-1"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"
    certificates = {
      "main" = { domain_name = "test.example.invalid" }
    }
  }

  expect_failures = [
    var.project,
  ]
}

run "rejects_project_with_uppercase" {
  command = plan

  variables {
    project          = "Caas"
    environment      = "test"
    region           = "us-east-1"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"
    certificates = {
      "main" = { domain_name = "test.example.invalid" }
    }
  }

  expect_failures = [
    var.project,
  ]
}

run "rejects_environment_with_uppercase" {
  command = plan

  variables {
    project          = "test"
    environment      = "Prod"
    region           = "us-east-1"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"
    certificates = {
      "main" = { domain_name = "test.example.invalid" }
    }
  }

  expect_failures = [
    var.environment,
  ]
}

run "rejects_invalid_region" {
  command = plan

  variables {
    project          = "test"
    environment      = "test"
    region           = "not-a-region"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"
    certificates = {
      "main" = { domain_name = "test.example.invalid" }
    }
  }

  expect_failures = [
    var.region,
  ]
}

run "rejects_invalid_public_zone_id" {
  command = plan

  variables {
    project          = "test"
    environment      = "test"
    region           = "us-east-1"
    public_zone_id   = "not-a-zone"
    public_zone_name = "test.example.invalid"
    certificates = {
      "main" = { domain_name = "test.example.invalid" }
    }
  }

  expect_failures = [
    var.public_zone_id,
  ]
}

run "rejects_invalid_domain_name" {
  command = plan

  variables {
    project          = "test"
    environment      = "test"
    region           = "us-east-1"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"
    certificates = {
      "main" = { domain_name = "Not-A-Domain" }
    }
  }

  expect_failures = [
    var.certificates,
  ]
}

run "rejects_invalid_san" {
  command = plan

  variables {
    project          = "test"
    environment      = "test"
    region           = "us-east-1"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"
    certificates = {
      "main" = {
        domain_name               = "test.example.invalid"
        subject_alternative_names = ["NOT A FQDN"]
      }
    }
  }

  expect_failures = [
    var.certificates,
  ]
}

run "rejects_invalid_also_in_regions" {
  command = plan

  variables {
    project          = "test"
    environment      = "test"
    region           = "us-east-1"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"
    certificates = {
      "main" = {
        domain_name     = "test.example.invalid"
        also_in_regions = ["nonsense"]
      }
    }
  }

  expect_failures = [
    var.certificates,
  ]
}

run "rejects_email_validation_method" {
  command = plan

  variables {
    project           = "test"
    environment       = "test"
    region            = "us-east-1"
    public_zone_id    = "Z123456789ABCDEF"
    public_zone_name  = "test.example.invalid"
    validation_method = "EMAIL"
    certificates = {
      "main" = { domain_name = "test.example.invalid" }
    }
  }

  expect_failures = [
    var.validation_method,
  ]
}

run "rejects_unknown_key_algorithm" {
  command = plan

  variables {
    project          = "test"
    environment      = "test"
    region           = "us-east-1"
    public_zone_id   = "Z123456789ABCDEF"
    public_zone_name = "test.example.invalid"
    key_algorithm    = "RSA_1024"
    certificates = {
      "main" = { domain_name = "test.example.invalid" }
    }
  }

  expect_failures = [
    var.key_algorithm,
  ]
}
