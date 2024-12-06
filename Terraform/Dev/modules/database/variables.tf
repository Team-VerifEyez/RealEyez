variable "db_instance_class" {
  description = "The instance type of the RDS instance"
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "The name of the database to create when the DB instance is created"
  type        = string
  default     = "Realeyez"
}

variable "db_username" {
  description = "Username for the master DB user"
  type        = string
  default     = "team1"
}

variable "db_password" {
    description = "password for db user"
    type = string
    default = "wewin"
}

variable "vpc_id" {
}

variable "private_subnet_id_2_az1" {
}

variable "private_subnet_id_2_az2" {
}