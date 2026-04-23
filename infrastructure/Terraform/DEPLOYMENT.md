# Deployment Guide: Microservices Demo on GKE

This guide walks through deploying the Google Cloud Microservices Demo application on the GKE cluster created by Terraform.

## Prerequisites

- ✅ GKE cluster created via Terraform (see [README.md](./README.md))
- ✅ kubectl configured and authenticated
- ✅ Optional: Helm 3.x (for Helm-based deployment)

---

## 📋 Step 1: Prepare the Cluster

### 1.1 Verify Cluster is Running

```bash
# Check cluster status
kubectl cluster-info

# Check nodes are ready
kubectl get nodes

# Expected output (3 nodes in dev):
# NAME                                          STATUS   ROLES    AGE   VERSION
# gke-microservices-demo-default-pool-xyz...   Ready    <none>   15m   v1.27.x
# gke-microservices-demo-default-pool-abc...   Ready    <none>   15m   v1.27.x
# gke-microservices-demo-default-pool-def...   Ready    <none>   15m   v1.27.x
```

### 1.2 Create Application Namespace

The Terraform configuration creates a namespace automatically:

```bash
# Verify it exists
kubectl get namespace microservices-demo

# Label for pod security policies (optional)
kubectl label namespace microservices-demo \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite=true
```

### 1.3 Check Addon Status

Verify required Kubernetes addons are enabled:

```bash
# Check HTTP Load Balancing
kubectl get deployments -n kube-system | grep gke-metrics

# Check Metrics Server (for HPA/VPA)
kubectl get deployment metrics-server -n kube-system

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

---

## 📦 Step 2: Clone and Prepare the Application

### 2.1 Clone Microservices Demo Repository

```bash
# Clone the official repo
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
cd microservices-demo

# Verify structure
ls -la
# kubernetes-manifests/  (traditional Kubernetes manifests)
# helm-chart/            (Helm charts - optional)
# docker-compose.yml     (Local development)
# ...
```

### 2.2 Review Kubernetes Manifests

```bash
# List all manifest files
ls -la kubernetes-manifests/

# Key services:
# - frontend.yaml                 (Go, port 80)
# - cartservice.yaml              (C#, gRPC)
# - productcatalogservice.yaml    (Go, gRPC)
# - recommendationservice.yaml    (Python, gRPC)
# - checkoutservice.yaml          (Go, gRPC)
# - paymentservice.yaml           (Node.js, gRPC)
# - shippingservice.yaml          (Go, gRPC)
# - emailservice.yaml             (Python, gRPC)
# - currencyservice.yaml          (Node.js, gRPC)
# - adservice.yaml                (Java, gRPC)
# - redis.yaml                    (Redis, in-memory cache)
```

---

## 🚀 Step 3: Deploy the Application

### Option A: Traditional kubectl Apply (Simple)

```bash
# Deploy all services to the microservices-demo namespace
kubectl apply -f kubernetes-manifests/ -n microservices-demo

# Verify deployment
kubectl get deployments -n microservices-demo
kubectl get pods -n microservices-demo
kubectl get services -n microservices-demo
```

**Expected Deployments:**
```
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
adservice               1/1     1            1           90s
cartservice             1/1     1            1           90s
checkoutservice         1/1     1            1           90s
currencyservice         1/1     1            1           90s
emailservice            1/1     1            1           90s
frontend                1/1     1            1           90s
paymentservice          1/1     1            1           90s
productcatalogservice   1/1     1            1           90s
recommendationservice   1/1     1            1           90s
shippingservice         1/1     1            1           90s
redis-cart              1/1     1            1           90s
```

### Option B: Helm Deployment (Recommended for Production)

```bash
# Add Helm repo (if the chart is hosted)
# helm repo add microservices-demo https://...
# helm repo update

# Install using Helm chart
helm install microservices-demo ./release/helm-chart \
  --namespace microservices-demo \
  --create-namespace \
  --values helm-chart/values.yaml

# Or with custom values:
helm install microservices-demo ./release/helm-chart \
  --namespace microservices-demo \
  --set image.tag=v0.3.0 \
  --set replicas=3
```

---

## ✅ Step 4: Verify Deployment

### 4.1 Check All Pods are Running

```bash
# Watch pod startup (press Ctrl+C to exit)
kubectl get pods -n microservices-demo -w

# All pods should reach "Running" status within 2-3 minutes
```

### 4.2 Check Pod Logs

```bash
# Check frontend logs
kubectl logs -n microservices-demo deployment/frontend --tail=20

