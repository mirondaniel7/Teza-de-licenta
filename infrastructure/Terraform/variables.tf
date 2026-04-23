variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must follow Google Cloud naming conventions."
  }
}

variable "region" {
  description = "Google Cloud region for resources"
  type        = string
  default     = "us-central1"
  validation {
    condition     = contains(["us-central1", "us-east1", "us-west1", "europe-west1", "asia-southeast1"], var.region)
    error_message = "Region must be a valid Google Cloud region."
  }
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "microservices-demo"
  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{0,38}[a-z0-9]$", var.cluster_name))
    error_message = "Cluster name must be valid Kubernetes name format."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the cluster (will use the latest available patch version for the specified minor version)"
  type        = string
  default     = "1.27"
}

variable "network_ipv4_cidr" {
  description = "IPv4 CIDR for the VPC network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_secondary_range_name" {
  description = "Secondary IP range name for Pod networking"
  type        = string
  default     = "pods"
}

variable "cluster_secondary_range_cidr" {
  description = "IPv4 CIDR for pods"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_secondary_range_name" {
  description = "Secondary IP range name for Services"
  type        = string
  default     = "services"
}

variable "services_secondary_range_cidr" {
  description = "IPv4 CIDR for services"
  type        = string
  default     = "10.8.0.0/20"
}

variable "initial_node_count" {
  description = "Initial number of nodes in the primary node pool"
  type        = number
  default     = 3
  validation {
    condition     = var.initial_node_count >= 1 && var.initial_node_count <= 10
    error_message = "Initial node count should be between 1 and 10."
  }
}

variable "min_node_count" {
  description = "Minimum number of nodes per zone in the node pool"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes per zone in the node pool"
  type        = number
  default     = 5
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-standard-2"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.machine_type))
    error_message = "Machine type name is invalid."
  }
}

variable "disk_size_gb" {
  description = "Disk size for nodes in GB"
  type        = number
  default     = 50
  validation {
    condition     = var.disk_size_gb >= 20 && var.disk_size_gb <= 500
    error_message = "Disk size must be between 20 and 500 GB."
  }
}

variable "enable_autoscaling" {
  description = "Enable Kubernetes autoscaling on node pools"
  type        = bool
  default     = true
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity on the cluster"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable Google Cloud monitoring and logging"
  type        = bool
  default     = true
}

variable "enable_http_load_balancing" {
  description = "Enable HTTP(S) Load Balancing addon"
  type        = bool
  default     = true
}

variable "enable_network_policy" {
  description = "Enable Network Policy addon"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels to apply to cluster resources"
  type        = map(string)
  default = {
    environment = "dev"
    managed-by  = "terraform"
  }
}

variable "maintenance_window_start_time" {
  description = "Start time for maintenance window (HH:mm format)"
  type        = string
  default     = "00:00"
  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window_start_time))
    error_message = "Maintenance window start time must be in HH:mm format."
  }
}

variable "enable_pod_security_policy" {
  description = "Enable Pod Security Policy (deprecated but may be needed for older clusters)"
  type        = bool
  default     = false
}
