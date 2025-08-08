# local cluster setup

```bash
kind create cluster --name local-cluster
```


1. Add argocd

```bash
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.0.0" | kubectl apply -f -; }

helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets

kubectl create namespace argocd

# curl -kLs -o infra/argocd/install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl apply -k ./infra/argocd/install/ -n argocd --wait=true

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

kubectl port-forward svc/argocd-server -n argocd 8080:443

```

Create file `infra/argocd/repo-creds-unsafe.yaml`

```bash
# apply app of apps

kubeseal -f ./infra/argocd/repo-creds-unsafe.yaml -w ./infra/argocd/repo-creds.yaml

kubectl apply -f infra/argocd/repo-creds.yaml
kubectl apply -f infra/argocd/repositories.yaml

kubectl apply -f infra/argocd/apps/applications.yaml

export INGRESS_HOST=$(kubectl get -n argocd gtw argocd-gateway -o jsonpath='{.status.addresses[0].value}')
export INGRESS_PORT=$(kubectl get -n argocd gtw argocd-gateway -o jsonpath='{.spec.listeners[?(@.name=="http")].port}')

```


