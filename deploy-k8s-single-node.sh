#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
KUBERNETES_VERSION="1.35.0"
POD_NETWORK_CIDR="10.244.0.0/16"
SERVICE_CIDR="10.96.0.0/12"
NODE_NAME=$(hostname)
KUBECONFIG="/etc/kubernetes/admin.conf"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
fi

log_info "Starting Kubernetes single-node deployment..."

# Step 1: Update system and add required repositories
log_info "Updating system packages..."
apt-get update

# Install prerequisites for adding repositories
apt-get install -y \
  curl \
  gnupg \
  lsb-release \
  ca-certificates \
  apt-transport-https

# Step 2: Add Docker repository and install containerd
log_info "Adding Docker repository for containerd..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

log_info "Installing containerd..."
apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml > /dev/null

# Enable systemd cgroup driver
sed -i 's/^\(\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc\]\)$/\1/' /etc/containerd/config.toml
sed -i '/\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\]/a\            SystemdCgroup = true' /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd
log_info "Containerd installed and configured"

# Step 3: Install Kubernetes components
log_info "Installing Kubernetes components (kubeadm, kubelet, kubectl)..."

# Create keyring directory if it doesn't exist
mkdir -p /etc/apt/keyrings

# Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null || \
  curl -fsSL https://dl.k8s.io/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

apt-get update

apt-get install -y kubeadm=${KUBERNETES_VERSION}-* kubelet=${KUBERNETES_VERSION}-* kubectl=${KUBERNETES_VERSION}-*

# Hold these packages to prevent auto-updates
apt-mark hold kubeadm kubelet kubectl

log_info "Kubernetes components installed"

# Step 4: Configure system settings
log_info "Configuring system settings..."

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Enable IP forwarding
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system > /dev/null

log_info "System settings configured"

# Step 5: Initialize control plane
log_info "Initializing Kubernetes control plane..."
log_info "Using Pod Network CIDR: ${POD_NETWORK_CIDR}"

kubeadm init \
  --pod-network-cidr=${POD_NETWORK_CIDR} \
  --service-cidr=${SERVICE_CIDR} \
  --kubernetes-version=v${KUBERNETES_VERSION} \
  --node-name=${NODE_NAME}

log_info "Control plane initialized successfully"

# Step 6: Setup kubectl
log_info "Setting up kubectl for root user..."
mkdir -p /root/.kube
cp -i ${KUBECONFIG} /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config

export KUBECONFIG=/root/.kube/config

# Verify cluster is up
log_info "Waiting for control plane to be ready..."
sleep 10

# Step 7: Install CNI (Flannel)
log_info "Installing Flannel CNI..."
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

log_info "Waiting for Flannel to be ready..."
kubectl wait --for=condition=ready pod -l app=flannel -n kube-flannel --timeout=300s

# Step 8: Remove control plane taint
log_info "Removing control plane taint to allow pod scheduling..."
kubectl taint nodes ${NODE_NAME} node-role.kubernetes.io/control-plane:NoSchedule- || true

log_info "Removing control plane label..."
kubectl label nodes ${NODE_NAME} node-role.kubernetes.io/worker="" --overwrite || true

# Step 9: Verify deployment
log_info "Verifying Kubernetes deployment..."
log_info "Nodes:"
kubectl get nodes -o wide

log_info "Pods in kube-system namespace:"
kubectl get pods -n kube-system

# Step 10: Create kubeconfig in home directory
if [[ ! -z "${SUDO_USER:-}" ]]; then
    log_info "Creating kubeconfig for user ${SUDO_USER}..."
    mkdir -p /home/${SUDO_USER}/.kube
    cp /root/.kube/config /home/${SUDO_USER}/.kube/config
    chown ${SUDO_USER}:${SUDO_USER} /home/${SUDO_USER}/.kube/config
    chmod 600 /home/${SUDO_USER}/.kube/config
fi

echo ""
log_info "=========================================="
log_info "Kubernetes single-node deployment complete!"
log_info "=========================================="
echo ""
log_info "Your cluster is ready. To manage it:"
echo ""
echo "  export KUBECONFIG=/root/.kube/config"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo ""
log_info "The control plane node has been configured as a worker node."
log_info "You can now deploy workloads to this cluster."
echo ""
