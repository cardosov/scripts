#!/bin/sh

kubectl delete statefulset.apps/data-flow-studio-postgres-cluster -n hitachi-solutions
kubectl delete service/data-flow-studio-postgres-cluster -n hitachi-solutions
kubectl delete service/data-flow-studio-postgres-cluster-config -n hitachi-solutions
kubectl delete service/data-flow-studio-postgres-cluster-repl -n hitachi-solutions
kubectl delete pvc pgdata-data-flow-studio-postgres-cluster-0 -n hitachi-solutions

# kubectl delete $(kubectl get clusterrole -o name | grep data-flow)
# kubectl delete $(kubectl get clusterrolebinding -o name | grep data-flow)
# kubectl delete clusterrole postgres-pod
# kubectl delete clusterrole pdi-execution-manager-persistentvolumes
# kubectl delete clusterrolebinding pdi-execution-manager-persistentvolumes
