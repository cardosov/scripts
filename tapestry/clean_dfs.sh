#!/bin/sh

kubectl delete statefulset.apps/data-flow-studio-postgres-cluster -n hitachi-solutions
kubectl delete service/data-flow-studio-postgres-cluster -n hitachi-solutions
kubectl delete service/data-flow-studio-postgres-cluster-config -n hitachi-solutions
kubectl delete service/data-flow-studio-postgres-cluster-repl -n hitachi-solutions
kubectl delete pvc pgdata-data-flow-studio-postgres-cluster-0 -n hitachi-solutions
