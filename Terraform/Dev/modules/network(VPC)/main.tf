#Create VPC 
resource "aws_vpc" "" {
  cidr_block = "10.0.0.0/16"
}

# Reference the default vpc
data "aws_vpc" "default_vpc" {
  id = var.default_vpc_id
}

# Create an Internet Gateway for the VPC

# Create public subnet 

# Create public subnet two 

# Create private subnet 1 az1

# Create private subnet 2 az1

# Create private subnet 1 az2

# Create private subnet 2 az2

# Create a route table for the public subnets

# Associate the route table with both of the public subnets

# Create Elastic IP for the first NAT Gateway az1

# Create Elastic IP for the second NAT Gateway az2

# Create NAT Gateway for az1 

# Create NAT Gateway for az2

# Create a route table for the private subnets in az1 

# Associate the route table with both private subnets in az1

# Create a route table for the private subnets in az2

# Associate the route table with both private subnets in az2

# Create a VPC Peering Connection between the default VPC and the Terraform-created VPC

resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id        = data.aws_vpc.default_vpc.id  # default VPC ID
  peer_vpc_id   = ""           # Accepter VPC ID which is our custom VPC
  auto_accept   = true  # Automatically accept the peering connection
}

# Add a route to the default VPC's route table 
resource "aws_route" "default_vpc_to_vpc" {
  route_table_id         = var.default_route_table_id  # Route Table ID of the manual VPC
  destination_cidr_block = "" #Our custom VPC's cidr block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

# Define the routes for the public route table
resource "aws_route" "public_to_default" {
  route_table_id         = aws_route_table.my_public_route_table.id  
  destination_cidr_block = data.aws_vpc.default_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

# Define the routes for the first private route table it will be similar to the preceding 


# Define the routes for the second private route table it will be similar to the preceding 
