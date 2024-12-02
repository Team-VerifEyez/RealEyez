
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
      var.public_subnet_id_1,
      var.public_subnet_id_2,
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
    var.public_subnet_id_1,
    var.public_subnet_id_2,
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
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${aws_eks_cluster.realeyez.id}"
        }
        Condition = {
          StringEquals = {
            "oidc.eks.${var.region}.amazonaws.com/id/${aws_eks_cluster.realeyez.id}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
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
    region: "${var.region}"
    vpcId: "${var.vpc_id}"
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
    kubernetes_manifest.letsencrypt_cluster_issuer,  # Make sure Cert-Manager and the Issuer are created first
    kubernetes_manifest.example_ingress             # Ensure the ingress is created after certificate is ready
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for AWS Load Balancer Controller certificate..."
      kubectl wait --for=condition=ready certificate aws-load-balancer-serving-cert -n kube-system --timeout=300s
    EOT
  }
}


# --------------------------------------------------------
# RESOURCE 45: DEFINE CERTIFICATE REQUESTS INGRESS
# --------------------------------------------------------
# Purpose: Defines an Ingress resource to expose a service to external traffic. The Ingress uses the AWS Load Balancer Controller and manages SSL/TLS encryption (either with a Let's Encrypt certificate or a self-signed certificate).
# Rationale: The Ingress resource depends on the certificate being ready (as well as the AWS Load Balancer Controller). 
# It is defined last because it references the certificate (whether from Let's Encrypt or self-signed), and requires the ALB to be ready to manage the traffic.
resource "kubernetes_manifest" "example_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "example-ingress"
      namespace = "default"
      annotations = {
        kubernetes.io/ingress.class: "alb"               # Specifies AWS Load Balancer Controller
        alb.ingress.kubernetes.io/scheme: "internet-facing" # ALB configuration (adjust as needed)
        alb.ingress.kubernetes.io/target-type: "ip"        # Target type (ip or instance)
        # cert-manager.io/cluster-issuer: "letsencrypt-prod" # For Cert-Manager to manage TLS
        cert-manager.io/issuer: "selfsigned-prod" # Reference self-signed issuer
      }
    }
    spec = {
      rules = [
        {
          host = "localhost"  # Replace with your actual domain. You can use this for testing purposes but note that Let's Encrypt won’t issue a certificate for this placeholder domain. For real-world usage, you must use a proper, valid, publicly accessible domain.
          # --------------------------------------------------------
          # ROADBLOCK 1: DOMAIN FOR INGRESS REQUESTS
          # --------------------------------------------------------
          # Without a domain, you can't request a valid TLS certificate from Let's Encrypt.
          # To proceed, you should either buy a domain, use a subdomain from a DNS provider, or use a free service for testing.
          # After getting a domain, ensure your DNS is configured to point to your ingress controller, and update your Ingress resources to use the new domain for SSL certificate requests.
          # If you're using a cloud provider like AWS, Azure, or GCP, you will need to expose the ingress controller via a LoadBalancer service, which will provide an external IP address.
          # --------------------------------------------------------
          # WORKAROUND 1: SELF-SIGNED ISSUER
          # --------------------------------------------------------
          # If You're Testing Without a Domain:  
          # cert-manager.io/issuer: "selfsigned-prod" # Reference self-signed issuer
          # If you're testing locally or in a development environment without a publicly accessible domain, the self-signed issuer can be useful. In this case:
          # Update your ingress resource to reference aws-load-balancer-selfsigned-issuer instead of letsencrypt-prod.
          # Use the self-signed certificate for internal testing.
          http = {
            paths = [
              {
                path = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "your-service"
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
          hosts      = ["localhost"]  # The domain for which the certificate is requested. Replace with your actual domain.
          secretName = "realeye-app-tls"  # Secret to store the certificate
        }
      ]
    }
  }
}


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



