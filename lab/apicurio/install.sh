#/usr/bin/env bash

kubectl create ns lab

curl -sSL "https://raw.githubusercontent.com/Apicurio/apicurio-registry/refs/heads/main/operator/install/install.yaml" | \
    sed "s/PLACEHOLDER_NAMESPACE/lab/g" | \
    kubectl apply -n lab -f -

kubectl apply -n lab -f apicurio-registry.yaml
