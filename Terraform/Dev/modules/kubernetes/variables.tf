variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
}

variable "public_subnet_id_1" {
}

variable "public_subnet_id_2" {
}

variable "private_subnet_id_1_az1" {
}

variable "private_subnet_id_1_az2" {
}


variable "rds_instance_id" {
  description = "The ID of the RDS instance"
  type        = string
}

variable "rds_security_group_id" {
  description = "The security group ID of the RDS instance"
  type        = string
}

variable "db_username" {
  description = "The username for the PostgreSQL database"
  type        = string
}

variable "rds_endpoint" {
}

variable "bastion_sg_id" {
}