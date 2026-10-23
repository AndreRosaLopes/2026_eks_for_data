# Argo CD from the official chart (D-007)
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.10.5"
  namespace        = "argocd"
  create_namespace = true

  # Dex only provides SSO, unused in this phase (login with the local admin user)
  values = [yamlencode({
    dex = { enabled = false }
  })]
}

# Root Application (app-of-apps): Argo CD deploys every Application in platform/aws.
# A separate chart, because the Application CRD does not exist until Argo CD is installed.
resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.7"
  namespace  = "argocd"

  values = [yamlencode({
    applications = {
      platform = {
        namespace  = "argocd"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project    = "default"
        source = {
          repoURL        = "https://github.com/AndreRosaLopes/2026_eks_for_data.git"
          targetRevision = "main"
          path           = "platform/aws"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
