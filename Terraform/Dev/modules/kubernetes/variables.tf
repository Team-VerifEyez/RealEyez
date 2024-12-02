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