# The account ID is part of the Velero bucket name (D-015, D-077)
data "aws_caller_identity" "current" {}

# Created in infra/aws/cluster; found by name
data "aws_iam_role" "velero" {
  name = "${local.name}-velero"
}

# Velero from the official chart, installed before Argo CD (D-078, D-081)
resource "helm_release" "velero" {
  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  version          = "12.2.5"
  namespace        = "velero"
  create_namespace = true

  values = [yamlencode({
    # AWS plugin, copied into the Velero pod by an init container (D-081)
    initContainers = [{
      name            = "velero-plugin-for-aws"
      image           = "velero/velero-plugin-for-aws:v1.14.4"
      imagePullPolicy = "IfNotPresent"
      volumeMounts    = [{ mountPath = "/target", name = "plugins" }]
    }]

    configuration = {
      backupStorageLocation = [{
        name     = "default"
        provider = "aws"
        bucket   = "${local.name}-velero-${data.aws_caller_identity.current.account_id}"
        default  = true
        config   = { region = "us-east-1" }
      }]
      # CSI snapshots through the snapshot controller (D-076)
      features = "EnableCSI"
    }

    # No native EBS snapshotter and no node agent: CSI snapshots only, no data movement (D-076)
    snapshotsEnabled = false
    deployNodeAgent  = false

    # IRSA instead of a credentials Secret (D-008)
    credentials = { useSecret = false }
    serviceAccount = {
      server = {
        name        = "velero"
        annotations = { "eks.amazonaws.com/role-arn" = data.aws_iam_role.velero.arn }
      }
    }

    # The class Velero uses for CSI snapshots; Retain keeps the EBS snapshot after the cluster is
    # gone (D-076, D-085)
    extraObjects = [{
      apiVersion = "snapshot.storage.k8s.io/v1"
      kind       = "VolumeSnapshotClass"
      metadata = {
        name   = "ebs-csi"
        labels = { "velero.io/csi-volumesnapshot-class" = "true" }
      }
      driver         = "ebs.csi.eks.amazonaws.com"
      deletionPolicy = "Retain"
    }]
  })]
}
