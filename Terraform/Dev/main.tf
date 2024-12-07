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
  private_subnet_cidr_az1 = module.VPC.private_subnet_cidr_az1
  private_subnet_cidr_az2 = module.VPC.private_subnet_cidr_az2
  depends_on = [ module.VPC ]
}

module "Compute" {
  source = "./modules/compute"
  vpc_id = module.VPC.vpc_id
  public_subnet_id_1 = module.VPC.public_subnet_id_1
  public_subnet_id_2 = module.VPC.public_subnet_id_2
  depends_on = [module.RDS]
}

module "Cluster" {
  source = "./modules/cluster"
  private_subnet_id_1_az1 = module.VPC.private_subnet_id_1_az1
  private_subnet_id_1_az2 = module.VPC.private_subnet_id_1_az2
  bastion_sg_id = module.Compute.bastion_secuirty_group_id
  depends_on = [ module.Compute ]
}

output "cluster_endpoint" {
  value = module.Cluster.eks_cluster_endpoint
}

output "cluster_certificate_authority" {
  value = module.Cluster.eks_cluster_certificate_authority
}

output "oidc_issuer" {
  value = module.Cluster.eks_oidc_issuer
}

output "cluster_auth_token" {
  value = module.Cluster.eks_cluster_auth_token
  sensitive = true

}