#/usr/bin/env bash

kind create cluster --config kind-config.yaml --name cdyn

# This url is generated from the individual YAML files by generate-provisioner-deployment.sh. Do not
# edit this file directly but instead edit the source files and re-render.
#
# Generated from:
#       examples/contour/01-crds.yaml
#       examples/gateway/00-crds.yaml
#       examples/gateway-provisioner/00-common.yaml
#       examples/gateway-provisioner/01-roles.yaml
#       examples/gateway-provisioner/02-rolebindings.yaml
#       examples/gateway-provisioner/03-gateway-provisioner.yaml
kubectl apply -f contour-gateway-provisioner.yaml

kubectl apply -f gatewayclass.yaml
kubectl apply -f gateway.yaml

kubectl create ns lab
kubectl apply -f example-application.yaml -n lab