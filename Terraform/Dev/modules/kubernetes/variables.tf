variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
}

variable "private_subnet_id_1_az1" {
}

variable "private_subnet_id_1_az2" {
}

variable "rds_security_group_id" {
  description = "The security group ID of the RDS instance"
  type        = string
}
variable "rds_endpoint" {
}

variable "cluster_certificate_authority" {
}

variable "cluster_endpoint" {
}

variable "cluster_auth_token" {
}

variable "cluster_oidc_issuer" {
}

variable "cluster_name" {
}

variable "cluster_id" {
}

variable "rds_instance_id" {
}

variable "db_username" {
}