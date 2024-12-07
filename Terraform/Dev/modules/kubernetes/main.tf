terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

# The kubernetes provider is necessary to interact with the Kubernetes cluster created by EKS.
provider "kubernetes" {
  config_path = "~/.kube/config"
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority)
  token                  = var.cluster_auth_token
}

# Helm Provider
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority)
    token                  = var.cluster_auth_token
  }
}

data "aws_caller_identity" "current" {}

# OIDC Provider for Service Account Mapping
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b36a5d1596b6ec982"]
  url             = var.cluster_oidc_issuer
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
          "oidc.eks.${var.region}.amazonaws.com/id/${var.cluster_id}:sub" = "system:serviceaccount:default:postgres-service-account"
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
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
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
    value = var.cluster_name
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

# resource "null_resource" "wait_for_lb_controller" {
#   depends_on = [
#     helm_release.aws_load_balancer_controller
#   ]

#   provisioner "local-exec" {
#     command = <<EOT
#       echo "Waiting for AWS Load Balancer Controller pods..."
#       kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s
#     EOT
#   }
# }

# # Cert Manager Installation
# resource "helm_release" "cert_manager" {
#   name       = "cert-manager"
#   repository = "https://charts.jetstack.io"
#   chart      = "cert-manager"
#   namespace  = "cert-manager"
#   version    = "v1.12.0"  # Adjust the version as needed

#   create_namespace = true

#   set {
#     name  = "installCRDs"
#     value = "true"
#   }
# }

# # Self-Signed Cluster Issuer
# resource "kubernetes_manifest" "selfsigned_cluster_issuer" {
#   depends_on = [helm_release.cert_manager]

#   manifest = {
#     apiVersion = "cert-manager.io/v1"
#     kind       = "ClusterIssuer"
#     metadata = {
#       name = "selfsigned-cluster-issuer"  # You can choose any name for your self-signed issuer
#     }
#     spec = {
#       selfSigned = {}  # Defines a self-signed certificate issuer
#     }
#   }
# }

# resource "kubernetes_manifest" "aws_load_balancer_serving_cert" {
#   depends_on = [kubernetes_manifest.selfsigned_cluster_issuer]

#   manifest = {
#     apiVersion = "cert-manager.io/v1"
#     kind       = "Certificate"
#     metadata = {
#       name      = "aws-load-balancer-serving-cert"
#       namespace = "kube-system"
#     }
#     spec = {
#       dnsNames = [
#         "*" 
#       ]
#       secretName = "aws-load-balancer-serving-cert"
#       issuerRef = {
#         name = "selfsigned-cluster-issuer"
#         kind = "ClusterIssuer"
#       }
#     }
#   }
# }


# resource "null_resource" "wait_for_certificate" {
#   depends_on = [
#     kubernetes_manifest.selfsigned_cluster_issuer,
#     helm_release.cert_manager,
#     kubernetes_manifest.aws_load_balancer_serving_cert
#   ]

#   provisioner "local-exec" {
#     command = <<EOT
#       echo "Waiting for certificate to be issued..."
#       kubectl wait --for=condition=ready certificate aws-load-balancer-serving-cert -n kube-system --timeout=300s
#     EOT
#   }
# }

# ################################## APPLICATION DEPLOYMENT #############################################
# resource "kubernetes_manifest" "realeyez_ingress" {
#   manifest = {
#     apiVersion = "networking.k8s.io/v1"
#     kind       = "Ingress"
#     metadata = {
#       name      = "realeyez-ingress"
#       namespace = "kube-system"
#       annotations = {
#         "kubernetes.io/ingress.class"               = "alb"                        # Matches ingress_class2.yml
#         "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
#         "alb.ingress.kubernetes.io/target-type"     = "instance"                   # Match the target type from ingress2.yml
#         "alb.ingress.kubernetes.io/tags"            = "Environment=staging"        # Optional tags for ALB
#         "cert-manager.io/issuer"                    = "selfsigned-cluster-issuer"  # Keep for testing; replace for production
#       }
#     }
#     spec = {
#       rules = [
#         {
#           host = "localhost"
#           http = {
#             paths = [
#               {
#                 path = "/"
#                 pathType = "Prefix"
#                 backend = {
#                   service = {
#                     name = "realeyez-service"  # Replace with your actual service name
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
#           hosts      = ["localhost"]  # Replace with your actual domain for HTTPS
#           secretName = "realeye-app-tls"
#         }
#       ]
#     }
#   }
# }

# resource "kubernetes_manifest" "realeyez_service" {
#   manifest = {
#     apiVersion = "v1"
#     kind       = "Service"
#     metadata = {
#       name      = "realeyez-service"
#       namespace = "default"
#     }
#     spec = {
#       selector = {
#         app = "realeyez"
#       }
#       ports = [
#         {
#           port       = 80
#           targetPort = 8000
#         }
#       ]
#       type = "ClusterIP"  
#     }
#   }
# }


# resource "kubernetes_manifest" "realeyez_deployment" {
#   depends_on = [kubernetes_manifest.realeyez_ingress]  # Ensure the ingress is created first

#   manifest = {
#     apiVersion = "apps/v1"
#     kind       = "Deployment"
#     metadata = {
#       name      = "realeyez"
#       namespace = "default"
#     }
#     spec = {
#       replicas = 2
#       selector = {
#         matchLabels = {
#           app = "realeyez"
#         }
#       }
#       template = {
#         metadata = {
#           labels = {
#             app = "realeyez"
#           }
#         }
#         spec = {
#           containers = [
#             {
#               name  = "realeyez"
#               image = "tjwkura5/real_eyez:latest"
#               ports = [
#                 {
#                   containerPort = 8000
#                 }
#               ]
#               env = [
#                 {
#                   name  = "DB_HOST"  # The name of the environment variable
#                   value = var.rds_endpoint # The value of the environment variable
#                 }
#               ]
#             }
#           ]
#         }
#       }
#     }
#   }
# }



