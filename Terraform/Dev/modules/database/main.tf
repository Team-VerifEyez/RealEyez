# Define an RDS PostgreSQL database instance
resource "aws_db_instance" "postgres_db" {
  identifier           = "realeyez-db"
  engine               = "postgres"
  engine_version       = "14.13"
  instance_class       = var.db_instance_class # will need a different instance type e.g., "db.m5.large"
  allocated_storage    = 20
  storage_type         = "standard"
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.postgres14"
  multi_az             = false  # Enable Multi-AZ failover
  skip_final_snapshot  = true

  # Encryption configuration
  storage_encrypted   = true

  db_subnet_group_name   = aws_db_subnet_group.rds_subgroup.name
  vpc_security_group_ids = [aws_security_group.sg_for_rds.id]

  tags = {
    Name = "Realeyez Postgres DB"
  }
}

# Define a subnet group for RDS (The subnet id's will be private_subnet_id_2_az1 and private_subnet_id_2_az2)
resource "aws_db_subnet_group" "rds_subgroup" {
  name       = "rds_subnet_group"
  subnet_ids = [var.private_subnet_id_2_az1, var.private_subnet_id_2_az2]

  tags = {
    Name = "RDS Subnet Group"
  }
}

# Define a security group for RDS instance
resource "aws_security_group" "sg_for_rds" {
  name        = "rds_sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432 #for PostgreSQL
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks = ["10.0.2.0/24", "10.0.5.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS Security Group"
  }
}

# Output the RDS endpoint for use in other modules or outputs
output "rds_endpoint" {
  value = aws_db_instance.postgres_db.address
}