#!/usr/bin/env bash
# Bring up the AWS environment: infrastructure, Secrets and Argo CD (HOW_TO_RUN.md §3.1 and §3.2).
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

# 1. Infrastructure: network, EKS, buckets, IAM roles (about 15–20 minutes; asks for "yes")
terraform -chdir=infra/aws/cluster init
terraform -chdir=infra/aws/cluster apply

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

# 3. Argo CD; it then deploys the services in platform/aws from Git (asks for "yes")
terraform -chdir=infra/aws/gitops init
terraform -chdir=infra/aws/gitops apply

echo
echo "Done. Wait until every application is Synced and Healthy:"
echo "  kubectl -n argocd get applications"
echo "Then bootstrap the Polaris realm (specs/03-processing-spark-iceberg/HOW_TO_RUN.md §3)."
