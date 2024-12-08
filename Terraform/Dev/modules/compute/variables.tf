variable "vpc_id" {
}

variable "instance_type" {
  description = "The type of EC2 instance to use"
  type        = string
  default     = "t3.medium"
}

variable "public_subnet_id_1" {
}

variable "public_subnet_id_2" {
}

variable "private_subnet_id_1_az1" {
}

variable "private_subnet_id_1_az2" {
}

# Double check to make sure that this is the right machine image
variable "ami" {
  description = "The Amazon Machine Image (AMI) ID used to launch the EC2 instance."
  type = string
  default = "ami-0866a3c8686eaeeba"
}

variable "rds_endpoint" {
}

variable "dockerhub_username" {
}

variable "dockerhub_password" {
}

variable "app_security_group_id" {
}

variable "default_vpc_id" {
  description = "The default Vpc ID"
  type = string
  default = "vpc-032011d00cb9f7c50"
}

variable "default_subnet_id" {
  description = "The default Subnet ID"
  type = string
  default = "subnet-054c80d005b955d6c"
}

