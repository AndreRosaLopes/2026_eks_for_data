#!/usr/bin/env bash
# Tear down the AWS environment (HOW_TO_RUN.md §5). The databases are backed up with Velero first,
# and the buckets in infra/aws/data are kept, with their data (D-076, D-077).
# Run from Git Bash: ./scripts/down.sh
# Full reset (D-088): ./scripts/down.sh --purge deletes every backup and the buckets instead
set -euo pipefail
cd "$(dirname "$0")/.."

purge=false
[ "${1:-}" = --purge ] && purge=true

set -a; source .env; set +a

# Stop if the credentials point to another AWS account
account=$(aws sts get-caller-identity --query Account --output text)
if [ "$account" != "$ACCOUNT_ID" ]; then
  echo "Wrong AWS account: $account (expected $ACCOUNT_ID)" >&2
  exit 1
fi
command -v velero >/dev/null || { echo "Velero CLI not found (HOW_TO_RUN.md §2)" >&2; exit 1; }

# Make sure kubectl targets this cluster before deleting anything
aws eks update-kubeconfig --name eks-for-data --region us-east-1

# 1. Stop the services; the databases shut down cleanly and their volumes stay (D-079, D-086)
kubectl delete pod --all                                   # no test pods keeping nodes alive
kubectl delete application platform -n argocd --ignore-not-found   # waits for the child applications
# airbyte-db is a Helm hook, which Argo CD may leave running
kubectl -n airbyte delete statefulset airbyte-db --cascade=foreground --ignore-not-found

databases=postgres,polaris,airflow,airbyte

if [ "$purge" = false ]; then
  # 2. Back up the database volumes; stop before deleting anything if it fails (D-079)
  backup=lab-$(date -u +%Y%m%d%H%M%S)
  velero backup create "$backup" --include-namespaces "$databases" \
    --include-resources persistentvolumeclaims --wait
  phase=$(kubectl -n velero get backup "$backup" -o jsonpath='{.status.phase}')
  if [ "$phase" != Completed ]; then
    echo "Backup $backup ended as $phase; nothing was deleted (velero backup describe $backup)" >&2
    exit 1
  fi

  # 3. Keep the latest backup only; the delete also removes the older snapshots (D-080)
  for old in $(kubectl -n velero get backups -o jsonpath='{.items[*].metadata.name}'); do
    [ "$old" = "$backup" ] || velero backup delete "$old" --confirm
  done
else
  # 2. Purge: delete every backup, with its bucket files and EBS snapshots (D-088)
  velero backup delete --all --confirm
  for i in $(seq 1 60); do   # up to 10 minutes
    [ -z "$(kubectl -n velero get backups -o name)" ] && break
    sleep 10
  done
  [ -z "$(kubectl -n velero get backups -o name)" ] || { echo "Backups still being deleted" >&2; exit 1; }
fi

# 4. The database namespaces, with their PVCs and EBS volumes (D-086)
kubectl delete namespace ${databases//,/ } --ignore-not-found

# 5. Argo CD, Velero, then the infrastructure (no prompt)
terraform -chdir=infra/aws/gitops destroy -auto-approve
terraform -chdir=infra/aws/backup destroy -auto-approve
terraform -chdir=infra/aws/cluster destroy -auto-approve

# 6. EKS may recreate its log group after the destroy; the next apply fails if it exists
log_group=/aws/eks/eks-for-data/cluster
if MSYS_NO_PATHCONV=1 aws logs describe-log-groups --log-group-name-prefix "$log_group" \
     --region us-east-1 --query 'logGroups[].logGroupName' --output text | grep -q .; then
  MSYS_NO_PATHCONV=1 aws logs delete-log-group --log-group-name "$log_group" --region us-east-1
fi

# 7. Purge only: the buckets, with every file in them (D-082)
if [ "$purge" = true ]; then
  terraform -chdir=infra/aws/data destroy -auto-approve
fi

# 8. Check nothing is left; every line must be empty (NAT Gateways may show "deleting" for minutes)
P="--region us-east-1 --output text"
aws eks list-clusters $P --query 'clusters'
aws ec2 describe-nat-gateways $P --query 'NatGateways[?State!=`deleted`].[NatGatewayId,State]'
aws ec2 describe-addresses $P --query 'Addresses[].PublicIp'
aws ec2 describe-vpcs --filters Name=tag:project,Values=2026_eks_for_data $P --query 'Vpcs[].VpcId'

kubectl config delete-context "arn:aws:eks:us-east-1:$ACCOUNT_ID:cluster/eks-for-data" || true
