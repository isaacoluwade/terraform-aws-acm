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
    "main" = {
      domain_name = var.domain_name
    }
  }

  tags = {
    Owner = "ci-terratest"
  }
}
