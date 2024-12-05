provider "aws" {
    region = "us-east-1"  
    access_key = "AKIAUMYCIUCTEIXHKHSH"
    secret_key = "var.aws_secret_key"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "testvpc" 
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
    tags = {
    Name = "Internet_Gateway"
  }
}

resource "aws_subnet" "public_subnet1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public Subnet 1Demo"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1b"

  tags = {
    Name = "Public Subnet 2Demo"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
}

# resource "aws_subnet" "private_subnet2" {
#   vpc_id            = aws_vpc.main.id
#   cidr_block        = "10.0.4.0/24"
#   availability_zone = "us-east-1b"
# }

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet1.id
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_rta1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

# resource "aws_route_table_association" "public_rta2" {
#   subnet_id      = aws_subnet.public_subnet2.id
#   route_table_id = aws_route_table.public_route_table.id
# }

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
}

resource "aws_route_table_association" "private_rta1" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_route_table.id
}

# resource "aws_route_table_association" "private_rta2" {
#   subnet_id      = aws_subnet.private_subnet2.id
#   route_table_id = aws_route_table.private_route_table.id
# }

##############################################
# SECURITY GROUP FOR BOTH ECOMMERCE APP EC2S #
##############################################

resource "aws_security_group" "sg_ecomm_app" { # name that terraform recognizes
  name        = "sg_ecomm_app" # name that will show up on AWS
  description = "Security Group for Ecommerce App EC2s"
 
  vpc_id = aws_vpc.main.id
  # Ingress rules: Define inbound traffic that is allowed. 
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 

  ingress {
    description = "PostgresSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 

  # Egress rules: Define outbound traffic that is allowed. The below configuration allows all outbound traffic from the instance.
  egress {
    from_port   = 0                                     # Allow all outbound traffic (from port 0 to any port)
    to_port     = 0
    protocol    = "-1"                                  # "-1" means all protocols
    cidr_blocks = ["0.0.0.0/0"]                         # Allow traffic to any IP address
  }

  # Tags for the security group
  tags = {
    "Name"      = "sg_ecomm_app"                          # Name tag for the security group
    "Terraform" = "true"                                # Custom tag to indicate this SG was created with Terraform
  }
}

# Create app instances in AWS. 
resource "aws_instance" "test_app"{
  ami               = "ami-0866a3c8686eaeeba"                                                                          
  instance_type     = "t3.micro"
  # Attach an existing security group to the instance.
  vpc_security_group_ids = aws_security_group.sg_ecomm_app.id
  key_name          = "team5" # The key pair name for SSH access to the instance.
  subnet_id         = aws_subnet.private_subnet1.id
  user_data         = base64encode(templatefile("./deploy.sh", {
      docker_compose = templatefile("./compose.yml")}))

  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "test_app"         
  }
}
# output "subnet_ids" {
#   value = [
#     aws_subnet.public_subnet1.id,
#     aws_subnet.public_subnet2.id,
#     aws_subnet.private_subnet1.id,
#     aws_subnet.private_subnet2.id,
#   ]
# }

# resource "local_file" "subnet_ids_file" {
#   content = join("\n", [
#     aws_subnet.public_subnet1.id,
#     aws_subnet.public_subnet2.id,
#     aws_subnet.private_subnet1.id,
#     aws_subnet.private_subnet2.id,
#   ])
#   filename = "subnets.txt"
# }

