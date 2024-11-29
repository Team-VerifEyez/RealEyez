provider "aws" {
    region = "us-east-1"  
    access_key = "#Enter account keys"
    secret_key = "#Enter account keys"
}

# --------------------------------------------------------
# RESOURCE 0: KUBERNETES
# --------------------------------------------------------
provider "kubernetes" {
  config_path = "~/.kube/config" # Path to kubeconfig file
  config_context = "my-cluster" # Context name (optional)
  host = module.eks.cluster_endpoint
  token = module.eks.kubeconfig["token"]
  cluster_ca_certificate = base64decode(module.eks.kubeconfig["cluster_ca_certificate"])
}

# --------------------------------------------------------
# RESOURCE 1: VPC
# --------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# --------------------------------------------------------
# RESOURCE 2: INTERNET GATEWAY
# --------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# --------------------------------------------------------
# RESOURCE 3: PUBLIC SUBNET A
# --------------------------------------------------------
# Without proper tags, Kubernetes might fail to provision or associate the load balancer with the right subnets.
# The controller does not interpret the value 1 differently from other non-empty values. 
# It just checks if the tag exists and associates the subnet with ELB provisioning.
# "kubernetes.io/role/elb" tags public subnets, meaning they can host internet-facing load balancers.
# "kubernetes.io/role/internal-elb" tags private subnets for internal-only load balancers.

resource "aws_subnet" "public_subneta" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public Subnet A"
    "kubernetes.io/role/elb" = 1
  }
}

# --------------------------------------------------------
# RESOURCE 4: PUBLIC SUBNET B
# --------------------------------------------------------
resource "aws_subnet" "public_subnetb" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1b"

  tags = {
    Name = "Public Subnet B"
    "kubernetes.io/role/elb" = 1
  }
}

# --------------------------------------------------------
# RESOURCE 5: PRIVATE SUBNET A1
# --------------------------------------------------------
resource "aws_subnet" "private_subneta1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private Subnet A1"
    "kubernetes.io/role/internal-elb" = 1
  }
}

# --------------------------------------------------------
# RESOURCE 6: PRIVATE SUBNET A2
# --------------------------------------------------------
resource "aws_subnet" "private_subneta2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private Subnet 2A"
    "kubernetes.io/role/internal-elb" = 1
  }
}

# --------------------------------------------------------
# RESOURCE 7: PRIVATE SUBNET B1
# --------------------------------------------------------
resource "aws_subnet" "private_subnetb1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private Subnet B1"
    "kubernetes.io/role/internal-elb" = 1
  }
}

# --------------------------------------------------------
# RESOURCE 8: PRIVATE SUBNET B2
# --------------------------------------------------------
resource "aws_subnet" "private_subnetb2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private Subnet B1"
    "kubernetes.io/role/internal-elb" = 1
  }
}

# --------------------------------------------------------
# RESOURCE 9: EIP A
# --------------------------------------------------------
resource "aws_eip" "nata" {
  vpc = true
}

# --------------------------------------------------------
# RESOURCE 10: EIP B
# --------------------------------------------------------
resource "aws_eip" "natb" {
  vpc = true
}

# --------------------------------------------------------
# RESOURCE 11: NAT GATEWAY A
# --------------------------------------------------------
resource "aws_nat_gateway" "natgwa" {
  allocation_id = aws_eip.nata.id
  subnet_id     = aws_subnet.public_subneta.id
  depends_on    = [aws_internet_gateway.igw]
}

# --------------------------------------------------------
# RESOURCE 12: NAT GATEWAY B
# --------------------------------------------------------
resource "aws_nat_gateway" "natgwb" {
  allocation_id = aws_eip.natb.id
  subnet_id     = aws_subnet.public_subnetb.id
  depends_on    = [aws_internet_gateway.igw]
}

# --------------------------------------------------------
# RESOURCE 13: PUBLIC ROUTE TABLE
# --------------------------------------------------------
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# --------------------------------------------------------
# RESOURCE 14: PUBLIC RTB ASSOCIATION 1: PUBLIC SUBNET A
# --------------------------------------------------------
resource "aws_route_table_association" "public_rta1" {
  subnet_id      = aws_subnet.public_subneta.id
  route_table_id = aws_route_table.public_route_table.id
}

# --------------------------------------------------------
# RESOURCE 15: PUBLIC RTB ASSOCIATION 2: PUBLIC SUBNET B
# --------------------------------------------------------
resource "aws_route_table_association" "public_rta2" {
  subnet_id      = aws_subnet.public_subnetb.id
  route_table_id = aws_route_table.public_route_table.id
}

