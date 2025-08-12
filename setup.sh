#!/usr/bin/env bash
set -euo pipefail

echo "[1/8] Creating kind cluster..."
kind create cluster --name local-cluster
kubectl label node local-cluster-control-plane node.kubernetes.io/exclude-from-external-load-balancers-

echo "[2/8] Installing Gateway API CRDs if not present..."
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
	{ kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.0.0" | kubectl apply -f -; }

echo "[3/8] Installing sealed-secrets..."
helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets

echo "[4/8] Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "[5/8] Installing ArgoCD..."
kubectl apply -k ./infra/argocd/install/ -n argocd --wait=true

echo "[6/8] Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=Available --timeout=180s deployment -l app.kubernetes.io/part-of=argocd -n argocd
kubectl wait --for=condition=Ready --timeout=180s pod -l app.kubernetes.io/name -n argocd

echo "[7/8] Sealing repo credentials..."
if [ -f ./infra/argocd/repo-creds-unsafe.yaml ]; then
	kubeseal -f ./infra/argocd/repo-creds-unsafe.yaml -w ./infra/argocd/repo-creds.yaml
else
	echo "WARNING: ./infra/argocd/repo-creds-unsafe.yaml not found. Skipping sealing."
fi

echo "Creating and labeling apps-ns namespace for Istio ambient mode..."
kubectl create namespace apps-ns --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace apps-ns istio.io/dataplane-mode=ambient --overwrite

kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -

echo "[8/8] Bootstrapping ArgoCD app of apps..."
kubectl apply -f infra/argocd/repo-creds.yaml
kubectl apply -f infra/argocd/repositories.yaml
kubectl apply -f infra/argocd/apps/applications.yaml



echo "Waiting for LoadBalancer services to be assigned external IPs..."
timeout 180 bash -c 'until kubectl get svc --all-namespaces -o json | jq -e ".items[] | select(.spec.type==\"LoadBalancer\") | .status.loadBalancer.ingress[0].ip or .status.loadBalancer.ingress[0].hostname"; do echo waiting for LoadBalancer IPs...; sleep 5; done'

echo "Enabling cloud-provider-kind port mapping..."
cloud-provider-kind -enable-lb-port-mapping

echo "Setup complete!"
