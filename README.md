# local cluster setup

```bash
kind create cluster --name local-cluster
```


1. Add argocd

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

kubectl port-forward svc/argocd-server -n argocd 8080:443

```

Optionally create a github app, and connect repo in argocd

```bash

```

2. Add Istio

```bash 
cd infra/istio
curl -L https://istio.io/downloadIstio | sh -
export PATH="$PATH:$PWD/istio-1.26.3/bin"

# istioctl install --set profile=ambient --skip-confirmation

# helm repo add istio https://istio-release.storage.googleapis.com/charts
# check config: 
# echo "$(helm template istio-base istio/base -n istio-system)" > chart/istio-base.yaml

helm install istio-base istio/base -n istio-system --create-namespace --wait

kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml

helm install istiod istio/istiod --namespace istio-system --set profile=ambient --wait

helm install istio-cni istio/cni -n istio-system --set profile=ambient --wait

helm install ztunnel istio/ztunnel -n istio-system --wait


```

3. Add gitea


