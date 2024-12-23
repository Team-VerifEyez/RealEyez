# Create Custom VPC 
resource "aws_vpc" "customvpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "realeyez" 
  }
}

# Reference the Default VPC
data "aws_vpc" "default_vpc" {
  id = var.default_vpc_id
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.customvpc.id

  tags = {
    Name = "Internet_Gateway"
  }
}

# Create a VPC Peering Connection between the default VPC and the Terraform-created VPC
resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id        = data.aws_vpc.default_vpc.id  # default VPC ID
  peer_vpc_id   = aws_vpc.customvpc.id           # Accepter VPC ID which is our custom VPC
  auto_accept   = true  # Automatically accept the peering connection
  
  tags = {
    Name = "Default-to-Custom-Peering"
  }

}

# Add a route to the default VPC's route table 
resource "aws_route" "default_vpc_to_vpc" {
  route_table_id         = var.default_route_table_id  # Route Table ID of the manual VPC
  destination_cidr_block = "10.0.0.0/16" #Our custom VPC's cidr block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

# Availability Zone 1: 
# Create public subnet 1 (AZ1) 
resource "aws_subnet" "pub_sub_az1" {
  vpc_id     = aws_vpc.customvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "pub_sub_az1" 
  }
}

# Create private subnet 1 (AZ1)
resource "aws_subnet" "priv_sub1_az1" {
  vpc_id     = aws_vpc.customvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "priv_sub1_az1"
  }
}

# Create private subnet 2 (AZ1)
resource "aws_subnet" "priv_sub2_az1" {
  vpc_id     = aws_vpc.customvpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "priv_sub2_az1"
  }
}

# Availability Zone 2
# Create public subnet 2 (AZ2) 
resource "aws_subnet" "pub_sub_az2" {
  vpc_id     = aws_vpc.customvpc.id
  cidr_block = "10.0.4.0/24" 
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "pub_sub_az2" 
  }
}

# Create private subnet 1 (AZ2) 
resource "aws_subnet" "priv_sub1_az2" {
  vpc_id     = aws_vpc.customvpc.id
  cidr_block = "10.0.5.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "priv_sub1_az2"
  }
}

# Create private subnet 2 az2
resource "aws_subnet" "priv_sub2_az2" {
  vpc_id     = aws_vpc.customvpc.id
  cidr_block = "10.0.6.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "priv_sub2_az2"
  }
}
# Create a route table for the public subnets
resource "aws_route_table" "pub_rt_main" {
  vpc_id = aws_vpc.customvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
  route {
    cidr_block                = data.aws_vpc.default_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
  }
  
  tags = {
    Name = "pub_rt_main" 
  }

  depends_on = [aws_vpc_peering_connection.vpc_peering]
}

# Associate the route table with both of the public subnets
resource "aws_route_table_association" "pub_rt_assc1" {
  subnet_id      = aws_subnet.pub_sub_az1.id
  route_table_id = aws_route_table.pub_rt_main.id

}

resource "aws_route_table_association" "pub_rt_assc2" {
  subnet_id      = aws_subnet.pub_sub_az2.id
  route_table_id = aws_route_table.pub_rt_main.id

}


# Create Elastic IP for the first NAT Gateway (AZ1)
resource "aws_eip" "elastic1" {
  domain   = "vpc"

  tags = {
    Name = "elastic1_ip"
  }
}

# Create Elastic IP for the second NAT Gateway (AZ2)
resource "aws_eip" "elastic2" {
  domain   = "vpc"

  tags = {
    Name = "elastic2_ip"
  }
}

# Create NAT Gateway for AZ1 
resource "aws_nat_gateway" "nat1" {
  allocation_id = aws_eip.elastic1.id
  subnet_id = aws_subnet.pub_sub_az1.id

  tags = {
    Name = "NAT_Gateway1" 
  }
  
  depends_on = [aws_internet_gateway.ig]
}

# Create NAT Gateway for AZ2
resource "aws_nat_gateway" "nat2" {
  allocation_id = aws_eip.elastic2.id
  subnet_id = aws_subnet.pub_sub_az2.id
 
  tags = {
    Name = "NAT_Gateway2" 
  }

  depends_on = [aws_internet_gateway.ig]
}

# Create a route table for the private subnets in AZ1 
resource "aws_route_table" "priv_rt_az1" {
  vpc_id = aws_vpc.customvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat1.id
  }

  route {
    cidr_block                = data.aws_vpc.default_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id 
  }

  tags = {
    Name = "priv_rt_az1" 
  }

  depends_on = [aws_vpc_peering_connection.vpc_peering]
}


# Associate the private route table with both private subnets in AZ1
resource "aws_route_table_association" "pri_rt_assc1_az1" {
  subnet_id      = aws_subnet.priv_sub1_az1.id
  route_table_id = aws_route_table.priv_rt_az1.id

}
resource "aws_route_table_association" "pri_rt_assc2_az1" {
  subnet_id      = aws_subnet.priv_sub2_az1.id
  route_table_id = aws_route_table.priv_rt_az1.id

}
# Create a private route table for the private subnets in AZ2
resource "aws_route_table" "priv_rt_az2" {
  vpc_id = aws_vpc.customvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat2.id
  }

  route {
    cidr_block                = data.aws_vpc.default_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id 
  }

  tags = {
    Name = "priv_rt_az2" 
  }

  depends_on = [aws_vpc_peering_connection.vpc_peering]
}
# Associate the private route table with both private subnets in AZ2
resource "aws_route_table_association" "pri_rt_assc1_az2" {
  subnet_id      = aws_subnet.priv_sub1_az2.id
  route_table_id = aws_route_table.priv_rt_az2.id

}
resource "aws_route_table_association" "pri_rt_assc2_az2" {
  subnet_id      = aws_subnet.priv_sub2_az2.id
  route_table_id = aws_route_table.priv_rt_az2.id

}

#Creating this here so that its available for the RDS
resource "aws_security_group" "app_security_group" {
  name        = "app_sg"
  description = "Security group for our app"
  vpc_id = aws_vpc.customvpc.id

  # Ingress (inbound) rules
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from any IP
  }

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from any IP
  }

  ingress {
    description = "Django runs on port 8000"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow inbound traffic on Node Exporters default port 9100"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress (outbound) rule to allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }

  tags = {
    Name : "app_sg"
    Terraform : "true"
  }
}
