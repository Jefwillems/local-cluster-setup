# local cluster setup

```bash
kind create cluster --name local-cluster
kubectl label node local-cluster-control-plane node.kubernetes.io/exclude-from-external-load-balancers-
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
```

Create file `infra/argocd/repo-creds-unsafe.yaml`

```bash
# apply app of apps

kubeseal -f ./infra/argocd/repo-creds-unsafe.yaml -w ./infra/argocd/repo-creds.yaml

# bootstrap argocd app of apps
kubectl apply -f infra/argocd/repo-creds.yaml
kubectl apply -f infra/argocd/repositories.yaml
kubectl apply -f infra/argocd/apps/applications.yaml

kubectl label namespace default istio.io/dataplane-mode=ambient
# expose all LoadBalancer objects in the cluster. navigate to them by checking exposed docker ports mapped to port 80
cloud-provider-kind -enable-lb-port-mapping
```

wait until loadbalancer proxy containers are running in docker/podman

```bash
# generate some traffic

for i in $(seq 1 100); do curl -sSI -o /dev/null http://localhost:<port for productpage loadbalancer>/productpage; done

```

Open the kiali dashboard and enjoy
