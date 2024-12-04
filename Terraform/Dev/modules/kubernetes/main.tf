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
  host = aws_eks_cluster.realeyez.endpoint
  token = data.aws_eks_cluster_auth.realeyez.token
  cluster_ca_certificate = base64decode(aws_eks_cluster.realeyez.certificate_authority[0].data)
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
    aws_subnet.public_subneta.id,
    aws_subnet.public_subnetb.id,
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
# Reference the Default VPC
data "aws_vpc" "default_vpc" {
  id = data.default_vpc_id
}
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
      aws_subnet.public_subneta.id,
      aws_subnet.public_subnetb.id,
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
output "cluster_endpoint" {
  value = aws_eks_cluster.realeyez.endpoint
}

data "aws_eks_cluster_auth" "realeyez" {
  name = aws_eks_cluster.realeyez.name
}

output "cluster_token" {
  value = aws_eks_cluster.realeyez.identity[0].oidc.issuer
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.realeyez.certificate_authority[0].data
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
resource "aws_iam_openid_connect_provider" "realeyez_oidc" {
  url = aws_eks_cluster.realeyez.identity[0].oidc.issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    # Use the thumbprint for the OIDC provider. Retrieve this from the AWS documentation or using tools.
    "9e99a48a9960a6a3561e0e8f0ed33c65e3780c1d"
  ]

  tags = {
    Environment = "test"
    Team        = "Verifeye"
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

# # --------------------------------------------------------
# # RESOURCE 35: WORKER NODE SECRUITY GROUP
# # --------------------------------------------------------
# resource "aws_security_group" "eks_worker_sg" {
#   name        = "eks-worker-sg"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     description = "Allow API server communication"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = [aws_vpc.main.cidr_block]
#   }

#   ingress {
#     description = "Allow worker-to-worker communication"
#     from_port   = 0
#     to_port     = 65535
#     protocol    = "tcp"
#     cidr_blocks = [aws_vpc.main.cidr_block]
#   }

#   egress {
#     description = "Allow all outbound traffic"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# --------------------------------------------------------
# RESOURCE 35: EKS NODE GROUP 
# --------------------------------------------------------
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.realeyez.name
  node_group_name = "node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  # Add the security group for worker nodes
  # The error occurs because the node_group_security_groups argument is not valid for the aws_eks_node_group resource. 
  # Instead, AWS EKS node groups automatically inherit security groups from the EKS cluster's configuration. 
  # If you need to attach additional security groups to worker nodes, you must set them at the EKS Cluster level or use launch templates with your node group.
  # node_group_security_groups = [aws_security_group.eks_worker_sg.id]

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
# EXPLANATION: WHY ARE WE USING HELM?
# --------------------------------------------------------
# https://www.reddit.com/r/kubernetes/comments/qsf8ey/what_problem_does_helm_chart_solve/
# Helm is a package manager. Think apt-get for Kubernetes.
# A Helm Chart (or package) gives a user the ability to consume software on their cluster that was packaged with sane default configuration by experts in that software. 
# Helm charts (or packages) allow users to deploy that software without having to become an expert in said software.
# Analogous to being able to install MySQL on a Linux host. Can experts tweak the install to be more performant or better for their use-case? Yes. 
# Do you need to be an expert in MySQL to use apt to install the thing and get going? No. Same with Helm charts.

# --------------------------------------------------------
# RESOURCE 36: Helm Provider Setup
# --------------------------------------------------------
# Helm Provider: The helm provider is used to manage Helm charts in your Kubernetes cluster.
# Helm allows you to package these configurations into a Chart, which is a pre-configured application definition.
## Helm Charts ##
# A Helm Chart is a bundle of Kubernetes YAML files organized into templates. It includes:
# A values.yaml file for customizable parameters.
# Templates for resources like Deployments, Services, etc.
# Metadata for the chart (e.g., Chart.yaml).
# With a Helm Chart, you can deploy complex applications like NGINX, MySQL, or custom apps with a single command.
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config" # or use config in your cluster
  }
}

