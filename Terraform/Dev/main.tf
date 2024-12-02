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
  vpc_id = module.VPC.vpc_id
  private_subnet_id_2_az1 = module.VPC.private_subnet_id_2_az1
  private_subnet_id_2_az2 = module.VPC.private_subnet_id_2_az2
  depends_on = [module.VPC]
}

module "Kubernetes" {
  source = "./modules/kubernetes"
  vpc_id = module.VPC.vpc_id
  private_subnet_id_1_az1 = module.VPC.private_subnet_id_1_az1
  private_subnet_id_1_az2 = module.VPC.private_subnet_id_1_az2
  public_subnet_id_1 = module.VPC.public_subnet_id_1
  public_subnet_id_2 = module.VPC.public_subnet_id_2
  depends_on = [module.VPC]
}