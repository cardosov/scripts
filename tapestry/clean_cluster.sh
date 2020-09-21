#!/usr/bin/env bash

# allow failures early in a pipeline to propagate back to
#  the shell.  this doesn't happen by default
set -o pipefail

# more great ideas from http://kvz.io/blog/2013/11/21/bash-best-practices/
# See here for in-depth study: http://www.tldp.org/LDP/abs/html/index.html
set -o errexit
set -o nounset

# Turn on trace, useful for debugging
#set -o xtrace

KUBECONFIG=
NAMESPACE="hitachi-solutions"

function show_help() {
  cat <<EOF
    Usage: ${0##*/} [-h] [-k /path/to/kubeconfig] [-n namespace]
        -h                      Display this help and exit
        -k /path/to/kubeconfig  The path to a Kubeconfig file.  By default uses $HOME/.kube/config.
        -n namespace            Specify a namespace to clean. Default is hitachi-solutions
EOF
}

#Inspired by https://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac
resolve_link() {
  local linkpath="$1"
  local orig_dir="$(pwd -P)"
  #logError "orig_dir=$orig_dir"

  cd "$(dirname "$linkpath")"
  #logError "curDir = $(pwd -P)"
  local filename=$(basename "$linkpath")
  #logError "filename = $filename"

  while [ -L "$filename" ]; do
    linkpath="$(readlink "$filename")"
    #logError "linkpath = $linkpath"
    cd "$(dirname "$linkpath")"
    #logError "curDir = $(pwd -P)"
    filename="$(basename "$linkpath")"
    #logError "filename = $filename"
  done

  local phys_dir="$(pwd -P)"
  #logError "returning $phys_dir/$filename"
  echo "$phys_dir/$filename"
  cd "$orig_dir"
}

# See http://mywiki.wooledge.org/BashFAQ/035#getopts
OPTIND=1
# : indicates that there is an argument expected
while getopts ":hk:n:" opt; do
  case "$opt" in
  '?')
    show_help >&2
    exit 1
    ;;
  h)
    show_help
    exit 0
    ;;
  k)
    KUBECONFIG=$(resolve_link "$OPTARG")
    ;;
  n)
    NAMESPACE=$OPTARG
    ;;
  esac
done
shift "$((OPTIND - 1))" # Shift off the options and optional --.

# Note: kubectl does not provide a --quiet option,
# and will print to stderr if an object to be deleted is not found
function quietKubectl() {
  local kubectlArgs
  kubectlArgs=("$@")

  if [[ "z${KUBECONFIG}" != "z" ]]; then
    kubectlArgs+=("--kubeconfig=${KUBECONFIG}")
  fi

  # 'true' makes the exit code 0
  {
    kubectl "${kubectlArgs[@]}"
  } 2>/dev/null ||
    true
}

function deleteNamespacedK8sObjects() {
  local namespace
  namespace=$1

  # In rough "dependency" order
  # i.e., services point to pods made by deployments so we delete
  # service -> deployment -> pod -> anything a pod may have used
  local k8s_namespaced_types
  k8s_namespaced_types=(
    "Service"
    "CronJobs" "DaemonSet" "Deployment" "Jobs" "ReplicaSets" "StatefulSets"
    "Pods"
    "PersistentVolumeClaims"
    "PersistentVolumes"
    "Bindings" "ConfigMaps" "Secrets" "ServiceAccounts" "Roles" "RoleBindings"
  )

  # Include CRDs
  k8s_namespaced_customResources=$(
    quietKubectl get crds -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -i \
      -e "banzaicloud" \
      -e "cert-manager" \
      -e "hitachi" \
      -e "openebs" \
      -e "keycloak" \
      -e "istio" || echo ""
  )

  # shellcheck disable=SC2206
  types_to_delete=(
    ${k8s_namespaced_types[@]}
    ${k8s_namespaced_customResources[@]}
  )

  for type in "${types_to_delete[@]}"; do
    local objects_to_delete
    objects_to_delete=$(
      quietKubectl get "${type}" \
        -o=name \
        --namespace="${namespace}"
    )

    # shellcheck disable=SC2068
    for object in ${objects_to_delete[@]}; do
      quietKubectl delete "${object}" \
        --namespace="${namespace}" \
        --force=true \
        --wait=false
      quietKubectl patch "${object}" \
        --namespace="${namespace}" \
        --patch='{"metadata":{"finalizers":[]}}' \
        --type=merge
    done
  done
}

function deleteClusteredK8sObject() {
  local typeToDelete
  typeToDelete=$1

  local resourcesToDelete
  resourcesToDelete=$(
    quietKubectl get "${typeToDelete}" -o name |
      grep -i \
        -e "banzaicloud" \
        -e "cert-manager" \
        -e "hitachi" \
        -e "openebs" \
        -e "keycloak" \
        -e "hscp-${NAMESPACE}" \
        -e "istio" || echo ""
  )

  # shellcheck disable=SC2068
  for resource in ${resourcesToDelete[@]}; do
    quietKubectl delete "${resource}" --wait=false --force=true
    quietKubectl patch "${resource}" \
      --patch='{"metadata":{"finalizers":[]}}' \
      --type=merge
  done
}

function deleteK8sSystemObjects() {
  local typeToDelete
  typeToDelete=$1

  local resourcesToDelete
  resourcesToDelete=$(
    quietKubectl get "${typeToDelete}" -o name -n kube-system |
      grep -i \
        -e "cert-manager" || echo ""
  )

  # shellcheck disable=SC2068
  for resource in ${resourcesToDelete[@]}; do
    quietKubectl delete "${resource}" --wait=false --force=true -n kube-system
    quietKubectl patch "${resource}" \
      --patch='{"metadata":{"finalizers":[]}}' \
      --type=merge \
      -n kube-system
  done

}

# In rough "dependency" order
#   Solutions
deleteNamespacedK8sObjects "${NAMESPACE}"
quietKubectl delete ns "${NAMESPACE}" --wait=false --force=true

#   Namespaces with cluster-wide components
deleteNamespacedK8sObjects openebs
quietKubectl delete ns openebs --wait=false --force=true

deleteNamespacedK8sObjects cert-manager
quietKubectl delete ns cert-manager --wait=false --force=true

deleteNamespacedK8sObjects istio-system
quietKubectl delete ns istio-system --wait=false --force=true

## Cluster-wide resources and any "left-overs"
declare -a K8S_CLUSTER_TYPES_TO_DELETE=(
  "CustomResourceDefinition"
  "ClusterRoleBinding"
  "ClusterRole"
  "MutatingWebhookConfiguration"
  "Role"
  "RoleBinding"
  "StorageClass"
  "ValidatingWebhookConfiguration"
)

for type in "${K8S_CLUSTER_TYPES_TO_DELETE[@]}"; do
  deleteClusteredK8sObject "$type"
done

# cert-manager ends up with Roles in the 'kube-system' namespace
deleteK8sSystemObjects "Role"
deleteK8sSystemObjects "RoleBinding"

exit 0
