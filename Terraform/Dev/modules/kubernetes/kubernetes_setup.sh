#!/bin/bash

# # Create EKS cluster
# eksctl create cluster kubedemo40 --vpc-public-subnets=subnet-0c7755f1dba6358c8,subnet-0c893fcb7da57f2d1 --vpc-private-subnets=subnet-096cb6de98d7239f0,subnet-088b523a067045ade --without-nodegroup

# # Create node group
# eksctl create nodegroup --cluster kubedemo40 --name kubedemo-ng --node-type t2.medium --nodes 2 --nodes-min 1 --nodes-max 10

# # Wait for nodes to be ready
# kubectl wait --for=condition=ready nodes --all --timeout=300s

# # Associate IAM OIDC provider
# eksctl utils associate-iam-oidc-provider --region=us-east-1 --cluster=kubedemo40 --approve

# # Create IAM service account
# eksctl create iamserviceaccount \
#   --cluster=kubedemo40 \
#   --namespace=kube-system \
#   --name=aws-load-balancer-controller \
#   --attach-policy-arn=arn:aws:iam::994181039877:policy/AWSLoadBalancerControllerIAMPolicy \
#   --approve

# # Install cert-manager first and ensure it's ready. Certification manager. Encrypt traffic from http to https
# kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml


# # Wait for cert-manager to be ready - increased timeout and added verification
# echo "Waiting for cert-manager pods to be ready..."
# kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s
# kubectl wait --for=condition=ready pod -l app=cainjector -n cert-manager --timeout=300s
# kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=300s
# --------------------------------------------------------
# EXPLANATION: Do You Need These (3 Wait) Steps in Your Terraform Kubernetes Setup?
# --------------------------------------------------------
# It Depends on the Deployment Method:
# If You Are Using Terraform to Deploy Cert-Manager (As in Resource 42):
# The helm_release for Cert-Manager deploys the necessary components.
# Helm manages pod readiness checks internally, so you don't need additional kubectl wait commands in your Terraform scripts.
# However:
# If you have external scripts or a pipeline that depends on Cert-Manager's availability immediately after deployment, you might still need to verify readiness using kubectl wait.
# If Terraform Does Not Enforce Dependencies on Cert-Manager Readiness:
# Adding readiness checks outside Terraform (e.g., in CI/CD pipelines or as a post-deployment script) ensures that Cert-Manager is fully functional before Ingress resources reference it.


# # Apply CRDs first
# kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds"
# sleep 30
# --------------------------------------------------------
# EXPLANATION: Applying CRDs 
# --------------------------------------------------------
# The command applies Custom Resource Definitions (CRDs) for the AWS Load Balancer Controller in an EKS cluster. The steps involved are:
# Apply CRDs:
# kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds" pulls the required CRDs from the AWS EKS charts repository and applies them to your cluster.
# CRDs are Kubernetes extensions defining custom resource types and APIs (e.g., IngressClass for a load balancer).
# Wait for Propagation:
# sleep 30 adds a 30-second delay to ensure that the CRDs are fully registered and available for subsequent resources that depend on them.


# # Create the self-signed issuer first
# cat <<EOF | kubectl apply -f -
# apiVersion: cert-manager.io/v1
# kind: Issuer
# metadata:
#   name: aws-load-balancer-selfsigned-issuer
#   namespace: kube-system
# spec:
#   selfSigned: {}
# EOF
# --------------------------------------------------------
# EXPLANATION: Applying CRDs 
# --------------------------------------------------------
# What This Command Does:
# Defines an Issuer Resource:
# The Issuer resource is used by Cert-Manager to issue certificates. In this case, it creates a self-signed issuer (aws-load-balancer-selfsigned-issuer) in the kube-system namespace.
# A self-signed issuer is used to generate certificates without relying on an external Certificate Authority (CA).
# Specifies selfSigned Issuer Type:
# The selfSigned: {} block in the spec section means this issuer will generate self-signed certificates, which are not trusted by default in browsers but can be useful for testing or internal communication.
# Applies the Configuration:
# The kubectl apply command creates the issuer in the cluster.
# Why This Might Be Used:
# Testing or Internal Use:
# Self-signed certificates are often used in non-production environments to test setups without requiring a real certificate from a trusted CA (e.g., Let's Encrypt).

# # Wait for issuer to be ready
# sleep 10

