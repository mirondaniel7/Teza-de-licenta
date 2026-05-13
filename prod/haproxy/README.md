helm repo add haproxy-ingress https://haproxy-ingress.github.io/charts
helm repo update

# Install with hostNetwork enabled
helm install haproxy-ingress haproxy-ingress/haproxy-ingress \
  --namespace ingress-controller --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.dnsPolicy=ClusterFirstWithHostNet \
  --set controller.kind=DaemonSet