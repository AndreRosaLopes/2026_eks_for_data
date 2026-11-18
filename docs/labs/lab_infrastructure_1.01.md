[Labs](README.md) › 1.01

# Lab 1.01 — Services Without Argo CD

> Not verified: this path has not been run end to end, and it is not part of the project plan
> ([D-007](../decisions/007-argo-cd-installation.md)).

## Goal

Install the platform's services by hand, with `kubectl` for plain manifests and `helm` for charts,
instead of Argo CD ([How to Run, 3.1 Bring Up](../../HOW_TO_RUN.md#31-bring-up) step 9). The
manifests in `platform/aws` stay the source of the configuration: plain manifests go through
`kubectl`, and the chart values are read from the Argo CD Application, so nothing is duplicated.
The lab installs the StorageClass and Airbyte.

## Prerequisites

- The infrastructure up, without Argo CD:
  [How to Run, Appendix A.1](../../HOW_TO_RUN.md#a1-bring-up-by-hand), steps 1 to 4 and 6. Skip
  steps 5 and 7 to 10: no Velero, no restore, no Argo CD.
- [Helm](https://helm.sh/docs/intro/install/) 3 and [yq](https://github.com/mikefarah/yq) 4, to
  read the chart values from the Argo CD manifests.

## Concepts

- **Plain manifest vs. chart:** a plain manifest is a YAML file applied as is; a Helm chart is a
  package of templates rendered with values.
- **Helm hooks:** some Airbyte resources (database, ServiceAccount, secrets, bootloader) are Helm
  hooks that must run in order before the rest. `helm install` runs them in that order.
  `helm template ... | kubectl apply -f -` also works for simple charts, but it applies everything
  at once and ignores the hooks, which can break the first start of Airbyte.
- **Release name:** Helm prefixes the resource names with it. It must be `airbyte`, as in Argo CD,
  so the Service names match the specs and [How to Run, 4.4 Airbyte](../../HOW_TO_RUN.md#44-airbyte).

## Steps

1. **StorageClass** (plain manifest):

   ```bash
   kubectl apply -f platform/aws/storageclass.yaml
   ```

2. **Airbyte** (Helm chart): extract the chart version and values from the Application, then
   install with `helm`:

   ```bash
   VERSION=$(yq '.spec.source.targetRevision' platform/aws/airbyte.yaml)
   ```

   ```bash
   yq '.spec.source.helm.valuesObject' platform/aws/airbyte.yaml > airbyte-values.yaml
   ```

   ```bash
   helm repo add airbyte https://airbytehq.github.io/charts
   ```

   ```bash
   helm install airbyte airbyte/airbyte --version "$VERSION" \
     --namespace airbyte --create-namespace --values airbyte-values.yaml --wait --timeout 15m
   ```

   ```bash
   rm airbyte-values.yaml
   ```

3. **Other services** follow the same pattern: `kubectl apply -f` for plain manifests and
   `helm install` for charts, each with its own infrastructure (buckets, IRSA role) in Terraform.

## Validation

```bash
kubectl -n airbyte get pods
```

Expected result: every pod `Running`/`Ready` and the bootloader `Completed`. The Airbyte UI opens
as in [How to Run, 4.4 Airbyte](../../HOW_TO_RUN.md#44-airbyte).

## Break It

Install Airbyte with another release name (for example, `helm install ab airbyte/airbyte ...` in a
new namespace), then run the port-forward of [How to Run, 4.4](../../HOW_TO_RUN.md#44-airbyte)
against that namespace. Find why the Service is not found, with `kubectl get svc`. Uninstall it
before [Cleanup](#cleanup).

## Questions

1. What do you lose without Argo CD? (Git stops being the source of truth, and the cluster keeps
   whatever the last command applied; manual changes are not detected; history lives only in
   `helm history`, which is lost on teardown.)
2. Why does `helm install` work where `helm template ... | kubectl apply -f -` may not?
3. Why are the chart values read from `platform/aws/airbyte.yaml` instead of being copied into a
   values file in the repository?

## Cleanup

Remove what you installed by hand, then destroy only the `cluster` root:

```bash
helm uninstall airbyte --namespace airbyte
kubectl delete namespace airbyte   # PVC → EBS volume deleted
kubectl delete -f platform/aws/storageclass.yaml
terraform -chdir=infra/aws/cluster destroy
```

Then check that nothing is left:
[How to Run, 3.6 Check Nothing Is Left](../../HOW_TO_RUN.md#36-check-nothing-is-left).
