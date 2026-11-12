#!/usr/bin/env bash
# Tear down the AWS environment (HOW_TO_RUN.md §5.1 and §5.2). Bronze and silver data is lost.
# Run from Git Bash: ./scripts/down.sh
set -euo pipefail
cd "$(dirname "$0")/.."

set -a; source .env; set +a

# Stop if the credentials point to another AWS account
account=$(aws sts get-caller-identity --query Account --output text)
if [ "$account" != "$ACCOUNT_ID" ]; then
  echo "Wrong AWS account: $account (expected $ACCOUNT_ID)" >&2
  exit 1
fi

# Make sure kubectl targets this cluster before deleting anything
aws eks update-kubeconfig --name eks-for-data --region us-east-1

# 1. Services, while the cluster is up, so their EBS volumes are deleted with them
kubectl delete pod --all                                   # no test pods keeping nodes alive
kubectl delete application platform -n argocd --ignore-not-found   # waits for the child applications
kubectl delete namespace airbyte --ignore-not-found        # PVC → Airbyte EBS volume deleted

# 2. Argo CD, then the infrastructure (each asks for "yes")
terraform -chdir=infra/aws/gitops destroy
terraform -chdir=infra/aws/cluster destroy

# 3. EKS may recreate its log group after the destroy; the next apply fails if it exists
log_group=/aws/eks/eks-for-data/cluster
if MSYS_NO_PATHCONV=1 aws logs describe-log-groups --log-group-name-prefix "$log_group" \
     --region us-east-1 --query 'logGroups[].logGroupName' --output text | grep -q .; then
  MSYS_NO_PATHCONV=1 aws logs delete-log-group --log-group-name "$log_group" --region us-east-1
fi

# 4. Check nothing is left; every line must be empty (NAT Gateways may show "deleting" for minutes)
P="--region us-east-1 --output text"
aws eks list-clusters $P --query 'clusters'
aws ec2 describe-nat-gateways $P --query 'NatGateways[?State!=`deleted`].[NatGatewayId,State]'
aws ec2 describe-addresses $P --query 'Addresses[].PublicIp'
aws ec2 describe-vpcs --filters Name=tag:project,Values=2026_eks_for_data $P --query 'Vpcs[].VpcId'

kubectl config delete-context "arn:aws:eks:us-east-1:$ACCOUNT_ID:cluster/eks-for-data" || true
