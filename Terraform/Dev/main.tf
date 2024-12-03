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
  private_subnet_cidr_az1 = module.VPC.priv_sub1_az1.cidr_block
  private_subnet_cidr_az2 = module.VPC.priv_sub1_az2.cidr_block
  depends_on = [module.VPC]
}

module "Kubernetes" {
  source = "./modules/kubernetes"
  vpc_id = module.VPC.vpc_id
  private_subnet_id_1_az1 = module.VPC.private_subnet_id_1_az1
  private_subnet_id_1_az2 = module.VPC.private_subnet_id_1_az2
  public_subnet_id_1 = module.VPC.public_subnet_id_1
  public_subnet_id_2 = module.VPC.public_subnet_id_2
  rds_instance_id = module.RDS.rds_instance_id
  rds_security_group_id = module.RDS.rds_security_group_id
  db_username = module.RDS.db_username
  rds_endpoint = module.RDS.rds_endpoint
  bastion_sg_id = ""
  depends_on = [module.VPC]
}