# # Apply the main controller configuration
# kubectl apply -f v2_4_7_full.yaml
# --------------------------------------------------------
# EXPLANATION: Apply the main controller configuration
# --------------------------------------------------------
# What the Command Does
# The file v2_4_7_full.yaml likely contains multiple Kubernetes resources necessary for a specific feature or controller. Based on the description, it includes resources related to the AWS Load Balancer Controller or a similar component. Here's a breakdown of the resource types listed:
# IngressClassParams:
# Specifies configuration for custom IngressClass definitions, which may determine how ingress resources are processed by the controller (e.g., specific load balancer behavior).
# TargetGroupBinding:
# Connects Kubernetes services and pods to AWS target groups. Essential for the AWS Load Balancer Controller to route traffic.
# ClusterRole and RoleBinding:
# Define permissions for the controller to interact with Kubernetes API objects and resources.
# Service and Deployment:
# Deploys the actual controller as a service in the cluster, enabling it to manage AWS load balancers for ingress traffic.
# Certificate and Issuer:
# Configures Cert-Manager or similar certificate management components. These resources define how certificates are issued and managed for secure traffic.
# MutatingWebhookConfiguration:
# Used by the controller to dynamically modify or "mutate" Kubernetes objects as they are created. This is common for setting defaults or ensuring compatibility with the controller.
# Do You Need It?
# If You're Using Helm to Deploy the AWS Load Balancer Controller
# No, you likely don’t need this command if you're using the helm_release resource (aws_load_balancer_controller) for deploying the AWS Load Balancer Controller. Helm takes care of deploying all necessary components, including those listed in v2_4_7_full.yaml.
# Helm manages versioning and dependencies, reducing the need to manually apply large configuration files.

# Wait for the certificate to be ready
# echo "Waiting for AWS Load Balancer Controller certificate..."
# kubectl wait --for=condition=ready certificate aws-load-balancer-serving-cert -n kube-system --timeout=300s
# --------------------------------------------------------
# EXPLANATION: Waiting for AWS Load Balancer Controller certificate
# --------------------------------------------------------
# What It Does:
# Waits for a Certificate Resource to Be Ready:
# The kubectl wait command is used to monitor a specific resource in your Kubernetes cluster—in this case, a certificate named aws-load-balancer-serving-cert in the kube-system namespace.
# The condition --for=condition=ready ensures the command waits until the certificate is fully provisioned and ready to use.
# Timeout Parameter:
# The --timeout=300s flag specifies a timeout of 300 seconds (5 minutes). If the certificate is not ready within this time, the command will fail.
# Purpose:
# Ensures that the required certificate is issued and ready before proceeding with other operations (like setting up HTTPS or connecting to an AWS Application Load Balancer).
# This is especially important if the certificate is being provisioned by Cert-Manager (e.g., via Let's Encrypt or a self-signed issuer) and is required for secure communication (TLS).

# Wait for the controller to be ready
# echo "Waiting for AWS Load Balancer Controller pods..."
# kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s
# --------------------------------------------------------
# EXPLANATION: Waiting for AWS Load Balancer Controller pods
# --------------------------------------------------------
# Yes, introducing a kubectl wait command to ensure the AWS Load Balancer Controller pods are ready would be an excellent addition to your Terraform workflow. 
# This ensures that the necessary components are fully running and available before proceeding with subsequent steps, such as creating resources dependent on the controller's availability (like ingress or certificate management).
# Flow:
# Install Cert-Manager (via Helm).
# Create Issuer for Let's Encrypt or a self-signed certificate.
# Deploy AWS Load Balancer Controller (via Helm).
# Wait for Load Balancer Controller pods to be ready.
# Wait for the TLS certificate to be issued by Cert-Manager.
# Once the certificate is ready, your Ingress can be used to manage external traffic securely.

# # Apply remaining resources with increased delays
# kubectl apply -f ingress_class2.yaml
# sleep 45  # Increased delay

kubectl apply -f deployment2.yaml
kubectl apply -f deployment2be.yaml
sleep 45  # Increased delay

kubectl apply -f service2.yaml
kubectl apply -f service2be.yaml
sleep 45  # Increased delay

kubectl apply -f ingress2.yaml
sleep 60  # Increased delay for ingress to be processed

# Wait and get Load Balancer DNS Name
sleep 60  # Increased final wait time
#aws elbv2 describe-load-balancers --names k8s-default-kurak8de-ff2c43794b --query 'LoadBalancers[0].DNSName' --output text >> lb4.txt
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,DNSName]' --output text >> loadbalancerdns8.txt
# Add verification steps
echo "Verifying resources..."
kubectl get certificate -n kube-system
kubectl get pods -n kube-system | grep aws-load-balancer-controller
kubectl get ingress
