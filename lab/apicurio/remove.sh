#/usr/bin/env bash

kubectl delete -n lab -f apicurio-registry.yaml
kubectl delete ns lab
