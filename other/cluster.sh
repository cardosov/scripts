#!/usr/bin/env bash

set -eo pipefail

# check utilities availability
mustHave="minikube kubectl helm"
echo "$mustHave" | tr ' ' '\n' | while read item; do
	if ! command -v $item > /dev/null; then
		echo $item 'is not available!'
		exit 0
	fi
done

PROGNAME=$0

usage() {
 cat <<EOF
  Usage: $PROGNAME [-cn | --cluster-name ]=my-cluster [-ns | --namespace ]=my-namespace ...

  -cn  | --cluster-name	    : sets the name for the cluster. Defaults to 'jenkins-cluster'
  -ns  | --namespace        : sets the name for the namespace that holds the jenkins app. Defaults to 'jenkins-project'
  -app | --application-name : sets the name for the app to be installed. Defaults to 'jenkins'
  -vm  | --vm-memory        : sets the memory available for the virtual machine running the cluster
  -vc  | --vm-cpus          : sets the cpus available for the virtual machine running the cluster
  -vd  | --vm-disk-size     : sets the amout of disk storage available for the virtual machine running the cluster
  -h   | --help             : display this usage guide
EOF
  exit 1
}

CLUSTER_NAME=jenkins-cluster
JENKINS_NS=jenkins-project
JENKINS_APP=jenkins
VM_MEMORY=12gi
VM_CPUS=2
VM_DISK_SIZE=120g

for key in "$@" do case $key in -cn=*|--cluster-name=*) CLUSTER_NAME="${key#*=}"
shift ;; -vm=*|--vm-memory=*) VM_MEMORY="${key#*=}" shift ;; -vc=*|--vm-cpus=*)
VM_CPUS="${key#*=}" shift ;; -vd=*|--vm-disk-size=*) VM_DISK_SIZE="${key#*=}"
shift ;; -ns=*|--namespace=*) JENKINS_NS="${key#*=}" shift ;;
-app=*|--application-name=*) JENKINS_APP="${key#*=}" shift ;; -h|--help) usage
;; esac done shift "$((OPTIND - 1))"

createClusterObject() {
  SCRIPT_PATH=$1
  TEMPLATE='cat "$SCRIPT_PATH" | sed "s/{{JENKINS_NS}}/$JENKINS_NS/g"'
  eval $TEMPLATE | kubectl create -f -
}

CLUSTER_RUNNING=$(minikube status -p $CLUSTER_NAME | grep "host: Running") || echo "Cluster is down or doesn't exist"
if [ -z "$CLUSTER_RUNNING" ]; then 
  minikube start -p $CLUSTER_NAME --memory=$VM_MEMORY --cpus=$VM_CPUS --disk-size=$VM_DISK_SIZE

  TILLER_EXISTS=$(kubectl get sa --namespace=kube-system | grep tiller) || echo "Helm not configured yet"
  if [ -z "$TILLER_EXISTS" ]; then 
    #kube-system specific
    createClusterObject 'helm/tiller.yaml' #kubectl create -f helm/tiller.yaml
    createClusterObject 'kube/dns-config.yaml' #kubectl apply -f kube/dns-config.yaml

    # init helm and wait until it's available both on client and server
    helm init --wait
  fi
fi

NAMESPACE_EXISTS=$(kubectl get ns | grep $JENKINS_NS) || echo "Namespace doesn't exist. Creating..."
if [ -z "$NAMESPACE_EXISTS" ]; then 
  # create namespace
  createClusterObject 'kube/namespace.yaml'

  # create volumes
  createClusterObject 'kube/config-pv.yaml'
  createClusterObject 'kube/workspace-pv.yaml'
  #we create the volume folder manually so that it doesn't get created automatically with 'root' permissions
  minikube ssh -p $CLUSTER_NAME "sudo mkdir -p /data/$JENKINS_NS && sudo chown -R 1000:1000 /data/$JENKINS_NS"

  # create volumes claims
  createClusterObject 'kube/config-pvc.yaml'
  createClusterObject 'kube/workspace-pvc.yaml'
fi

DEPLOY_EXISTS=$(kubectl get deploy --namespace=$NAMESPACE_EXISTS | grep $JENKINS_APP) || echo "Deployment '$JENKINS_APP' doesn't exist. Creating..."
if [ -n "$DEPLOY_EXISTS" ]; then 
  echo "Deployment '$JENKINS_APP' already exists. Lauching the cluster's dashboard..."
  minikube -p $CLUSTER_NAME dashboard
  exit 3
else 
  # create master/slave configs. There seems to exist a limitation when trying to create deployments with a name that already exists in the cluster - even if in a different namespace. Helm seems to run 'helm ls --all <deployment-name>' to check its existence but ignores the namespace. Probably best workaround would be to add a suffix to the deployment name (-app|--application-name) when creating a new namespace
  helm install --name $JENKINS_APP -f helm/jenkins-values.yaml stable/jenkins --set persistence.existingClaim="$JENKINS_NS-config-pvc",persistence.storageClass="$JENKINS_NS-config-pv" --namespace $JENKINS_NS 

  echo "To launch the deployment service, just type 'minikube service -n $JENKINS_NS $JENKINS_APP -p $CLUSTER_NAME'"
  minikube dashboard -p $CLUSTER_NAME --url=false
fi