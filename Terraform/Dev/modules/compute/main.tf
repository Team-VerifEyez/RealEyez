# Might need to keep this here to create some bastion host

resource "aws_security_group" "bastion_secuirty_group" {
  name        = "bastion_sg"
  description = "Security group for jumpbox"
  vpc_id = var.vpc_id

  # Ingress (inbound) rules
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from any IP
  }

  # Egress (outbound) rule to allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }

  tags = {
    Name : "bastion_sg"
    Terraform : "true"
  }
}

# Create bastion hosts  
resource "aws_instance" "bastion_az1"{
  ami               = var.ami                                                                          
  instance_type     = var.instance_type
  # Attach an existing security group to the instance.
  vpc_security_group_ids = [aws_security_group.bastion_secuirty_group.id]
  key_name          = "team5" # The key pair name for SSH access to the instance.
  subnet_id         = var.public_subnet_id_1
  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "bastion_az1"         
  }

}

resource "aws_instance" "bastion_az2"{
  ami               = var.ami                                                                          
  instance_type     = var.instance_type
  # Attach an existing security group to the instance.
  vpc_security_group_ids = [aws_security_group.bastion_secuirty_group.id]
  key_name          = "team5" # The key pair name for SSH access to the instance.
  subnet_id         = var.public_subnet_id_2
  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "bastion_az1"         
  }

}

output "bastion_secuirty_group_id" {
  value = aws_security_group.bastion_secuirty_group.id
}