# The kubernetes provider is necessary to interact with the Kubernetes cluster created by EKS.
provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_cluster.token
}

# Helm Provider
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks_cluster.token # Where is this coming from??
  }
}

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
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSCNIPolicy"
  role       = aws_iam_role.eks_worker_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_worker_role.name
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
  user_data     = base64encode(file("Terraform/Dev/install_node_exporter.sh"))

  iam_instance_profile {
    name = aws_iam_instance_profile.eks_workers_profile.name
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
    version = "$Latest"
  }

  instance_types = ["t3.medium"]
  disk_size      = 20

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
  security_group_id = data.aws_security_group.worker_sg.id
  cidr_blocks       = ["0.0.0.0/0"] 
}


# OIDC Provider for Service Account Mapping
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b36a5d1596b6ec982"]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc.issuer
}

# IAM Role for RDS Access
resource "aws_iam_role" "rds_access_role" {
  name = "eks-rds-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks_oidc.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "oidc.eks.${var.region}.amazonaws.com/id/${aws_eks_cluster.eks_cluster.id}:sub" = "system:serviceaccount:default:postgres-service-account"
        }
      }
    }]
  })
}

# Attach IAM Policy for RDS Access
resource "aws_iam_role_policy" "rds_access_policy" {
  name = "eks-rds-access-policy"
  role = aws_iam_role.rds_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["rds-db:connect"]
      Resource = [
        "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${var.rds_instance_id}/${var.db_username}"
      ]
    }]
  })
}

# Kubernetes Service Account for PostgreSQL
resource "kubernetes_service_account" "postgres_service_account" {
  metadata {
    name      = "postgres-service-account"
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.rds_access_role.arn
    }
  }
}

# IAM Role for Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller_role" {
  name = "aws-load-balancer-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks_oidc.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "oidc.eks.us-east-1.amazonaws.com/id/${aws_iam_openid_connect_provider.eks_oidc.url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancerControllerPolicy"
  role       = aws_iam_role.aws_load_balancer_controller_role.name
}

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller_role.arn
    }
  }
}

# Helm Chart for AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks_cluster.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
  }

  # Add region and vpcId as configuration parameters
  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  # Optionally force pod recreation during updates
  recreate_pods = true
}

resource "null_resource" "wait_for_lb_controller" {
  depends_on = [
    helm_release.aws_load_balancer_controller
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for AWS Load Balancer Controller pods..."
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s
    EOT
  }
}

# Cert Manager Installation
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "v1.12.0"  # Adjust the version as needed

  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Self-Signed Cluster Issuer
resource "kubernetes_manifest" "selfsigned_cluster_issuer" {
  depends_on = [helm_release.cert_manager] # Ensure cert-manager is deployed first

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned-cluster-issuer"  # You can choose any name for your self-signed issuer
    }
    spec = {
      selfSigned = {}  # Defines a self-signed certificate issuer
    }
  }
}

resource "null_resource" "wait_for_certificate" {
  depends_on = [
    kubernetes_manifest.selfsigned_cluster_issuer,
    helm_release.cert_manager
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for certificate to be issued..."
      kubectl wait --for=condition=ready certificate aws-load-balancer-serving-cert -n kube-system --timeout=300s
    EOT
  }
}

################################## APPLICATION DEPLOYMENT #############################################
# resource "kubernetes_deployment" "example_app" {}

# resource "kubernetes_service" "example_service" {}

# resource "kubernetes_manifest" "example_ingress" {} 