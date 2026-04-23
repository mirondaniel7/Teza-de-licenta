# ============================================================================
# VPC Network
# ============================================================================

resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  project                 = var.project_id
}

# ============================================================================
# Subnet with Secondary IP Ranges (for Pods and Services)
# ============================================================================

resource "google_compute_subnetwork" "clusters" {
  name          = "${var.cluster_name}-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.network_ipv4_cidr

  # Secondary IP ranges for VPC-native GKE
  secondary_ip_range {
    range_name    = var.cluster_secondary_range_name
    ip_cidr_range = var.cluster_secondary_range_cidr
  }

  secondary_ip_range {
    range_name    = var.services_secondary_range_name
    ip_cidr_range = var.services_secondary_range_cidr
  }

  # Flow logs for network troubleshooting
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ============================================================================
# Cloud Router (for NAT gateway outbound traffic)
# ============================================================================

resource "google_compute_router" "router" {
  name    = "${var.cluster_name}-router"
  region  = var.region
  project = var.project_id
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ============================================================================
# GKE Cluster
# ============================================================================

resource "google_container_cluster" "primary" {
  name       = var.cluster_name
  location   = var.region
  project    = var.project_id

  initial_node_count = var.initial_node_count
  remove_default_node_pool = false

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.clusters.name

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.cluster_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  node_config {
    machine_type = var.machine_type
    disk_type    = "pd-standard"
    disk_size_gb = var.disk_size_gb
  }

  resource_labels = merge(var.labels, {
    cluster_name = var.cluster_name
    environment  = var.environment
  })

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  depends_on = [
    google_compute_router_nat.nat
  ]
}

# ============================================================================
# Additional Node Pool (optional - for specialized workloads)
# ============================================================================

resource "google_container_node_pool" "specialized" {
  count = var.environment == "prod" ? 1 : 0

  name       = "specialized-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  project    = var.project_id
  
  initial_node_count = 1

  autoscaling {
    min_node_count = 0
    max_node_count = 3
  }

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 50

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = merge(
      var.labels,
      {
        node_pool       = "specialized-pool"
        workload_type   = "ml-inference"
      }
    )

    # Taint this node pool to control workload placement
    taint {
      key    = "specialized"
      value  = "ml-workloads"
      effect = "NO_EXECUTE"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# ============================================================================
# Kubernetes Resources (via Terraform Kubernetes Provider)
# ============================================================================

# Create dedicated namespace for the app
resource "kubernetes_namespace" "app" {
  metadata {
    name = "microservices-demo"
    labels = merge(
      var.labels,
      {
        name = "microservices-demo"
      }
    )
  }

  depends_on = [google_container_cluster.primary]
}

# Network Policy for pod-to-pod communication control
resource "kubernetes_network_policy" "default_deny" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "default-deny-ingress"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress"]
  }
}
