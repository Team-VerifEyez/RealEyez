# Define an RDS PostgreSQL database instance

# Define a subnet group for RDS (The subnet id's will be private_subnet_id_2_az1 and private_subnet_id_2_az2)

# Define a security group for RDS instance

# Output the RDS endpoint for use in other modules or outputs
output "rds_endpoint" {
  value = aws_db_instance.postgres_db.address
}