# --------------------------------------------------------
# RESOURCE 16: PRIVATE ROUTE TABLE A
# --------------------------------------------------------
resource "aws_route_table" "private_route_table_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgwa.id
  }
}

# --------------------------------------------------------
# RESOURCE 17: PRIVATE RTB A ASSOCIATION 1: PRIVATE SUBNET A1
# --------------------------------------------------------
resource "aws_route_table_association" "private_rtba1" {
  subnet_id      = aws_subnet.private_subneta1.id
  route_table_id = aws_route_table.private_route_table_a.id
}

# --------------------------------------------------------
# RESOURCE 18: PRIVATE RTB A ASSOCIATION 2: PRIVATE SUBNET A2
# --------------------------------------------------------
resource "aws_route_table_association" "private_rtba2" {
  subnet_id      = aws_subnet.private_subneta2.id
  route_table_id = aws_route_table.private_route_table_a.id
}

# --------------------------------------------------------
# RESOURCE 19: PRIVATE ROUTE TABLE B
# --------------------------------------------------------
resource "aws_route_table" "private_route_table_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgwb.id
  }
}

# --------------------------------------------------------
# RESOURCE 20: PRIVATE RTB B ASSOCIATION 1: PRIVATE SUBNET B1
# --------------------------------------------------------
resource "aws_route_table_association" "private_rtbb1" {
  subnet_id      = aws_subnet.private_subnetb1.id
  route_table_id = aws_route_table.private_route_table_b.id
}

# --------------------------------------------------------
# RESOURCE 21: PRIVATE RTB A ASSOCIATION 2: PRIVATE SUBNET B2
# --------------------------------------------------------
resource "aws_route_table_association" "private_rtbb2" {
  subnet_id      = aws_subnet.private_subnetb2.id
  route_table_id = aws_route_table.private_route_table_b.id
}


# --------------------------------------------------------
# RESOURCE 22: OUTPUT ALL SUBNET IDS
# --------------------------------------------------------
output "subnet_ids" {
  value = [
    aws_subnet.public_subnet1.id,
    aws_subnet.public_subnet2.id,
    aws_subnet.private_subneta1.id,
    aws_subnet.private_subneta2.id,
    aws_subnet.private_subnetb1.id,
    aws_subnet.private_subnetb2.id,
  ]
}
# Outputs subnet ids to a file using a local file resource
# resource "local_file" "subnet_ids_file" {
#   content = join("\n", [
#     aws_subnet.public_subnet1.id,
#     aws_subnet.public_subnet2.id,
#     aws_subnet.private_subneta1.id,
#     aws_subnet.private_subneta2.id,
#     aws_subnet.private_subnetb1.id,
#     aws_subnet.private_subnetb2.id,
#   ])
#   filename = "subnets.txt"
# }


# --------------------------------------------------------
# RESOURCE 23: VPC PEERING CONNECTION: CUSTOM-TO-DEFAULT VPC
# --------------------------------------------------------
# Create a VPC Peering Connection between the default VPC and the Terraform-created VPC
resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id        = aws_vpc.main.id  # Custom VPC ID
  peer_vpc_id   = data.aws_vpc.default_vpc.id  # Default VPC ID (or other VPC you are peering with)
  auto_accept   = true  # Automatically accept the peering connection
}

# --------------------------------------------------------
# RESOURCE 24: PUBLIC ROUTE TABLE PEERING ROUTE
# --------------------------------------------------------
resource "aws_route" "public_to_peer" {
  route_table_id             = aws_route_table.public_route_table.id
  destination_cidr_block     = data.aws_vpc.default_vpc.cidr_block  # Peer VPC's CIDR block
  vpc_peering_connection_id  = aws_vpc_peering_connection.vpc_peering.id
}

# --------------------------------------------------------
# RESOURCE 25: PRIVATE ROUTE TABLE A PEERING ROUTE
# --------------------------------------------------------
resource "aws_route" "private_a_to_peer" {
  route_table_id             = aws_route_table.private_route_table_a.id
  destination_cidr_block     = data.aws_vpc.default_vpc.cidr_block  # Peer VPC's CIDR block
  vpc_peering_connection_id  = aws_vpc_peering_connection.vpc_peering.id
}

# --------------------------------------------------------
# RESOURCE 26: PRIVATE ROUTE TABLE B PEERING ROUTE
# --------------------------------------------------------
resource "aws_route" "private_b_to_peer" {
  route_table_id             = aws_route_table.private_route_table_b.id
  destination_cidr_block     = data.aws_vpc.default_vpc.cidr_block  # Peer VPC's CIDR block
  vpc_peering_connection_id  = aws_vpc_peering_connection.vpc_peering.id
}


