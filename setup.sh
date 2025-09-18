#!/usr/bin/env bash
set -euo pipefail


REQUIRED_TOOLS=(kind kubectl helm kubeseal cloud-provider-kind)
MISSING_TOOLS=()

# Check for required tools
for tool in "${REQUIRED_TOOLS[@]}"; do
	if ! command -v "$tool" &>/dev/null; then
		MISSING_TOOLS+=("$tool")
	fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
	echo -e "\033[1;31m[ERROR] The following required tools are missing:\033[0m"
	for tool in "${MISSING_TOOLS[@]}"; do
		echo "  - $tool"
	done
	echo -e "\033[1;33mPlease install the missing tools and re-run this script.\033[0m"
	exit 1
fi

# Check for required helm chart repositories
REQUIRED_HELM_REPOS=("sealed-secrets")
MISSING_HELM_REPOS=()
for repo in "${REQUIRED_HELM_REPOS[@]}"; do
	if ! helm repo list | awk '{print $1}' | grep -q "^$repo$"; then
		MISSING_HELM_REPOS+=("$repo")
	fi
done

if [ ${#MISSING_HELM_REPOS[@]} -ne 0 ]; then
	echo -e "\033[1;31m[ERROR] The following required Helm repositories are missing:\033[0m"
	for repo in "${MISSING_HELM_REPOS[@]}"; do
		if [ "$repo" = "sealed-secrets" ]; then
			echo "  - sealed-secrets (add with: helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets)"
		else
			echo "  - $repo"
		fi
	done
	echo -e "\033[1;33mPlease add the missing Helm repositories and re-run this script.\033[0m"
	exit 1
fi

echo -e "\033[1;34m[INFO][1/8] Creating kind cluster...\033[0m"
kind create cluster --name local-cluster
kubectl label node local-cluster-control-plane node.kubernetes.io/exclude-from-external-load-balancers-

echo -e "\033[1;34m[INFO][2/8] Installing Gateway API CRDs if not present...\033[0m"
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
	{ kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.0.0" | kubectl apply -f -; }

echo -e "\033[1;34m[INFO][3/8] Installing sealed-secrets...\033[0m"
helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets

echo -e "\033[1;34m[INFO][3.5/8] Waiting for sealed-secrets deployment and pods to be ready...\033[0m"
kubectl wait --for=condition=Available --timeout=120s deployment/sealed-secrets-controller -n kube-system
kubectl wait --for=condition=Ready --timeout=120s pod -l app.kubernetes.io/name=sealed-secrets -n kube-system

echo -e "\033[1;34m[INFO][4/8] Creating argocd namespace...\033[0m"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo -e "\033[1;34m[INFO][7/8] Sealing repo credentials...\033[0m"
if [ -f ./infra/argocd/repo-creds-unsafe.yaml ]; then
	kubeseal -f ./infra/argocd/repo-creds-unsafe.yaml -w ./infra/argocd/repo-creds.yaml
else
	echo -e "\033[1;33m[WARN] ./infra/argocd/repo-creds-unsafe.yaml not found. Skipping sealing.\033[0m"
fi

echo -e "\033[1;34m[INFO][8/8] Bootstrapping ArgoCD app of apps...\033[0m"

helm upgrade --install argocd ./infra/argocd/install --namespace argocd --values ./infra/argocd/install/values.yaml
kubectl apply -f infra/argocd/app-of-infras.yaml

echo -e "\033[1;34m[INFO] Running cloud-provider-kind with lb port mapping enabled...\033[0m"
cloud-provider-kind -enable-lb-port-mapping

echo -e "\033[1;32m[SUCCESS] Setup complete!\033[0m"