# --------------------------------------------------------
# RESOURCE 37: AWS Load Balancer Controller IAM Role
# --------------------------------------------------------
# IAM Role and Service Account: The IAM role for the AWS Load Balancer Controller is created and associated with the service account using the annotation eks.amazonaws.com/role-arn. 
# This allows the controller to assume the role and gain the necessary permissions.
# The aws_load_balancer_controller_role IAM role is configured with an assume role policy that allows it to trust:
# The OIDC provider for the EKS cluster.
# The specific service account (system:serviceaccount:kube-system:aws-load-balancer-controller).
# The policy ensures only the correct service account can assume the IAM role.
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
# RESOURCE 38: Attach AWS Load Balancer Controller IAM Policy
# --------------------------------------------------------
# Full content of the AWSLoadBalancerControllerIAMPolicy https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html
# The policy ensures that the AWS Load Balancer Controller can:
# Create and manage ALBs/NLBs.
# Configure target groups, listeners, and listener rules.
# Modify security groups and network interfaces for load balancer resources.
# Access tagging and resource discovery services.
# This enables the controller to handle Kubernetes resources like Ingress and Service objects efficiently.
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_policy" {
  role       = aws_iam_role.aws_load_balancer_controller_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy"
}

# --------------------------------------------------------
# RESOURCE 39: Kubernetes Service Account
# --------------------------------------------------------
# Identity for Kubernetes Pods
# In Kubernetes, a service account provides an identity to the pods running in your cluster. 
# The AWS Load Balancer Controller runs as a pod, and it uses the specified service account to authenticate itself.

# IAM Role Association
# The service account is annotated with the IAM Role ARN, 
# allowing the pods using this service account to assume the IAM role and access AWS services with the permissions defined in the role’s attached policy.

# Lifecycle
# When the AWS Load Balancer Controller pod starts, it uses the aws-load-balancer-controller service account.
# The service account token (provided by Kubernetes) includes claims that are verified against the OIDC provider in AWS.
# AWS confirms that:
# The OIDC provider matches the EKS cluster.
# The sub claim matches the specific service account in the kube-system namespace.
# If the verification succeeds, the pod can assume the IAM role and gain the permissions granted by the AWSLoadBalancerControllerIAMPolicy.
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
# EXPLANATION: RESOURCE 37 - 39
# --------------------------------------------------------
## Why This Approach? ##
# This design:
# Increases Security: The controller pod is limited to specific permissions only through the IAM role, which is scoped to the service account.
# Improves Least Privilege Access: Only the controller pod using the correct service account can access AWS resources.
# Simplifies Management: IRSA removes the need to attach AWS credentials manually to pods
## Security Scenarios Demonstrating the Risks ##
# Pod Compromise Without IRSA
# A malicious actor gains control over a pod. If the node role has permissions to access S3 buckets, EC2 instances, or RDS databases, the attacker can leverage those permissions to extract sensitive data or disrupt services.
# Accidental Exposure of Static Credentials
# Developers might inadvertently push static credentials to a public repository, giving attackers immediate access to AWS resources.
# No Separation of Duties
# In a multi-tenant cluster, workloads from different teams or projects could end up with the same AWS permissions, risking cross-team data access or unintentional disruptions.
# How IRSA Prevents These Issues
# Pod-Specific IAM Permissions: Only the specific service account (and its pods) can assume the IAM role with its designated permissions.
# Automatic Token Expiry: Tokens from the OIDC provider are short-lived, reducing exposure time in case of compromise.
# Granular Audit Logs: CloudTrail shows which service account or pod initiated AWS API calls.
# Improved Least Privilege: Each workload can have its own service account with just the permissions it needs, limiting the blast radius of a breach.




# --------------------------------------------------------
# EXPLANATION: RESOURCE 40 - 44
# --------------------------------------------------------
# NGINX Ingress Controller handles ingress traffic and routes requests to services within the cluster. 
# It is essential to have it set up before you create Ingress resources (which are referenced by Cert-Manager).
# You do not need Resource 41 (NGINX Ingress Controller) unless you have advanced or internal routing needs.
# Use AWS Load Balancer Controller if your cluster is fully hosted on AWS and you don’t need NGINX’s advanced features or internal traffic routing.
# Yes, you would need to integrate Cert-Manager into your EKS cluster setup if you want to manage SSL/TLS certificates automatically for services deployed within the cluster. 
# After installing Cert-Manager, you would also need to create an Issuer or ClusterIssuer resource to specify how Cert-Manager should issue certificates (e.g., via Let's Encrypt or another certificate provider).
# Once Cert-Manager is installed and a ClusterIssuer is configured, you can create Ingress resources that specify how to request certificates for your services.
## Why Apply Cert-Manager to Your EKS Cluster? ##
# Automates SSL/TLS Certificates: Cert-Manager will handle the entire lifecycle of certificates, from issuance to renewal, without manual intervention.
# Reduces Human Error: Managing certificates manually can be error-prone and lead to expired certificates. Cert-Manager automates and ensures proper certificates are always available for your services.
# Seamless Integration: Cert-Manager integrates seamlessly with Kubernetes resources like Ingress, making it easy to manage certificates for your HTTP/HTTPS endpoints.

