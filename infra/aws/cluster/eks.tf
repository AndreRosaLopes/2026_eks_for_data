module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = local.name
  kubernetes_version = "1.37"

  # Auto Mode with the general-purpose pool only (D-006)
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Public API restricted to the operator's IP (D-012)
  endpoint_public_access       = true
  endpoint_public_access_cidrs = [var.operator_cidr]

  # Access entries only; the caller of Terraform becomes cluster admin
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  # OIDC provider for IRSA (D-008)
  enable_irsa = true

  # EKS default envelope encryption, no customer KMS key (D-014)
  create_kms_key    = false
  encryption_config = null
}
