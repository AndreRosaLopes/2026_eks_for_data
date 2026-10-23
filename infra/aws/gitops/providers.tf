terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.59"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }
}

# Credentials come from AWS_PROFILE (see .env); the region is fixed by D-001.
provider "aws" {
  region = "us-east-1"
}

# Found by name: no wiring between this state and the cluster state (D-003)
data "aws_eks_cluster" "this" {
  name = "eks-for-data"
}

# Temporary token from `aws eks get-token`; no saved kubeconfig
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.this.name, "--region", "us-east-1"]
    }
  }
}