# Check a specific pod
kubectl logs -n microservices-demo <pod-name>

# Stream logs in real-time
kubectl logs -n microservices-demo -f deployment/frontend
```

### 4.3 Verify Services

```bash
# List all services
kubectl get services -n microservices-demo

# Example output:
# NAME                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)             AGE
# adservice               ClusterIP   10.0.32.10     <none>        9555/TCP            90s
# cartservice             ClusterIP   10.0.32.11     <none>        7070/TCP            90s
# checkoutservice         ClusterIP   10.0.32.12     <none>        5050/TCP            90s
# currencyservice         ClusterIP   10.0.32.13     <none>        7000/TCP            90s
# emailservice            ClusterIP   10.0.32.14     <none>        8080/TCP            90s
# frontend                LoadBalancer 10.0.32.100   35.xxx.xxx.xxx 80:30000/TCP       90s
# paymentservice          ClusterIP   10.0.32.15     <none>        50051/TCP           90s
# productcatalogservice   ClusterIP   10.0.32.16     <none>        3550/TCP            90s
# recommendationservice   ClusterIP   10.0.32.17     <none>        8080/TCP            90s
# shippingservice         ClusterIP   10.0.32.18     <none>        50051/TCP           90s
# redis-cart              ClusterIP   10.0.32.19     <none>        6379/TCP            90s
```

### 4.4 Check Resource Usage

```bash
# View node resource usage
kubectl top nodes

# View pod resource usage
kubectl top pods -n microservices-demo

# Example output:
# NAME                                READY   STATUS    RESTARTS   AGE     CPU(m)   MEMORY(Mi)
# frontend-7c9g5                      1/1     Running   0          90s     50m      128Mi
# cartservice-12a4b                   1/1     Running   0          90s     10m      256Mi
# redis-cart-xyz9a                    1/1     Running   0          90s     5m       64Mi
```

---

## 🌐 Step 5: Access the Application

### 5.1 Get the Frontend External IP

```bash
# Watch for External IP assignment
kubectl get service frontend -n microservices-demo -w

