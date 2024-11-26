terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.73.0"
    }
  }
}

provider "aws" {
  region     = var.region
}

module "VPC" {
  source = "./modules/network"
}

module "RDS" {
  source = "./modules/database"
  # You will need to provide the values for the variables here:

  # The VPC module needs to be created before this module:
  depends_on = [module.VPC]
}

module "EC2" {
  source = "./modules/compute"
  # You will to provide the values for the variables here:

  # This module depends on the RDS module:
  depends_on = [module.RDS]
}