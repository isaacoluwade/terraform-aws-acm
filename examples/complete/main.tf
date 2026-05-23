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

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
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
    # Wildcard cert with a SAN for the apex — usable by ALBs, API Gateway,
    # and EKS Ingresses in the primary region.
    "platform" = {
      domain_name = var.public_zone_name
      subject_alternative_names = [
        "*.${var.public_zone_name}",
      ]
    }

    # CloudFront wants its cert in us-east-1; this requests an additional
    # us-east-1 copy via the aws.us_east_1 alias.
    "cloudfront" = {
      domain_name = "cdn.${var.public_zone_name}"
      subject_alternative_names = [
        "assets.${var.public_zone_name}",
      ]
      also_in_regions = ["us-east-1"]
    }
  }

  key_algorithm = "RSA_2048"

  tags = {
    Owner      = "platform-team"
    Compliance = "sox"
  }
}
