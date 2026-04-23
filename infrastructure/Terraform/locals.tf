locals {
  cluster_name = var.cluster_name
  
  # Common labels applied to all resources
  common_labels = merge(
    var.labels,
    {
      terraform   = "true"
      environment = var.environment
    }
  )

  # Kubernetes version without patch number for comparisons
  k8s_version_range = "${var.kubernetes_version}."
}
