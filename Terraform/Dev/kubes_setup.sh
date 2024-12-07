#!/bin/bash

AWS_PROFILE=finalProj

# Create policy 
AWS_PROFILE=finalProj aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

# Associate IAM OIDC provider
AWS_PROFILE=finalProj eksctl utils associate-iam-oidc-provider --region=us-east-1 --cluster=my-eks-cluster --approve

# Create IAM service account
AWS_PROFILE=finalProj eksctl create iamserviceaccount \
  --cluster=my-eks-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::302263083174:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Ensure that your kubeconfig file points to the correct cluster API server.
AWS_PROFILE=finalProj aws eks update-kubeconfig --region us-east-1 --name my-eks-cluster

# Install cert-manager first and ensure it's ready
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml

# Wait for cert-manager to be ready - increased timeout and added verification
echo "Waiting for cert-manager pods to be ready..."
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s
kubectl wait --for=condition=ready pod -l app=cainjector -n cert-manager --timeout=300s
kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=300s

# Apply CRDs first
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds"
sleep 30

# Create the self-signed issuer first
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: aws-load-balancer-selfsigned-issuer
  namespace: kube-system
spec:
  selfSigned: {}
EOF

# Wait for issuer to be ready
sleep 10

# Apply the main controller configuration
kubectl apply -f v2_4_7_full.yaml

# Wait for the certificate to be ready
echo "Waiting for AWS Load Balancer Controller certificate..."
kubectl wait --for=condition=ready certificate aws-load-balancer-serving-cert -n kube-system --timeout=300s

# Wait for the controller to be ready
echo "Waiting for AWS Load Balancer Controller pods..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s

# Apply remaining resources with increased delays
kubectl apply -f ingress_class.yaml
sleep 45  # Increased delay

kubectl apply -f deployment.yaml
sleep 45  # Increased delay

kubectl apply -f service.yaml
sleep 45  # Increased delay

kubectl apply -f ingress.yaml
sleep 60  # Increased delay for ingress to be processed

# Wait and get Load Balancer DNS Name
sleep 60  # Increased final wait time
#aws elbv2 describe-load-balancers --names k8s-default-kurak8de-ff2c43794b --query 'LoadBalancers[0].DNSName' --output text >> lb4.txt
AWS_PROFILE=finalProj aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,DNSName]' --output text >> loadbalancerdns7.txt
# Add verification steps
echo "Verifying resources..."
kubectl get certificate -n kube-system
kubectl get pods -n kube-system | grep aws-load-balancer-controller
kubectl get ingress