#!/usr/bin/env bash

kind create cluster --name crossplane-test

CONTEXT="kind-crossplane-test"

helm repo add crossplane-stable https://charts.crossplane.io/stable

helm repo update

helm install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane

kubectl --context $CONTEXT get pods -n crossplane-system

kubectl --context $CONTEXT create namespace argocd

kubectl --context $CONTEXT apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl --context $CONTEXT wait --for=condition=Available deployment/argocd-server -n argocd --timeout=180s

# NOT this: kubectl --context $CONTEXT patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# just run: kubectl port-forward svc/argocd-server -n argocd 8080:443

ARGO_INITIAL_PW=$(argocd admin initial-password -n argocd | sed '1! d')

kubectl --context $CONTEXT port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &

sleep 5

argocd login localhost:8080 --insecure --username admin --password $ARGO_INITIAL_PW

ARGO_NEW_PW="superadmin"

argocd account update-password --insecure --current-password $ARGO_INITIAL_PW --new-password $ARGO_NEW_PW


echo "You can now open argocd at http://localhost:8080 and login with:
    username: admin
    password: $ARGO_NEW_PW
"

read -p "Press Enter to exit..."

# Cleanup
pkill 'kubectl'