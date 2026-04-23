# Terraform Google Cloud GKE Cluster

Production-ready Terraform Infrastructure as Code for provisioning a Google Cloud Kubernetes Engine (GKE) cluster optimized for the [Google Cloud Microservices Demo](https://github.com/GoogleCloudPlatform/microservices-demo) application.

## 📋 Features

### ✅ Networking & Security
- **VPC-native cluster** with custom CIDR ranges for optimal network isolation
- **Cloud NAT gateway** for secure outbound traffic from private nodes
- **VPC Flow Logs** enabled for network debugging and monitoring
- **Network Policy** support for pod-to-pod communication control
- **Shielded GKE nodes** with Secure Boot and Integrity Monitoring

### ✅ Compute & Workload Management
- **Autoscaling node pools** with min/max configuration
- **Multiple node pools** - default and specialized pools for different workload types
- **Workload Identity** for secure pod-to-GCP service authentication
- **Preemptible nodes** option for cost optimization in dev environments
- **Network policies** for granular access control

### ✅ Monitoring & Observability
- **Google Cloud Logging** enabled with workload logs
- **Google Cloud Monitoring** with managed Prometheus support
- **Flow logs** for network traffic analysis

### ✅ Best Practices
- **Input validation** on all variables
- **Comprehensive labels** for resource organization
- **Maintenance windows** for safe cluster updates
- **Binary Authorization** ready (disabled by default)
- **Enable Intra-node visibility** for enhanced security
- **Disabled legacy GCP metadata endpoints**

---

## 🚀 Quick Start

### Prerequisites
1. **Google Cloud Account** with a project created
2. **Terraform** >= 1.0 installed
3. **gcloud CLI** configured and authenticated
4. **kubectl** installed

### 1. Set Up Google Cloud

```bash
# Set your GCP project
export PROJECT_ID="tezadelicenta"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
```

### 2. Configure Terraform Variables

```bash
cd infrastructure/Terraform

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**Key variables to update:**
- `project_id` - Your GCP project ID
- `region` - Cloud region (e.g., `us-central1`, `europe-west1`)
- `cluster_name` - Name for your cluster
- `environment` - `dev`, `staging`, or `prod`

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan & Review

```bash
terraform plan -out=tfplan
```

Review the planned changes carefully, especially for production environments.

### 5. Apply Configuration

```bash
terraform apply tfplan
```

This will take 10-15 minutes to complete. Terraform will create:
- VPC network with subnets
- Cloud Router & NAT gateway
- GKE cluster with node pools
- Kubernetes namespace for the application

### 6. Configure kubectl

Once the cluster is created, configure kubectl:

```bash
gcloud container clusters get-credentials microservices-demo \
    --region us-central1 \
    --project $PROJECT_ID

# Verify connection
kubectl get nodes
```

The kubeconfig command is also available in the Terraform outputs:

```bash
terraform output kubeconfig_command
```

---

## 📊 Cluster Architecture

```
┌─────────────────────────────────────────────────┐
│        Google Cloud VPC Network                  │
│        (10.0.0.0/16)                           │
│                                                  │
│  ┌─────────────────────────────────────────┐   │
│  │       Subnet (10.0.0.0/24)              │   │
│  │                                          │   │
│  │  ┌────────────────────────────────────┐ │   │
│  │  │    GKE Cluster Master              │ │   │
│  │  │  (Managed by Google)               │ │   │
│  │  └────────────────────────────────────┘ │   │
│  │                                          │   │
│  │  ┌────────────────────────────────────┐ │   │
│  │  │    Node Pool #1 (General)          │ │   │
│  │  │  - 3 nodes (auto-scale 1-5)        │ │   │
│  │  │  - n1-standard-2  (dev)            │ │   │
│  │  │  - Pod CIDR: 10.4.0.0/14           │ │   │
│  │  │  - Service CIDR: 10.8.0.0/20       │ │   │
│  │  └────────────────────────────────────┘ │   │
│  │                                          │   │
│  │  ┌────────────────────────────────────┐ │   │
│  │  │    Node Pool #2 (Specialized)      │ │   │
│  │  │  - Production only                 │ │   │
│  │  │  - 1 node (auto-scale 0-3)         │ │   │
│  │  │  - n1-standard-4                   │ │   │
│  │  │  - Tainted for ML workloads        │ │   │
│  │  └────────────────────────────────────┘ │   │
│  │                                          │   │
│  └─────────────────────────────────────────┘   │
│                                                  │
│  ┌─────────────────────────────────────────┐   │
│  │  Cloud Router (BGP ASN: 64514)          │   │
│  │           ↓                              │   │
│  │  Cloud NAT (AUTO_ONLY)                  │   │
│  │  Outbound NAT for private nodes         │   │
│  │  Log Filter: ERRORS_ONLY                │   │
│  └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
         ↕ (Internet Gateway)
     External Internet
```

---

## 🔐 Security Notes

### 🛡️ What's Enabled
- **Workload Identity**: Pod-to-GCP service identity federation (no service account keys needed)
- **Shielded GKE Nodes**: Secure Boot + Integrity Monitoring
- **Network Policies**: Kubernetes-native network segmentation
- **VPC Flow Logs**: Network traffic audit logging
- **Intra-node visibility**: Better pod-to-pod communication visibility
- **Metadata server hardening**: Legacy metadata endpoints disabled

### ⚠️ What to Configure for Production
1. **Binary Authorization**: Ensure signed container images only
   ```hcl
   binary_authorization {
     evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
   }
   ```

2. **Pod Security Standards**: Create PSS policies for namespaces
   ```bash
   kubectl label namespace microservices-demo \
     pod-security.kubernetes.io/enforce=baseline \
     pod-security.kubernetes.io/audit=restricted \
     pod-security.kubernetes.io/warn=restricted
   ```

3. **RBAC**: Set up proper roles and role bindings for team access

4. **Network Egress Control**: Deny-by-default network policies
   ```bash
   kubectl apply -f network-policies/
   ```

### 🔓 What's Disabled (for dev environment)
- **Preemptible nodes** - Enable for cost savings; not recommended for prod
- **Pod Security Policy** - Consider enabling in production
- **Binary Authorization enforcement** - Use in production

---

## 📦 Deploying the Microservices Demo App

### 1. Create GCP Service Accounts (if using Workload Identity)

```bash
# Create a Google Service Account for the microservices
gcloud iam service-accounts create microservices-demo-sa \
    --display-name "Microservices Demo Service Account"

# Bind Workload Identity
gcloud iam service-accounts add-iam-policy-binding \
    microservices-demo-sa@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[microservices-demo/default]"
```

### 2. Deploy the Application

```bash
# Clone the microservices demo repo
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
cd microservices-demo

# Create namespace (if not already created by Terraform)
kubectl create namespace microservices-demo

# Deploy using Kubernetes manifests or Helm
kubectl apply -f ./kubernetes-manifests/ -n microservices-demo

# Or use Helm (if available)
helm install microservices-demo ./helm-chart \
    -n microservices-demo \
    --create-namespace
```

### 3. Verify Deployment

```bash
# Check pods
kubectl get pods -n microservices-demo

# Check services
kubectl get services -n microservices-demo

# Check nodes
kubectl get nodes

# View cluster info
kubectl cluster-info
```

### 4. Access the Application

```bash
# Port-forward to the frontend service
kubectl port-forward svc/frontend 8080:80 -n microservices-demo

# Access at http://localhost:8080
```

---

## 📈 Scaling & Optimization

### Auto-Scaling

The cluster is configured with Cluster Autoscaler enabled by default:

```hcl
autoscaling {
  min_node_count = 1
  max_node_count = 5
}
```

For workload-level scaling, install Horizontal Pod Autoscaler (HPA):

```bash
# HPA is included in GKE by default
kubectl apply -f hpa-configs/
```

### Vertical Pod Autoscaler (VPA)

Optimize resource requests/limits:

```bash
kubectl apply -f https://github.com/kubernetes/autoscaler/releases/download/vertical-pod-autoscaler-0.14.0/vpa-v0.14.0.yaml
```

### Cost Optimization (Dev Only)

For development, enable preemptible nodes by setting:

```hcl
preemptible = true
```

This reduces costs by ~70% but nodes can be terminated with 30-second notice.

---

## 🔄 Updating the Cluster

### Update Kubernetes Version

Edit `terraform.tfvars`:
```hcl
kubernetes_version = "1.28"  # Update the minor version
```

Then apply:
```bash
terraform plan
terraform apply
```

Terraform will update the control plane first, then rolling-update node pools.

### Update Node Machine Type

Edit `terraform.tfvars`:
```hcl
machine_type = "n1-standard-4"  # Upgrade instance size
```

GKE will perform a rolling update (drain → terminate → new node creation).

---

## 📊 Monitoring & Logging

### View Cluster Logs

```bash
# View master logs
gcloud container clusters describe microservices-demo \
    --region us-central1 \
    --credentials=~/.config/gcloud

# View workload logs via Cloud Logging
gcloud logging read \
    "resource.type=k8s_container AND resource.labels.namespace_name=microservices-demo" \
    --limit 50
```

### Access Google Cloud Console

```bash
# Open Google Cloud Console in browser
gcloud console projects describe $PROJECT_ID
```

Navigate to:
- **Kubernetes Engine** → Clusters
- **Logging** → Logs Explorer
- **Monitoring** → Metrics Explorer

---

## 🗑️ Cleanup

To destroy all resources:

```bash
terraform destroy -auto-approve
```

⚠️ **Warning**: This will permanently delete the cluster and all workloads. There is no recovery.

---

## 📚 Advanced Configurations

### Custom Network Policies

Create `network-policies/deny-all-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: microservices-demo
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

Apply it:
```bash
kubectl apply -f network-policies/deny-all-ingress.yaml
```

Then allow specific services:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: microservices-demo
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: ingress
```

### Remote State Backend (Production)

Configure Terraform Cloud or GCS bucket for remote state:

```hcl
# In providers.tf
terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "gke/cluster"
  }
}
```

Create the GCS bucket:
```bash
gsutil mb gs://your-terraform-state-bucket
gsutil versioning set on gs://your-terraform-state-bucket
```

---

## 🐛 Troubleshooting

### Cluster won't reach "Healthy" status

```bash
# Check master logs
gcloud container clusters describe microservices-demo \
    --region us-central1 \
    --format="value(status)"

# Check node status
kubectl get nodes

# Describe problematic node
kubectl describe node <node-name>
```

### Pods stuck in Pending

```bash
# Check resource availability
kubectl describe node <node-name>

# Check pod events
kubectl describe pod <pod-name> -n microservices-demo
```

### Network connectivity issues

```bash
# Check network policies
kubectl get networkpolicies -n microservices-demo

# Check service endpoints
kubectl get endpoints -n microservices-demo
```

---

## 📖 References

- [Google Cloud GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Google Microservices Demo](https://github.com/GoogleCloudPlatform/microservices-demo)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/)
- [GKE Security Hardening](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)

---

## 📝 License

This Terraform configuration is provided as-is under the Apache 2.0 License.

---

## 🤝 Contributing

Found a bug or have suggestions? Please open an issue or submit a pull request.