# # --------------------------------------------------------
# # RESOURCE 41: NGINX INGRESS CONTROLLER
# # --------------------------------------------------------
# # Helm Chart: The NGINX Ingress Controller is often installed via Helm, and it automatically sets up resources like Service, Deployment, and IngressController.
# # Usage: It is used in conjunction with Kubernetes Ingress resources to handle traffic routing from external users to internal services.
# # Purpose: The NGINX Ingress Controller is responsible for managing external access to services in a Kubernetes cluster by acting as a reverse proxy. 
# # It routes external HTTP(S) requests to the appropriate service within the cluster based on defined Ingress resources.
# resource "helm_release" "nginx_ingress" {
#   name       = "nginx-ingress"
#   namespace  = "ingress-nginx"
#   repository = "https://kubernetes.github.io/ingress-nginx"
#   chart      = "ingress-nginx"
#   version    = "4.0.13"  # Adjust version as needed
#   create_namespace = true
# }


# --------------------------------------------------------
# RESOURCE 40: INSTALL CERT MANAGER FOR ENCRYPTING TRAFFIC
# --------------------------------------------------------
# Purpose: Installs Cert-Manager, a Kubernetes tool to automate the management and issuance of TLS certificates (from external authorities like Let's Encrypt or self-signed certificates).
# Rationale: Cert-Manager must be installed first because it's responsible for managing the certificates used by the Load Balancer and Ingress resources. 
# This ensures that any references to certificates (like in Ingress resources) can be handled correctly.
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.12.0"  # Adjust the version as needed
  create_namespace = true

  # Ensure Cert-Manager is installed and running
  values = [
    <<EOF
    installCRDs: true  # Install CustomResourceDefinitions needed by Cert-Manager
    EOF
  ]
}

# # --------------------------------------------------------
# # RESOURCE 41: CLUSTERISSUER FOR CERT MANAGER VIA LET'S ENCRYPT
# # --------------------------------------------------------
# # Purpose: Defines a ClusterIssuer resource for requesting certificates from Let's Encrypt, enabling Cert-Manager to automatically issue and renew certificates.
# # Rationale: This resource depends on Cert-Manager being installed (hence the depends_on in the code). 
# # Once the ClusterIssuer is created, Cert-Manager can use it to request certificates for your domain.
# resource "kubernetes_manifest" "letsencrypt_cluster_issuer" {
#   depends_on = [helm_release.cert_manager] # Ensure cert-manager is deployed first

#   manifest = {
#     apiVersion = "cert-manager.io/v1"
#     kind       = "ClusterIssuer"
#     metadata = {
#       name = "letsencrypt-prod"  # You can also create a 'letsencrypt-staging' issuer for testing
#     }
#     spec = {
#       acme = {
#         email = "joekuralabs@gmail.com"  # Replace with your actual email
#         server = "https://acme-v02.api.letsencrypt.org/directory"  # Production server for Let’s Encrypt. For the staging server https://acme-staging-v02.api.letsencrypt.org/directory
#         privateKeySecretRef = {
#           name = "letsencrypt-prod"  # The secret where the private key for this issuer is stored
#         }
#         solvers = [
#           {
#             http01 = {
#               ingress = {}
#             }
#           }
#         ]
#       }
#     }
#   }
# }

# --------------------------------------------------------
# RESOURCE 41: CLUSTERISSUER FOR CERT MANAGER VIA SELF SIGNING
# --------------------------------------------------------
# If you're opting for a self-signed issuer for testing, you don't need to comment out the ClusterIssuer resource, but you should modify it to reference the self-signed certificate issuer instead of the Let's Encrypt issuer.
# Since you're using a self-signed certificate for testing, update the ClusterIssuer configuration to create a self-signed certificate issuer instead of a Let's Encrypt issuer.
resource "kubernetes_manifest" "selfsigned_cluster_issuer" {
  depends_on = [helm_release.cert_manager] # Ensure cert-manager is deployed first

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned-prod"  # You can choose any name for your self-signed issuer
    }
    spec = {
      selfSigned = {}  # Defines a self-signed certificate issuer
    }
  }
}


