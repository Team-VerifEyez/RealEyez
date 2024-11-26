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

# Define the RDS module (look at the main.tf in the Prod dir for hints)


# Define the RDS module (look at the main.tf in the Prod dir for hints)
