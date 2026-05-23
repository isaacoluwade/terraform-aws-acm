terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Required by the module even when no us-east-1 copy is requested
# (configuration_aliases), pointed at the primary region so the unused
# provider has a valid config.
provider "aws" {
  alias  = "us_east_1"
  region = var.region
}

module "acm" {
  source = "../../"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project     = var.project
  environment = var.environment
  region      = var.region

  public_zone_id   = var.public_zone_id
  public_zone_name = var.public_zone_name

  certificates = {
    "main" = {
      domain_name = var.public_zone_name
    }
  }

  tags = {
    Owner = "platform-team"
  }
}