# --------------------------------------------------------
# RESOURCE 42: Deploy AWS Load Balancer Controller Using Helm
# --------------------------------------------------------
# Purpose: Installs the AWS Load Balancer Controller via Helm, which will manage AWS ALBs (Application Load Balancers) in the Kubernetes cluster.
# Rationale: The AWS Load Balancer Controller is used to manage ALBs for Kubernetes services, including routing traffic and handling SSL termination. 
# It must be installed after Cert-Manager and the ClusterIssuer because the ALB may need to reference certificates for securing traffic. 
# It is also crucial that the ALB Controller is fully deployed before using it in ingress resources.
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  version    = "2.5.0"  # Specify the desired version of the chart

  # Configuration values for the Helm chart, including the service account annotations.
  # Values File: The values block provides configuration values that are passed to the Helm chart. Here, you specify:
  # The service account name to use (aws-load-balancer-controller).
  # The cluster name, region, and VPC ID.
  values = [
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

# --------------------------------------------------------
# RESOURCE 43: WAIT FOR AWS LOAD BALANCER CONTROLLER PODS
# --------------------------------------------------------
# Purpose: Ensures the AWS Load Balancer Controller pods are ready before any operations dependent on it are performed.
# Rationale: After the controller is deployed, it's important to wait until the pods are ready. This ensures that subsequent tasks (e.g., Ingress configuration, TLS setup) don’t fail because the controller isn’t ready to process them. 
# It depends on the deployment of the AWS Load Balancer Controller.
resource "null_resource" "wait_for_lb_controller" {
  depends_on = [
    helm_release.aws_load_balancer_controller  # Ensure the Load Balancer Controller is deployed first
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for AWS Load Balancer Controller pods..."
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s
    EOT
  }
}

# --------------------------------------------------------
# RESOURCE 44: WAIT FOR CERTIFICATE 
# --------------------------------------------------------
# Purpose: Ensures that the certificate requested by Cert-Manager (via the ClusterIssuer) is fully issued and ready before proceeding with Ingress or Load Balancer configuration.
# Rationale: Before configuring the ALB or applying SSL/TLS settings to your services, the certificate must be issued and available. 
# This resource waits for the certificate to be issued by Cert-Manager and ensures that the ALB is configured with a valid certificate for secure traffic.
resource "null_resource" "wait_for_certificate" {
  depends_on = [
    kubernetes_manifest.selfsigned_cluster_issuer,  # Make sure Cert-Manager and the Issuer are created first
    kubernetes_manifest.realeyez_ingress             # Ensure the ingress is created after certificate is ready
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for AWS Load Balancer Controller certificate..."
      kubectl wait --for=condition=ready certificate aws-load-balancer-serving-cert -n kube-system --timeout=300s
    EOT
  }
}


# # --------------------------------------------------------
# # RESOURCE 45: DEFINE CERTIFICATE REQUESTS INGRESS
# # --------------------------------------------------------
# # Purpose: Defines an Ingress resource to expose a service to external traffic. The Ingress uses the AWS Load Balancer Controller and manages SSL/TLS encryption (either with a Let's Encrypt certificate or a self-signed certificate).
# # Rationale: The Ingress resource depends on the certificate being ready (as well as the AWS Load Balancer Controller). 
# # It is defined last because it references the certificate (whether from Let's Encrypt or self-signed), and requires the ALB to be ready to manage the traffic.
# resource "kubernetes_manifest" "example_ingress" {
#   manifest = {
#     apiVersion = "networking.k8s.io/v1"
#     kind       = "Ingress"
#     metadata = {
#       name      = "example-ingress"
#       namespace = "default"
#       annotations = {
#         kubernetes.io/ingress.class: "alb"               # Specifies AWS Load Balancer Controller
#         alb.ingress.kubernetes.io/scheme: "internet-facing" # ALB configuration (adjust as needed)
#         alb.ingress.kubernetes.io/target-type: "ip"        # Target type (ip or instance)
#         # cert-manager.io/cluster-issuer: "letsencrypt-prod" # For Cert-Manager to manage TLS
#         cert-manager.io/issuer: "selfsigned-prod" # Reference self-signed issuer
#       }
#     }
#     spec = {
#       rules = [
#         {
#           host = "localhost"  # Replace with your actual domain. You can use this for testing purposes but note that Let's Encrypt won’t issue a certificate for this placeholder domain. For real-world usage, you must use a proper, valid, publicly accessible domain.
#           # --------------------------------------------------------
#           # ROADBLOCK 1: DOMAIN FOR INGRESS REQUESTS
#           # --------------------------------------------------------
#           # Without a domain, you can't request a valid TLS certificate from Let's Encrypt.
#           # To proceed, you should either buy a domain, use a subdomain from a DNS provider, or use a free service for testing.
#           # After getting a domain, ensure your DNS is configured to point to your ingress controller, and update your Ingress resources to use the new domain for SSL certificate requests.
#           # If you're using a cloud provider like AWS, Azure, or GCP, you will need to expose the ingress controller via a LoadBalancer service, which will provide an external IP address.
#           # --------------------------------------------------------
#           # WORKAROUND 1: SELF-SIGNED ISSUER
#           # --------------------------------------------------------
#           # If You're Testing Without a Domain:  
#           # cert-manager.io/issuer: "selfsigned-prod" # Reference self-signed issuer
#           # If you're testing locally or in a development environment without a publicly accessible domain, the self-signed issuer can be useful. In this case:
#           # Update your ingress resource to reference aws-load-balancer-selfsigned-issuer instead of letsencrypt-prod.
#           # Use the self-signed certificate for internal testing.
#           http = {
#             paths = [
#               {
#                 path = "/"
#                 pathType = "Prefix"
#                 backend = {
#                   service = {
#                     name = "your-service"
#                     port = {
#                       number = 80
#                     }
#                   }
#                 }
#               }
#             ]
#           }
#         }
#       ]
#       tls = [
#         {
#           hosts      = ["localhost"]  # The domain for which the certificate is requested. Replace with your actual domain.
#           secretName = "realeye-app-tls"  # Secret to store the certificate
#         }
#       ]
#     }
#   }
# }

resource "kubernetes_manifest" "realeyez_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "realeyez_ingress"
      namespace = "default"
      annotations = {
        kubernetes.io/ingress.class: "alb"                        # Matches ingress_class2.yml
        alb.ingress.kubernetes.io/scheme: "internet-facing"
        alb.ingress.kubernetes.io/target-type: "instance"         # Match the target type from ingress2.yml
        alb.ingress.kubernetes.io/tags: "Environment=staging"    # Optional tags for ALB
        cert-manager.io/issuer: "selfsigned-cluster-issuer"      # Keep for testing; replace for production
      }
    }
    spec = {
      rules = [
        {
          host = "localhost"  # Replace with a valid domain for production
          http = {
            paths = [
              {
                path = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "realeyez-service"  # Replace with your actual service name
                    port = {
                      number = 80
                    }
                  }
                }
              }
            ]
          }
        }
      ]
      tls = [
        {
          hosts      = ["localhost"]  # Replace with your actual domain for HTTPS
          secretName = "realeye-app-tls"
        }
      ]
    }
  }
}



