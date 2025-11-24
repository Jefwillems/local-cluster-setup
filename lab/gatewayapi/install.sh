#/usr/bin/env bash

kind create cluster --config kind-config.yaml --name test

kubectl apply --server-side -f https://raw.githubusercontent.com/projectcontour/contour/release-1.33/examples/gateway/00-crds.yaml

kubectl apply -f gatewayclass.yaml

kubectl create ns lab

kubectl apply -f gateway.yaml

# Namespace projectcontour to run Contour
# Contour CRDs
# Contour RBAC resources
# Contour Deployment / Service
# Envoy DaemonSet / Service
# Contour ConfigMap
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml

# Configure Contour to use the Gateway in the lab namespace
kubectl apply -f - <<EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: contour
  namespace: projectcontour
data:
  contour.yaml: |
    gateway:
      gatewayRef:
        name: contour
        namespace: lab
EOF

kubectl -n projectcontour apply -f envoy-service-patch.yaml
kubectl -n projectcontour rollout restart deployment/contour

# Deploy a sample application
kubectl apply -f example-application.yaml -n lab
