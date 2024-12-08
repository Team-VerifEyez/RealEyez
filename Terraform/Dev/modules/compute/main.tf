# This is where we will be creating our load balancer and are ec2 instances which will 
# be our kubernetes worker nodes, we need to look into exactly how to do this. 

# Create bastion hosts  
resource "aws_instance" "realeyez_bastion_az1"{
  ami               = var.ami                                                                          
  instance_type     = var.instance_type
  # Attach an existing security group to the instance.
  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]
  key_name          = "team5" # The key pair name for SSH access to the instance.
  subnet_id         = var.public_subnet_id_1
  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "realeyez_bastion_az1"         
  }

}

resource "aws_instance" "realeyez_bastion_az2"{
  ami               = var.ami                                                                          
  instance_type     = var.instance_type
  # Attach an existing security group to the instance.
  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]
  key_name          = "team5" # The key pair name for SSH access to the instance.
  subnet_id         = var.public_subnet_id_2
  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "realeyez_bastion_az2"         
  }

}

# Security Group for the bastion host
resource "aws_security_group" "bastion_security_group" {
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

# Create app instances in AWS. 
resource "aws_instance" "realeyez_app_az1"{
  ami               = var.ami                                                                          
  instance_type     = var.instance_type

  # Attach an existing security group to the instance.
  vpc_security_group_ids = [var.app_security_group_id]
  key_name          = "team5" # The key pair name for SSH access to the instance.
  subnet_id         = var.private_subnet_id_1_az1
  user_data         = base64encode(templatefile("./deploy.sh", {
    rds_endpoint = var.rds_endpoint,
    docker_user = var.dockerhub_username,
    docker_pass = var.dockerhub_password,
    docker_compose = templatefile("./compose.yml", {
      rds_endpoint = var.rds_endpoint
      run_migrations = "true"
    })
  }))

  root_block_device {
    volume_size = 30 # Specify the size of the root volume in GB
    volume_type = "gp3" # Optional: Specify the volume type (e.g., gp2, gp3, io1, etc.)
  }

  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "realeyez_app_az1"         
  }
}

resource "aws_instance" "realeyez_app_az2"{
  ami               = var.ami                                                                          
  instance_type     = var.instance_type

  # Attach an existing security group to the instance.
  vpc_security_group_ids = [var.app_security_group_id]
  key_name          = "team5" # The key pair name for SSH access to the instance.
  subnet_id         = var.private_subnet_id_1_az2
  user_data         = base64encode(templatefile("./deploy.sh", {
    rds_endpoint = var.rds_endpoint,
    docker_user = var.dockerhub_username,
    docker_pass = var.dockerhub_password,
    docker_compose = templatefile("./compose.yml", {
      rds_endpoint = var.rds_endpoint
      run_migrations = "false"
    })
  }))

  root_block_device {
    volume_size = 30 # Specify the size of the root volume in GB
    volume_type = "gp3" # Optional: Specify the volume type (e.g., gp2, gp3, io1, etc.)
  }

  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "realeyez_app_az2"         
  }
}

####################################################
## Referencing IP Address 
####################################################
data "template_file" "prometheus_config" {
  depends_on = [
    aws_instance.realeyez_app_az1,
    aws_instance.realeyez_app_az2
  ]
  template = file("${path.module}/prometheus.tpl")

  vars = {
    targets = join(",", [
      "${aws_instance.realeyez_app_az1.private_ip}:9100",
      "${aws_instance.realeyez_app_az2.private_ip}:9100"
    ])
  }
}

####################################################
## Creating Monitoring Instance
####################################################
resource "aws_instance" "monitoring" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.default_subnet_id
  key_name               = "team5" # The key pair name for SSH access to the instance.
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  user_data = <<EOF
#!/bin/bash
# Redirect stdout and stderr to a log file
exec > /var/log/user-data.log 2>&1

# Update and install Docker
sudo apt update -y
sudo apt install -y docker.io

# Enable and start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Run Prometheus container
sudo docker run -d --name prometheus -p 9090:9090 prom/prometheus

# Wait for Prometheus to start
until sudo docker ps -q -f name=prometheus; do
    echo "Waiting for Prometheus to start..."
    sleep 5
done

# Write configuration to host and copy it to the container
echo '${data.template_file.prometheus_config.rendered}' > /tmp/prometheus.yml

# Copy the configuration file into the Prometheus container
sudo docker cp /tmp/prometheus.yml prometheus:/etc/prometheus/prometheus.yml

# Restart Prometheus to apply the new configuration
sudo docker restart prometheus

# Run Grafana container
sudo docker run -d --name grafana -p 3000:3000 grafana/grafana

EOF

tags = {
    "Name" : "realeyez_monitoring"         
  }
}




resource "aws_security_group" "monitoring_sg" {
  name_prefix = "monitoring"
  vpc_id      = var.default_vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana"
  }

  # Egress (outbound) rule to allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}


# Create Security Group for the Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  vpc_id     = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]  # Allow HTTP traffic from anywhere
  }

  # Egress (outbound) rule to allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}

# Create Target Group for the Load Balancer
resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold  = 2
    unhealthy_threshold = 2
  }
}

# Create Load Balancer
resource "aws_lb" "my_lb" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]

  enable_deletion_protection = false

  subnets = [
    var.public_subnet_id_1,
    var.public_subnet_id_2
  ]
}

# Create Listener for Load Balancer
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

# Register EC2 Instances to the Target Group
resource "aws_lb_target_group_attachment" "instance1" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.realeyez_app_az1.id
  port             = 8000
}

resource "aws_lb_target_group_attachment" "instance2" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.realeyez_app_az2.id
  port             = 8000
}

