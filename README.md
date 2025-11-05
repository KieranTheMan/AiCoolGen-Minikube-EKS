# AI-Gen-Kube: Kubernetes Deployment Configuration

This repository contains the Kubernetes deployment configurations for the Cool Art Gen application, supporting both local development with Minikube and production deployment on AWS EKS.

## 📋 Table of Contents
- [Architecture Overview](#architecture-overview)
- [Services](#services)
- [Local Deployment with Minikube](#local-deployment-with-minikube)
- [Production Deployment with AWS EKS](#production-deployment-with-aws-eks)
- [Docker Images](#docker-images)
- [Prerequisites](#prerequisites)
- [Deployment Steps](#deployment-steps)

## 🏗️ Architecture Overview

This application consists of two main components:
- **Frontend**: React-based web interface (Port 80)
- **Backend**: Node.js API server (Port 8000)

Both components are containerized and deployed as separate Kubernetes deployments with dedicated services.

## 🔧 Services

### Backend Services

#### 1. Backend NodePort Service (`backend-node-service`)
- **Type**: NodePort
- **Purpose**: Exposes the backend API for external access during local testing
- **Port Configuration**:
  - Service Port: 8000
  - Target Port: 8000
  - NodePort: 30080
- **Selector**: `app: aicoolgen-backend`

#### 2. Backend ClusterIP Service (`backend-clusterip-service`)
- **Type**: ClusterIP
- **Purpose**: Internal cluster communication for backend services
- **Port Configuration**:
  - Service Port: 8000
  - Target Port: 8000
- **Use Case**: Used by the frontend to communicate with the backend within the cluster

### Frontend Services

#### 3. Frontend NodePort Service (`frontend-node-service`)
- **Type**: NodePort
- **Purpose**: Exposes the frontend application for external access during local testing
- **Port Configuration**:
  - Service Port: 80
  - Target Port: 80
  - NodePort: 30081
- **Selector**: `app: aicoolgen-frontend`

#### 4. Frontend ClusterIP Service (`frontend-clusterip-service`)
- **Type**: ClusterIP
- **Purpose**: Internal cluster communication for frontend services
- **Port Configuration**:
  - Service Port: 80
  - Target Port: 80

### Backend Deployment Features
- **Replicas**: 3 instances for high availability
- **Container Port**: 8000
- **Resource Limits**:
  - Memory: 128Mi (request) / 250Mi (limit)
  - CPU: 250m (request) / 500m (limit)
- **Environment Variables** (from Kubernetes Secrets):
  - `OPENAI_API_KEY`: API key for OpenAI integration
  - `MONGODB_URL`: MongoDB connection string
  - `CLOUDINARY_CLOUD_NAME`: Cloudinary cloud storage configuration
  - `CLOUDINARY_API_KEY`: Cloudinary API authentication
  - `CLOUDINARY_API_SECRET`: Cloudinary API secret

### Frontend Deployment Features
- **Replicas**: 3 instances for high availability
- **Container Port**: 80
- **Rolling Update Strategy**:
  - Max Surge: 1
  - Max Unavailable: 0 (ensures zero-downtime deployments)
- **Resource Limits**:
  - Memory: 128Mi (request) / 256Mi (limit)
  - CPU: 100m (request) / 500m (limit)

## 🖥️ Local Deployment with Minikube

### Minikube Configuration

The local deployment setup uses Minikube to simulate a Kubernetes cluster on you local machine for development and testing purposes.

#### Deployment Files Location
```
miniKube/
├── backend-deployment.yml
└── frontend-deployment.yml
```

#### Key Features for Local Testing

1. **NodePort Services**: Both frontend and backend use NodePort services, allowing direct access from your host machine:
   - Frontend: `http://<minikube-ip>:30081`
   - Backend API: `http://<minikube-ip>:30080`

2. **Resource Optimization**: Deployments are configured with minimal resource requirements suitable for local development

3. **Image Pull from AWS ECR**: Even in local testing, the deployments pull Docker images from your AWS Elastic Container Registry (ECR)

### Local Deployment Steps

1. **Start Minikube**:
```bash
minikube start --driver=docker
```

2. **Configure AWS ECR Access**:
```bash
# Get ECR login token
aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <your-ecr-registry>

# Create Kubernetes secret for ECR authentication
kubectl create secret docker-registry ecr-registry-secret \
  --docker-server=<your-ecr-registry> \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region <your-region>)
```

3. **Create Application Secrets**:
```bash
kubectl create secret generic app-secrets \
  --from-literal=OPENAI_API_KEY=<your-openai-key> \
  --from-literal=MONGODB_URL=<your-mongodb-url> \
  --from-literal=CLOUDINARY_CLOUD_NAME=<your-cloudinary-name> \
  --from-literal=CLOUDINARY_API_KEY=<your-cloudinary-key> \
  --from-literal=CLOUDINARY_API_SECRET=<your-cloudinary-secret>
```

4. **Set Environment Variables**:
Create a `.env` file with:
```bash
ECR_REGISTRY=<your-account-id>.dkr.ecr.<region>.amazonaws.com
```

5. **Deploy Backend**:
```bash
export ECR_REGISTRY=<your-account-id>.dkr.ecr.<region>.amazonaws.com
envsubst < miniKube/backend-deployment.yml | kubectl apply -f -
kubectl apply -f services/backend-service.yml
```

6. **Deploy Frontend**:
```bash
envsubst < miniKube/frontend-deployment.yml | kubectl apply -f -
kubectl apply -f services/frontend-service.yml
```

7. **Get Minikube IP and Access Application**:
```bash
minikube ip
# Access frontend at: http://<minikube-ip>:30081
# Access backend at: http://<minikube-ip>:30080
```

8. **Monitor Deployments**:
```bash
kubectl get pods
kubectl get services
kubectl logs <pod-name>
```

## ☁️ Production Deployment with AWS EKS

### EKS Cluster Configuration

The production environment uses Amazon Elastic Kubernetes Service (EKS) for a fully managed, scalable, and highly available Kubernetes cluster.

#### Configuration File Location
```
aws/eks-cluster-config.yml
```

### EKS Cluster Specifications

#### Cluster Metadata
- **Cluster Name**: `aicoolgen-eks-cluster`
- **Region**: `eu-west-2` (London)
- **Kubernetes Version**: `1.28`

#### Identity and Access Management (IAM)
- **OIDC Provider**: Enabled (`withOIDC: true`)
- Allows Kubernetes service accounts to assume AWS IAM roles
- Enables fine-grained permissions for pods

#### Virtual Private Cloud (VPC) Configuration
- **CIDR Block**: `10.0.0.0/16`
- **NAT Gateway**: Single NAT gateway (cost-effective for development; use HighlyAvailable for production)
- **Cluster Endpoints**:
  - Public Access: `false` (enhanced security for production)
  - Private Access: `true` (cluster API accessible only within VPC)

#### Managed Node Group (`aicoolgen-ng-general`)
- **Instance Type**: `t3.small` (2 vCPUs, 2 GiB RAM)
- **Scaling Configuration**:
  - Minimum Size: 3 nodes
  - Maximum Size: 5 nodes
  - Desired Capacity: 2 nodes
- **Storage**:
  - Volume Size: 20 GB
  - Volume Type: `gp3` (latest generation SSD)
- **Labels**:
  - `role: general`
  - `environment: production`
- **Networking**: Private networking enabled for enhanced security

#### IAM Addon Policies (Enabled)
The node group has the following AWS service integrations:
- **Auto Scaler**: Enables Kubernetes Cluster Autoscaler
- **EBS**: Amazon Elastic Block Store integration for persistent volumes
- **EFS**: Amazon Elastic File System integration for shared storage
- **ALB Ingress**: Application Load Balancer ingress controller
- **CloudWatch**: Integration with AWS CloudWatch for monitoring and logging

#### CloudWatch Logging
- **Enabled Log Types**:
  - `api`: Kubernetes API server logs
  - `audit`: Audit logs for compliance
  - `authenticator`: IAM authenticator logs
  - `controllerManager`: Controller manager logs
  - `scheduler`: Scheduler logs
- **Log Retention**: 7 days

### Creating the EKS Cluster

1. **Install eksctl** (if not already installed):
```bash
# Linux
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# macOS
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl
```

2. **Create the Cluster**:
```bash
eksctl create cluster -f aws/eks-cluster-config.yml
```

This process takes approximately 15-20 minutes and will:
- Create a VPC with public and private subnets
- Set up the EKS control plane
- Launch and configure the managed node group
- Configure IAM roles and policies
- Enable CloudWatch logging

3. **Verify Cluster**:
```bash
kubectl get nodes
kubectl cluster-info
```

4. **Configure ECR Image Pull Secret**:
```bash
# Create ECR registry secret for production
kubectl create secret docker-registry ecr-registry-secret \
  --docker-server=<your-ecr-registry> \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region eu-west-2)
```

5. **Create Application Secrets** (same as Minikube):
```bash
kubectl create secret generic app-secrets \
  --from-literal=OPENAI_API_KEY=<your-openai-key> \
  --from-literal=MONGODB_URL=<your-mongodb-url> \
  --from-literal=CLOUDINARY_CLOUD_NAME=<your-cloudinary-name> \
  --from-literal=CLOUDINARY_API_KEY=<your-cloudinary-key> \
  --from-literal=CLOUDINARY_API_SECRET=<your-cloudinary-secret>
```

6. **Deploy Applications**:
```bash
export ECR_REGISTRY=<your-account-id>.dkr.ecr.eu-west-2.amazonaws.com
envsubst < miniKube/backend-deployment.yml | kubectl apply -f -
envsubst < miniKube/frontend-deployment.yml | kubectl apply -f -
kubectl apply -f services/backend-service.yml
kubectl apply -f services/frontend-service.yml
```

7. **Set Up Load Balancer** (for external access in production):
```bash
# Install AWS Load Balancer Controller
# Follow: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

# Then create an Ingress resource or change services to LoadBalancer type
```

### Updating the Cluster
```bash
eksctl update cluster -f aws/eks-cluster-config.yml
```

### Deleting the Cluster
```bash
eksctl delete cluster -f aws/eks-cluster-config.yml
```

## 🐳 Docker Images

### AWS Elastic Container Registry (ECR)

All Docker images for this application are stored in AWS ECR, a fully managed container registry that provides secure, scalable, and reliable storage.

#### Images Used
1. **Backend Image**: `${ECR_REGISTRY}/ai-gen-app-backend:latest`
2. **Frontend Image**: `${ECR_REGISTRY}/ai-gen-app-frontend:latest`

Where `${ECR_REGISTRY}` is your AWS ECR registry URL in the format:
```
<account-id>.dkr.ecr.<region>.amazonaws.com
```

### Image Pull Configuration

Both deployments use the `imagePullSecrets` configuration to authenticate with AWS ECR:

```yaml
imagePullSecrets:
  - name: ecr-registry-secret
```

This secret must be created in your Kubernetes cluster before deploying the applications.

### Creating ECR Repositories

If you haven't already created the ECR repositories:

```bash
# Create backend repository
aws ecr create-repository \
  --repository-name ai-gen-app-backend \
  --region <your-region>

# Create frontend repository
aws ecr create-repository \
  --repository-name ai-gen-app-frontend \
  --region <your-region>
```

### Pushing Images to ECR

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <your-ecr-registry>

# Tag your images
docker tag ai-gen-app-backend:latest <your-ecr-registry>/ai-gen-app-backend:latest
docker tag ai-gen-app-frontend:latest <your-ecr-registry>/ai-gen-app-frontend:latest

# Push images
docker push <your-ecr-registry>/ai-gen-app-backend:latest
docker push <your-ecr-registry>/ai-gen-app-frontend:latest
```

### Image Pull Process

When Kubernetes deploys the pods:
1. Kubernetes reads the `imagePullSecrets` from the deployment manifest
2. Uses the `ecr-registry-secret` credentials to authenticate with AWS ECR
3. Pulls the specified image from ECR
4. Creates the container using the pulled image

This process works identically for both Minikube (local) and EKS (production) deployments.

## 📦 Prerequisites

### Software Requirements
- **kubectl**: Kubernetes command-line tool
- **Docker**: Container runtime
- **AWS CLI**: For AWS service interaction
- **eksctl**: For EKS cluster management
- **Minikube**: For local Kubernetes testing

### AWS Requirements
- Active AWS account
- AWS ECR repositories created
- IAM permissions for:
  - EKS cluster creation
  - ECR access
  - VPC management
  - CloudWatch logging

### Secrets Required
- OpenAI API key
- MongoDB connection URL
- Cloudinary credentials (cloud name, API key, API secret)

## 🚀 Deployment Steps

### Quick Start Script

The provided `deploy.sh` script simplifies deployment:

```bash
#!/bin/bash
set -a
source .env
set +a
# Deploy backend
envsubst < backend-deployment.yml | kubectl apply -f -
# Deploy frontend
envsubst < frontend-deployment.yml | kubectl apply -f -
```

**Usage**:
1. Create a `.env` file with your `ECR_REGISTRY` value
2. Run: `chmod +x deploy.sh && ./deploy.sh`

### Manual Deployment

Refer to the [Local Deployment](#local-deployment-steps) or [Production Deployment](#creating-the-eks-cluster) sections above for detailed step-by-step instructions.

## 🔍 Monitoring and Troubleshooting

### View Pods
```bash
kubectl get pods
kubectl describe pod <pod-name>
```

### View Logs
```bash
kubectl logs <pod-name>
kubectl logs -f <pod-name>  # Follow logs
```

### View Services
```bash
kubectl get services
kubectl describe service <service-name>
```

### Common Issues

1. **ImagePullBackOff**: ECR credentials are incorrect or expired
   - Solution: Recreate the `ecr-registry-secret`

2. **CrashLoopBackOff**: Application secrets are missing
   - Solution: Verify `app-secrets` exists and contains all required keys

3. **Service not accessible**: NodePort might not be exposed correctly
   - Solution: Check `minikube service list` or verify security groups in AWS

## 📝 Notes

- The EKS cluster configuration uses private endpoints for enhanced security. Ensure you have VPN or bastion host access to manage the cluster.
- For production, consider changing the NAT gateway configuration to `HighlyAvailable` for better fault tolerance.
- The current configuration uses `t3.small` instances. Scale up for higher workloads.
- CloudWatch logs are retained for 7 days. Adjust `logRetentionInDays` as needed.
- Both frontend and backend run 3 replicas for high availability and load distribution.

## 🏷️ Tags and Labels

The EKS node group uses the following labels and tags:
- `role: general`
- `environment: production`

## 👤 Author

Kieran