# Wait ~2-3 minutes for the LoadBalancer to be provisioned
# Once assigned, you'll see the external IP
```

### 5.2 Access via External IP

```bash
# Once you have the external IP:
FRONTEND_IP=$(kubectl get service frontend -n microservices-demo \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Access the app at: http://$FRONTEND_IP"

# Or manually (from output above)
# http://35.xxx.xxx.xxx
```

### 5.3 Local Port-Forwarding (Alternative)

```bash
# If you want to access via localhost
kubectl port-forward svc/frontend 8080:80 -n microservices-demo

# Access at: http://localhost:8080
# Press Ctrl+C to stop port-forward
```

---

## 📊 Step 6: Monitoring & Debugging

### 6.1 View Pod Events

```bash
# Check events for the entire namespace
kubectl get events -n microservices-demo

# Describe a specific pod to see recent events
kubectl describe pod <pod-name> -n microservices-demo
```

### 6.2 Execute Commands Inside Pods

```bash
# Open a shell in a pod
kubectl exec -it <pod-name> -n microservices-demo -- /bin/sh

# Or run a single command
kubectl exec <pod-name> -n microservices-demo -- curl http://localhost:8080/health
```

### 6.3 View Google Cloud Logs

```bash
# View logs via Cloud Logging (last 50 lines)
gcloud logging read \
  "resource.type=k8s_container AND resource.labels.namespace_name=microservices-demo" \
  --limit 50 \
  --format json

# Filter by pod
gcloud logging read \
  "resource.type=k8s_container AND resource.labels.pod_name=frontend-xyz" \
  --limit 20
```

### 6.4 Monitor Metrics in Cloud Console

```bash
# Open Cloud Console
gcloud console projects describe $(gcloud config get-value project)

# Navigate to:
# 1. Kubernetes Engine → Workloads
# 2. Monitoring → Dashboards → Kubernetes
# 3. Logging → Logs Explorer
```

---

## 🔄 Step 7: Update & Scale Deployment

### 7.1 Scale a Deployment

```bash
# Scale the frontend to 3 replicas
kubectl scale deployment frontend -n microservices-demo --replicas=3

# Watch the scaling
kubectl get pods -n microservices-demo -w
```

### 7.2 Update a Service Image

```bash
# Update frontend image to a new version
kubectl set image deployment/frontend \
  frontend=gcr.io/google-samples/microservices-demo/frontend:v0.3.1 \
  -n microservices-demo

# Watch the rolling update
kubectl rollout status deployment/frontend -n microservices-demo
```

### 7.3 View Rollout History

```bash
# Check deployment history
kubectl rollout history deployment/frontend -n microservices-demo

# Rollback to previous version if needed
kubectl rollout undo deployment/frontend -n microservices-demo

# Verify rollback
kubectl get pods -n microservices-demo
```

---

## 🛡️ Step 8: Security Configuration (Optional)

### 8.1 Apply Network Policies

Create a file `network-policy.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: microservices-demo-policy
  namespace: microservices-demo
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: microservices-demo
  policyTypes:
  - Ingress
```

Apply it:
```bash
kubectl apply -f network-policy.yaml
```

### 8.2 Configure RBAC

Create ServiceAccount and RoleBinding:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: microservices-demo-sa
  namespace: microservices-demo

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: microservices-demo-role
  namespace: microservices-demo
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: microservices-demo-rolebinding
  namespace: microservices-demo
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: microservices-demo-role
subjects:
- kind: ServiceAccount
  name: microservices-demo-sa
  namespace: microservices-demo
```

---

## 📈 Step 9: Configure Auto-Scaling (Optional)

### 9.1 Horizontal Pod Autoscaler (HPA)

Create `hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-hpa
  namespace: microservices-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

Apply it:
```bash
kubectl apply -f hpa.yaml

# Monitor HPA
kubectl get hpa -n microservices-demo -w
```

---

## 🗑️ Step 10: Cleanup

### 10.1 Delete the Application

```bash
# Delete all resources in the namespace
kubectl delete namespace microservices-demo

# Or delete specific deployments
kubectl delete deployment --all -n microservices-demo
```

### 10.2 Destroy the Cluster

From the Terraform directory:

```bash
cd infrastructure/Terraform

terraform destroy --auto-approve
```

**⚠️ Warning:** This permanently deletes the cluster and all data.

---

## 📚 Useful Commands Reference

```bash
# Get cluster info
kubectl cluster-info

# Get nodes
kubectl get nodes
kubectl describe node <node-name>

# Get deployments
kubectl get deployments -n microservices-demo
kubectl describe deployment <name> -n microservices-demo

# Get pods
kubectl get pods -n microservices-demo
kubectl describe pod <pod-name> -n microservices-demo

# Get services
kubectl get services -n microservices-demo
kubectl get endpoints <service-name> -n microservices-demo

# Logs
kubectl logs <pod-name> -n microservices-demo
kubectl logs -f <pod-name> -n microservices-demo  # Follow logs
kubectl logs --previous <pod-name> -n microservices-demo  # Previous container logs

# Resource usage
kubectl top nodes
kubectl top pods -n microservices-demo

# Execute commands
kubectl exec <pod-name> -n microservices-demo -- <command>
kubectl exec -it <pod-name> -n microservices-demo -- /bin/bash

# Port forwarding
kubectl port-forward <pod-name> 8080:80 -n microservices-demo
kubectl port-forward svc/<service-name> 8080:80 -n microservices-demo

# Check events
kubectl get events -n microservices-demo
kubectl get events -n microservices-demo --sort-by='.lastTimestamp'

# Useful GCP commands
gcloud container clusters describe microservices-demo --region us-central1
gcloud container clusters get-credentials microservices-demo --region us-central1
gcloud logging read --limit 50 --format json
```

---

## 🔗 References

- [Google Microservices Demo GitHub](https://github.com/GoogleCloudPlatform/microservices-demo)
- [GKE Deployment Guide](https://cloud.google.com/kubernetes-engine/docs/deploy-an-app)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)

---

## ❓ Troubleshooting

### Pods stuck in "Pending"

```bash
# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pod <pod-name> -n microservices-demo

# Possible causes:
# 1. Not enough CPU/memory available
# 2. Scheduler can't find suitable node
# 3. PVC not available
```

### Service doesn't have External IP

```bash
# Check service type
kubectl get service frontend -n microservices-demo

# If LoadBalancer, wait for IP assignment (can take 2-3 minutes):
kubectl get service frontend -n microservices-demo -w

# Check for GCP quota issues
gcloud compute project-info describe --project=$(gcloud config get-value project) | grep -A 5 "QUOTA"
```

### Frontend not accessible

```bash
# Try port-forward
kubectl port-forward svc/frontend 8080:80 -n microservices-demo

# Check frontend logs
kubectl logs deployment/frontend -n microservices-demo --tail=50

# Check service endpoints
kubectl get endpoints frontend -n microservices-demo
```
