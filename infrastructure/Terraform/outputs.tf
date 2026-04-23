output "kubernetes_cluster_name" {
  description = "GKE Kubernetes Cluster Name"
  value       = google_container_cluster.primary.name
  sensitive   = false
}

output "kubernetes_cluster_host" {
  description = "GKE Cluster Endpoint"
  value       = "https://${google_container_cluster.primary.endpoint}"
  sensitive   = true
}

output "region" {
  description = "Google Cloud Region"
  value       = var.region
}

output "project_id" {
  description = "Google Cloud Project ID"
  value       = var.project_id
}

output "vpc_network_name" {
  description = "VPC Network Name"
  value       = google_compute_network.vpc.name
}

output "vpc_subnetwork_name" {
  description = "VPC Subnetwork Name"
  value       = google_compute_subnetwork.clusters.name
}

output "vpc_subnetwork_self_link" {
  description = "VPC Subnetwork Self Link"
  value       = google_compute_subnetwork.clusters.self_link
}

output "router_name" {
  description = "Cloud Router Name (handles traffic routing)"
  value       = google_compute_router.router.name
}

output "nat_gateway_ip" {
  description = "NAT Gateway External IPs"
  value       = google_compute_router_nat.nat.name
  sensitive   = false
}

output "kubernetes_namespace" {
  description = "Kubernetes Namespace for the application"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "kubeconfig_command" {
  description = "Command to configure kubectl to access the cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
  sensitive   = false
}

output "cluster_ca_certificate" {
  description = "Cluster CA Certificate (base64 encoded)"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "vertical_pod_autoscaler_config" {
  description = "Configuration for Vertical Pod Autoscaler setup"
  value       = "Install VPA with: kubectl apply -f https://github.com/kubernetes/autoscaler/releases/download/vertical-pod-autoscaler-0.14.0/vpa-v0.14.0.yaml"
}

output "monitoring_setup" {
  description = "Google Cloud monitoring is enabled"
  value       = var.enable_monitoring
}
