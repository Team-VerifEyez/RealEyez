
# Define an RDS PostgreSQL database instance
resource "aws_db_instance" "postgres_db" {
  identifier           = "ecommerce-db"
  engine               = "postgres"
  engine_version       = "14.13"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "standard"
  db_name              = "Realeyez"
  username             = "team1"
  password             = "wewin"
  parameter_group_name = "default.postgres14"
  skip_final_snapshot  = true

  db_subnet_group_name   = aws_db_subnet_group.rds_subgroup.name
  vpc_security_group_ids = [aws_security_group.sg_for_rds.id]

  tags = {
    Name = "Ecommerce Postgres DB"
  }
}

# Define a subnet group for RDS (The subnet id's will be private_subnet_id_2_az1 and private_subnet_id_2_az2)

resource "aws_db_subnet_group" "rds_subgroup" {
  name       = "rds_subnet_group"
  subnet_ids = [aws_subnet.priv_sub2_az1.id, aws_subnet.priv_sub2_az2.id]

  tags = {
    Name = "RDS Subnet Group"
  }
}

# Define a security group for RDS instance
resource "aws_security_group" "sg_for_rds" {
  name        = "rds_sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.customvpc.id

  ingress {
    from_port       = 5432 #for PostgreSQL
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_back1.id] #CHECK - don't have this yet
  }

  # ingress {
  #   from_port   = 9100 #probably dont need this right?
  #   to_port     = 9100
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

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