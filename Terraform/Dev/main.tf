terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.73.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "0.7.0"  # specify the version you want
    }
  }
}

provider "aws" {
  region     = var.region
}

resource "time_static" "start" {
  id = "start"
}

module "VPC" {
  source = "./modules/network"
}

module "RDS" {
  source = "./modules/database"
  vpc_id = module.VPC.vpc_id
  private_subnet_id_2_az1 = module.VPC.private_subnet_id_2_az1
  private_subnet_id_2_az2 = module.VPC.private_subnet_id_2_az2
  db_password = var.db_password
  depends_on = [module.VPC] 
}

module "EC2" {
  source = "./modules/compute"
  vpc_id = module.VPC.vpc_id
  private_subnet_id_1_az1 = module.VPC.private_subnet_id_1_az1
  private_subnet_id_1_az2 = module.VPC.private_subnet_id_1_az2
  public_subnet_id_1 = module.VPC.public_subnet_id_1
  public_subnet_id_2 = module.VPC.public_subnet_id_2
  rds_endpoint = module.RDS.rds_endpoint
  app_security_group_id = module.VPC.app_security_group_id
  dockerhub_username = var.dockerhub_username
  dockerhub_password = var.dockerhub_password
  django_key = var.django_key
}

resource "time_static" "end" {
  id = "end"
}

# Calculate duration (output)
output "total_duration" {
  value = time_static.end.time - time_static.start.time
  description = "The total duration of the Terraform deployment in seconds."
}