# --------------------------------------------------------
# RESOURCE 27: EKS CLUSTER IAM ROLE
# --------------------------------------------------------
# IAM Role for the EKS Cluster
# The cluster requires an IAM role to manage AWS resources.
# The AmazonEKSClusterPolicy policy is attached to grant the necessary permissions.
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"

  assume_role_policy = jsonencode({
    # This specific format has been in use since 2012 and is still valid today. 
    # It's not considered "old" because it continues to define the permissions and relationship required for services (like Amazon EKS) to assume the role.
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole" #The service (in this case, Amazon EKS) is requesting permission to assume the role.
        Effect    = "Allow" # Specifies that the action is permitted.
        Principal = { # Refers to the entity that is allowed to assume the role. 
          Service = "eks.amazonaws.com" # Allows Amazon EKS to assume the role and interact with other AWS services on behalf of the EKS cluster.
        }
      },
    ]
  })
}

# --------------------------------------------------------
# RESOURCE 28: ATTACH POLICY TO IAM ROLE
# --------------------------------------------------------
# The role's trust relationship (through the assume role policy) allows EKS to take actions using the permissions granted to the IAM role. 
# The AmazonEKSClusterPolicy grants the IAM role the necessary permissions for managing an EKS cluster. This includes permissions for:
# Accessing EC2 instances for worker nodes, managing VPC resources (subnets, security groups, etc.), logging and monitoring with CloudWatch.
# IAM Role Policy Attachment
resource "aws_iam_role_policy_attachment" "eks_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" # Mmanaged policy provided by AWS for Amazon EKS clusters. Use an ARN directly for custom policies in the same format: "arn:aws:iam::<account-id>:policy/<policy-name>".
}

# --------------------------------------------------------
# RESOURCE 29: EKS CLUSTER
# --------------------------------------------------------
# Specifies the cluster configuration
resource "aws_eks_cluster" "realeyez" {
  name     = "realeyez"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    # The subnet_ids attribute includes both public and private subnet IDs.
    # These subnets are linked to the VPC created earlier.
    subnet_ids = [
      aws_subnet.public_subnet1.id,
      aws_subnet.public_subnet2.id,
      aws_subnet.private_subneta1.id,
      aws_subnet.private_subneta2.id,
      aws_subnet.private_subnetb1.id,
      aws_subnet.private_subnetb2.id,
    ]
  }

  # Optional: Kubernetes version
  version = "1.28"

  # Tags for the cluster
  tags = {
    Environment = "test"
    Team        = "Verifeye"
  }
}

# --------------------------------------------------------
# RESOURCE 30: EKS NODE ROLE
# --------------------------------------------------------
resource "aws_iam_role" "eks_node_role" {
  name = "eks_node_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# --------------------------------------------------------
# RESOURCE 31: EKS NODE POLICY ATTACHMENT
# --------------------------------------------------------
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# --------------------------------------------------------
# RESOURCE 32: EKS OIDC PROVIDER
# --------------------------------------------------------
# Create the OIDC provider and associate it with the EKS cluster.
# The OIDC provider is necessary for IAM roles for service accounts (IRSA) in EKS. 
# It allows EKS to authenticate Kubernetes service accounts with IAM roles, enabling the Kubernetes workloads to assume IAM roles and access AWS resources securely.
resource "aws_eks_identity_provider_config" "oidc" {
  cluster_name = aws_eks_cluster.realeyez.name
  provider    = "OIDC"
  oidc {
    issuer_url = aws_eks_cluster.realeyez.identity[0].oidc.issuer
  }
}

# --------------------------------------------------------
# RESOURCE 33: KUBERNETES SERVICE ACCOUNT
# --------------------------------------------------------
# Kubernetes and AWS do not automatically create the service account; it must be manually created within the Kubernetes cluster. 
# Once it's created, the IAM role policy (with its sub condition) will allow the service account to assume the IAM role, if the sub claim in the OIDC token matches the specified service account.
resource "kubernetes_service_account" "my_service_account" {
  metadata {
    name      = "my-service-account"
    namespace = "default"
  }
}

# --------------------------------------------------------
# RESOURCE 34: KUBERNETES SERVICE ACCOUNT IAM ROLE POLICY
# --------------------------------------------------------
# Once the OIDC provider is associated, you can use IAM roles for service accounts (IRSA) to assign specific AWS permissions to Kubernetes service accounts.
resource "aws_iam_role" "eks_service_account_role" {
  name = "eks_service_account_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRoleWithWebIdentity"
        Effect    = "Allow"
        Principal = { # Built-in data source in Terraform that provides information about the AWS identity making the request. The "current" part indicates that this refers to the identity tied to the credentials or profile currently in use (i.e., the user or role executing the Terraform configuration).
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/${aws_eks_cluster.realeyez.id}"
        }
        Condition = {
          StringEquals = {
            "oidc.eks.us-east-1.amazonaws.com/id/${aws_eks_cluster.realeyez.id}:sub" = "system:serviceaccount:default:my-service-account"
          }
        }
      },
    ]
  })
}

