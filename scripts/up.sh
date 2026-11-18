#!/usr/bin/env bash
# Bring up the AWS environment: infrastructure, Secrets, the database restore and Argo CD
# (HOW_TO_RUN.md §3).
# Run from Git Bash: ./scripts/up.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# Generate the passwords and keys .env does not have yet (kept between environments)
for v in POSTGRES_PASSWORD AIRBYTE_PG_PASSWORD QUACK_TOKEN \
         POLARIS_POSTGRES_PASSWORD POLARIS_PG_PASSWORD POLARIS_ROOT_SECRET \
         AIRFLOW_POSTGRES_PASSWORD AIRFLOW_PG_PASSWORD AIRFLOW_ADMIN_PASSWORD \
         AIRFLOW_API_SECRET_KEY AIRFLOW_JWT_SECRET; do
  grep -q "^$v=." .env || echo "$v=$(openssl rand -hex 16)" >> .env
done
grep -q '^AIRFLOW_FERNET_KEY=.' .env || echo "AIRFLOW_FERNET_KEY=$(openssl rand -base64 32 | tr '+/' '-_')" >> .env

set -a; source .env; set +a

# Stop if the credentials point to another AWS account
account=$(aws sts get-caller-identity --query Account --output text)
if [ "$account" != "$ACCOUNT_ID" ]; then
  echo "Wrong AWS account: $account (expected $ACCOUNT_ID)" >&2
  exit 1
fi
command -v velero >/dev/null || { echo "Velero CLI not found (HOW_TO_RUN.md §2)" >&2; exit 1; }

# 1. Infrastructure: the persistent buckets first (D-077), then network, EKS and IAM roles
#    (about 15–20 minutes; no prompt)
terraform -chdir=infra/aws/data init
terraform -chdir=infra/aws/data apply -auto-approve
terraform -chdir=infra/aws/cluster init
terraform -chdir=infra/aws/cluster apply -auto-approve

# Velero, before Argo CD starts the services (D-078)
terraform -chdir=infra/aws/backup init
terraform -chdir=infra/aws/backup apply -auto-approve

aws eks update-kubeconfig --name eks-for-data --region us-east-1

# 2. Namespaces and Secrets; safe to run again (create or update)
namespace() {
  kubectl create namespace "$1" --dry-run=client -o yaml | kubectl apply -f -
}
secret() {
  local ns=$1 name=$2
  shift 2
  kubectl -n "$ns" create secret generic "$name" "$@" --dry-run=client -o yaml | kubectl apply -f -
}

namespace postgres
secret postgres postgres-credentials \
  --from-literal=password="$POSTGRES_PASSWORD" \
  --from-literal=airbyte-password="$AIRBYTE_PG_PASSWORD"

namespace duckdb
secret duckdb duckdb-credentials \
  --from-literal=quack-token="$QUACK_TOKEN" \
  --from-literal=postgres-password="$POSTGRES_PASSWORD"

namespace polaris
secret polaris polaris-postgres-credentials \
  --from-literal=password="$POLARIS_POSTGRES_PASSWORD" \
  --from-literal=polaris-password="$POLARIS_PG_PASSWORD"
secret polaris polaris-persistence \
  --from-literal=username=polaris \
  --from-literal=password="$POLARIS_PG_PASSWORD" \
  --from-literal=jdbcUrl=jdbc:postgresql://polaris-postgres.polaris.svc.cluster.local:5432/polaris

namespace airflow
secret airflow airflow-postgres-credentials \
  --from-literal=password="$AIRFLOW_POSTGRES_PASSWORD" \
  --from-literal=airflow-password="$AIRFLOW_PG_PASSWORD"
secret airflow airflow-metadata \
  --from-literal=connection="postgresql://airflow:$AIRFLOW_PG_PASSWORD@airflow-postgres.airflow.svc.cluster.local:5432/airflow"
secret airflow airflow-fernet-key --from-literal=fernet-key="$AIRFLOW_FERNET_KEY"
secret airflow airflow-api-secret-key --from-literal=api-secret-key="$AIRFLOW_API_SECRET_KEY"
secret airflow airflow-jwt-secret --from-literal=jwt-secret="$AIRFLOW_JWT_SECRET"
secret airflow airflow-admin --from-literal=password="$AIRFLOW_ADMIN_PASSWORD"

# 3. Restore the database volumes from the latest backup, before Argo CD starts the databases
#    (D-078, D-080); skipped when the bucket has none (first bring-up, or after a purge)
bucket=eks-for-data-velero-$ACCOUNT_ID
backup=$( (aws s3 ls "s3://$bucket/backups/" || true) | awk '{print $2}' | tr -d / | sort | tail -n 1)
if [ -n "$backup" ]; then
  for i in $(seq 1 60); do   # up to 10 minutes for Velero to read the backup from the bucket
    kubectl -n velero get backup "$backup" >/dev/null 2>&1 && break
    sleep 10
  done
  velero restore create --from-backup "$backup" --include-resources persistentvolumeclaims,volumesnapshots.snapshot.storage.k8s.io,volumesnapshotcontents.snapshot.storage.k8s.io --wait
  restore=$(kubectl -n velero get restores --sort-by=.metadata.creationTimestamp     -o jsonpath='{.items[-1:].metadata.name}')
  phase=$(kubectl -n velero get restore "$restore" -o jsonpath='{.status.phase}')
  if [ "$phase" != Completed ]; then
    echo "Restore $restore ended as $phase (velero restore describe $restore)" >&2
    exit 1
  fi
else
  echo "No backup in $bucket: starting with empty databases"
fi

# 4. Argo CD; it then deploys the services in platform/aws from Git (no prompt)
terraform -chdir=infra/aws/gitops init
terraform -chdir=infra/aws/gitops apply -auto-approve

# 5. Polaris realm bootstrap (D-059), once Argo CD has Polaris and its Postgres Healthy;
#    safe to run again (specs/03-processing-spark-iceberg/HOW_TO_RUN.md §3)
wait_healthy() {
  local app=$1 i
  for i in $(seq 1 120); do   # up to 20 minutes
    [ "$(kubectl -n argocd get application "$app" -o jsonpath='{.status.health.status}' 2>/dev/null)" = Healthy ] && return 0
    sleep 10
  done
  echo "Timed out waiting for application $app to be Healthy" >&2
  return 1
}
wait_healthy polaris-postgres
wait_healthy polaris

kubectl -n polaris run polaris-bootstrap --rm -i --restart=Never \
  --image=apache/polaris-admin-tool:1.8.0 \
  --env="polaris.persistence.type=relational-jdbc" \
  --env="quarkus.datasource.username=polaris" \
  --env="quarkus.datasource.password=$POLARIS_PG_PASSWORD" \
  --env="quarkus.datasource.jdbc.url=jdbc:postgresql://polaris-postgres.polaris.svc.cluster.local:5432/polaris" \
  -- bootstrap -r POLARIS -c "POLARIS,root,$POLARIS_ROOT_SECRET"

echo
echo "Done. Check that every application is Synced and Healthy:"
echo "  kubectl -n argocd get applications"
