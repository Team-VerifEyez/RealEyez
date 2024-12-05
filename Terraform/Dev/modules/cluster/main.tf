# Terraform data source that retrieves information about the AWS account 
# Associated with the credentials used to run Terraform.
data "aws_caller_identity" "current" {}

# Create IAM roles for the EKS cluster and worker nodes.
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}


# Worker Node Role:
resource "aws_iam_role" "eks_worker_role" {
  name = "eks-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_worker_role.name
}

resource "aws_iam_role_policy_attachment" "worker_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_worker_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_worker_role.name
}

resource "aws_iam_instance_profile" "eks_workers_profile" {
  name = "eks-workers-profile"
  role = aws_iam_role.eks_worker_role.name
}

# Create the EKS cluster using the private subnets.
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      var.private_subnet_id_1_az1,
      var.private_subnet_id_1_az2,
    ]
  }

  # Optional: Kubernetes version
  version = "1.28"

  # Tags for the cluster
  tags = {
    Environment = "test"
    Team        = "Verifeye"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy
  ]
}

data "aws_eks_cluster_auth" "eks_cluster" {
  name = aws_eks_cluster.eks_cluster.name
}

#Install node exporter on the worker nodes
resource "aws_launch_template" "eks_workers" {
  name          = "eks-worker-template"
  instance_type = "t3.medium"
  # Specify the key pair for SSH access
  key_name = "team5"
  # User data for custom configurations
  user_data = base64encode(file("./multipart_user_data.txt"))


  block_device_mappings {
    device_name = "/dev/xvda" # Default device name for root volume
    ebs {
      volume_size           = 20   # Disk size (in GB)
      volume_type           = "gp2" # General Purpose SSD
      delete_on_termination = true
    }
  }

}


# Add a managed node group to span the private subnets and create two nodes per subnet.
# This creates a total of four nodes, two in each subnet.
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "my-node-group"
  node_role_arn   = aws_iam_role.eks_worker_role.arn
  subnet_ids      = [
    var.private_subnet_id_1_az1,
    var.private_subnet_id_1_az2,
  ]

  scaling_config {
    desired_size = 4
    max_size     = 6
    min_size     = 4
  }

  launch_template {
    id      = aws_launch_template.eks_workers.id
    version = aws_launch_template.eks_workers.latest_version
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.worker_cni_policy,
    aws_iam_role_policy_attachment.ec2_policy
  ]
}

# Dynamically identify the worker node security group
data "aws_security_group" "eks_worker_sg" {
  filter {
    name   = "tag:kubernetes.io/cluster/${aws_eks_cluster.eks_cluster.name}"
    values = ["owned"]
  }
}

# Add ingress rule for port 8000
resource "aws_security_group_rule" "allow_port_8000" {
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  security_group_id = data.aws_security_group.eks_worker_sg.id
  cidr_blocks = ["10.0.0.0/16"] 
}

#How the hell are we going to set up a bastion host for worker nodes
resource "aws_security_group_rule" "allow_bastion_ssh_to_workers" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.eks_worker_sg.id # Worker node SG
  source_security_group_id = var.bastion_sg_id
}

# Rule for node exporter
resource "aws_security_group_rule" "allow_port_9100" {
  type              = "ingress"
  from_port         = 9100
  to_port           = 9100
  protocol          = "tcp"
  security_group_id = data.aws_security_group.eks_worker_sg.id
  cidr_blocks       = ["0.0.0.0/0"] 
}

# Output Values
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_cluster_certificate_authority" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_id" {
  value = aws_eks_cluster.eks_cluster.id
}

output "eks_identity_debug" {
  value = aws_eks_cluster.eks_cluster.identity
}

output "eks_oidc_issuer" {
  value = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer
}

output "eks_cluster_auth_token" {
  value = data.aws_eks_cluster_auth.eks_cluster.token
}
