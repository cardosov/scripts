#!/bin/sh

#kubectl config use-context my-old-cluster
kubectl get crd loggingsolutions.logging.hitachivantara.com -o yaml  > old-version-of-loggingsolutions.yaml
kubectl apply -f old-version-of-loggingsolutions.yaml 
kubectl get crd loggingsolutions.logging.hitachivantara.com
kubectl get  loggingsolutions.logging.hitachivantara.com --all-namespaces ## here we find out that the name of stale CR is solution-control-plane-ls
kubectl patch  loggingsolutions.logging.hitachivantara.com/solution-control-plane-ls -n hitachi-solutions  -p '{"metadata":{"finalizers":[]}}' --type=merge
kubectl delete loggingsolutions.logging.hitachivantara.com/solution-control-plane-ls -n hitachi-solutions
kubectl delete  crd loggingsolutions.logging.hitachivantara.com