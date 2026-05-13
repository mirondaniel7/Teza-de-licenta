helm repo add vm https://victoriametrics.github.io/helm-charts/
helm upgrade vmetrics vm/victoria-metrics-k8s-stack --values values.yaml -n monitoring --create-namespace