# --------------------------------------------------------
# RESOURCE 35: EKS NODE GROUP
# --------------------------------------------------------
# This block adds worker nodes to your cluster in the public subnets, 
# replacing eksctl’s default node provisioning mechanism.
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.realeyez.name
  node_group_name = "node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  subnet_ids = [
    aws_subnet.public_subneta.id,
    aws_subnet.public_subnetb.id,
  ]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  tags = {
    Environment = "test"
    Team        = "Verifeye"
  }
}


# --------------------------------------------------------
# RESOURCE: WORKER NODE SECRUITY GROUP
# --------------------------------------------------------
resource "aws_security_group" "eks_worker_sg" {
  name        = "eks-worker-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow API server communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "Allow worker-to-worker communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}




# --------------------------------------------------------
# RESOURCE: Helm Provider Setup
# --------------------------------------------------------
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config" # or use config in your cluster
  }
}

# --------------------------------------------------------
# RESOURCE: AWS Load Balancer Controller IAM Role
# --------------------------------------------------------
resource "aws_iam_role" "aws_load_balancer_controller_role" {
  name = "aws-load-balancer-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRoleWithWebIdentity"
        Effect    = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${data.aws_region.current.name}.amazonaws.com/id/${aws_eks_cluster.realeyez.id}"
        }
        Condition = {
          StringEquals = {
            "oidc.eks.${data.aws_region.current.name}.amazonaws.com/id/${aws_eks_cluster.realeyez.id}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      },
    ]
  })
}

# --------------------------------------------------------
# RESOURCE: Attach AWS Load Balancer Controller IAM Policy
# --------------------------------------------------------
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_policy" {
  role       = aws_iam_role.aws_load_balancer_controller_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy"
}

# --------------------------------------------------------
# RESOURCE: Kubernetes Service Account
# --------------------------------------------------------
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller_role.arn
    }
  }
}

# --------------------------------------------------------
# RESOURCE: Deploy AWS Load Balancer Controller Using Helm
# --------------------------------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  version    = "2.5.0"  # Specify the desired version of the chart

  values = [
    # Configuration values for the Helm chart, including the service account annotations.
    <<EOF
    serviceAccount:
      create: false
      name: "aws-load-balancer-controller"  # Use the created service account name
    clusterName: "${aws_eks_cluster.realeyez.name}"
    region: "${data.aws_region.current.name}"
    vpcId: "${aws_vpc.main.id}"
    EOF
  ]

  # Ensure Helm only installs the release if it's not already deployed.
  recreate_pods = true
}

# Helm Provider: The helm provider is used to manage Helm charts in your Kubernetes cluster.
# IAM Role and Service Account: The IAM role for the AWS Load Balancer Controller is created and associated with the service account using the annotation eks.amazonaws.com/role-arn. This allows the controller to assume the role and gain the necessary permissions.
# Helm Chart Deployment: The helm_release resource is used to deploy the AWS Load Balancer Controller Helm chart. In this configuration, the service account that was created earlier is used (by setting serviceAccount.create: false and providing the name of the service account).
# Values File: The values block provides configuration values that are passed to the Helm chart. Here, you specify:
# The service account name to use (aws-load-balancer-controller).
# The cluster name, region, and VPC ID.





# --------------------------------------------------------
# RESOURCE : NGINX DEPLOYMENT
# --------------------------------------------------------
resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "nginx-deployment"
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          image = "nginx:1.21.1"
          name  = "nginx"

          port {
            container_port = 80
          }

          volume_mount {
            mount_path = "/etc/nginx/nginx.conf"
            name       = "nginx-config"
            sub_path   = "nginx.conf"
          }
        }

        volume {
          name = "nginx-config"

          config_map {
            name = "nginx-config"
          }
        }
      }
    }
  }
}