helm repo add argo https://argoproj.github.io/argo-helm

helm upgrade argocd argo/argo-cd --install --namespace argocd --create-namespace