resource "kubernetes_manifest" "realeyez_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "realeyez-service"
      namespace = "default"
    }
    spec = {
      selector = {
        app = "realeyez"
      }
      ports = [
        {
          port       = 80
          targetPort = 8000
        }
      ]
      type = "ClusterIP"  # or "NodePort", "LoadBalancer" depending on your setup
    }
  }
}


resource "kubernetes_manifest" "realeyez_deployment" {
  depends_on = [kubernetes_manifest.example_ingress]  # Ensure the ingress is created first

  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "realeyez"
      namespace = "default"
    }
    spec = {
      replicas = 2
      selector = {
        matchLabels = {
          app = "realeyez"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "realeyez"
          }
        }
        spec = {
          containers = [
            {
              name  = "realeyez"
              image = "joedhub/realeyez"
              ports = [
                {
                  containerPort = 8000
                }
              ]
            }
          ]
        }
      }
    }
  }
}


# # --------------------------------------------------------
# # RESOURCE : NGINX DEPLOYMENT
# # --------------------------------------------------------
# resource "kubernetes_deployment" "nginx" {
#   metadata {
#     name = "nginx-deployment"
#     labels = {
#       app = "nginx"
#     }
#   }

#   spec {
#     replicas = 3

#     selector {
#       match_labels = {
#         app = "nginx"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "nginx"
#         }
#       }

#       spec {
#         container {
#           image = "nginx:1.21.1"
#           name  = "nginx"

#           port {
#             container_port = 80
#           }

#           volume_mount {
#             mount_path = "/etc/nginx/nginx.conf"
#             name       = "nginx-config"
#             sub_path   = "nginx.conf"
#           }
#         }

#         volume {
#           name = "nginx-config"

#           config_map {
#             name = "nginx-config"
#           }
#         }
#       }
#     }
#   }
# }



