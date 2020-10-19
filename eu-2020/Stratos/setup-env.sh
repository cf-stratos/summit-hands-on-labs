#!/usr/bin/env bash

set -eo pipefail

CYAN="\033[96m"
YELLOW="\033[93m"
GREEN="\033[92m"
RED="\033[91m"
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

function cecho() {
  echo -e "$1$2${RESET}"
}

function install_tools() {
  cecho ${CYAN} "Installing Helm..."
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh

  echo "Verifying correct installation of required tools..."
  kubectl version --client=true
  helm version
  echo
}

function cluster_zone() {
  if [[ $((SEAT)) -le 50 ]]; then
    echo "europe-west3-a"
  else
    echo "europe-west3-b"
  fi
}

function target_cluster() {
  cecho ${CYAN} "Targeting cluster ${KUBE_NAME}..."
  gcloud container clusters get-credentials "${KUBE_NAME}" --zone "$(cluster_zone)" --project summit-labs
  res=$?
  if [ $res != 0 ]; then
    cecho ${RED} "Failed to execute gcloud get-credentials"
    exit 0 #Return zero such that source does not fail
  fi
  echo
}

function create_kube_token() {
  cecho ${CYAN} "Creating Kube Service Access Token..."

  local NS="kube-system"

  kubectl apply -n $NS -f service-account.yaml
  local SERVICE_USER=stratos

  # Service account should be created - now need to get token
  local SECRET=$(kubectl get -n $NS sa $SERVICE_USER -o json | jq -r '.secrets[0].name')
  KUBE_TOKEN=$(kubectl get -n $NS secret $SECRET -o json | jq -r '.data.token')
  KUBE_TOKEN=$(echo $KUBE_TOKEN | base64 -d -)
  echo
}

function print_details() {
# KUBE_URL=$(kubectl cluster-info | grep "Kubernetes master" | cut -c 44-)
  cecho ${CYAN} "Stratos Details"
  cecho ${GREEN} "Your Stratos namespace is '${STRATOS_NAMESPACE}'"
  cecho ${GREEN} "Your Stratos URL will be '${STRATOS_URL}'"
  echo
  cecho ${CYAN} "Kube Cluster Details"
  cecho ${GREEN} "Your Kube Cluster URL is '${KUBE_URL}'"
  cecho ${GREEN} "Your Kube Cluster Token is"
  echo ${KUBE_TOKEN}
  echo
}

function create_source_file() {
  cecho ${CYAN} "Creating env file"
  echo "SEAT=${SEAT}" >> ${ENV_FILE}
  echo "KUBE_NAME=${KUBE_NAME}" >> ${ENV_FILE}
  echo "KUBE_URL=${KUBE_URL}" >> ${ENV_FILE}
  echo "KUBE_TOKEN=${KUBE_TOKEN}" >> ${ENV_FILE}
  echo "STRATOS_NAMESPACE=${STRATOS_NAMESPACE}" >> ${ENV_FILE}
  echo "STRATOS_URL=${STRATOS_URL}" >> ${ENV_FILE}

  cecho ${GREEN} "Run \`source ${ENV_FILE}\` to apply"
  echo
}

function update_readme() {
  cecho ${CYAN} "Update and starting TUTORIAL"

  README_FILE=TUTORIAL.md
  README_TEMP_FILE=TUTORIAL.md.temp
  README_ORIG=TUTORIAL.md.orig

  WALKTHROUGH_CONST_URL="!!stratos_url!!"
  WALKTHROUGH_CONST_SEAT="!!seat_number!!"
  cp ${README_FILE} ${README_ORIG}

  touch ${README_TEMP_FILE}
  sed -e "s@$WALKTHROUGH_CONST_URL@$STRATOS_URL@" -e "s@$WALKTHROUGH_CONST_SEAT@$SEAT@" ${README_FILE} > ${README_TEMP_FILE}
  cp ${README_TEMP_FILE} ${README_FILE}
  rm ${README_TEMP_FILE}
  cloudshell launch-tutorial ${README_FILE}
  echo
}

function main() {
  if [ -z "$1" ] ; then
    SEAT="$(echo "${USER}" | tr -d "a-z_")"
  else
    SEAT=$1
  fi

  ENV_FILE="user-env"

  KUBE_NAME="stratos-${SEAT}"
  KUBE_URL="https://cluster-${SEAT}.lab.stratos.app"

  STRATOS_NAMESPACE=stratos-namespace
  STRATOS_URL="https://xyz:30891"

  PATH="${HOME}/bin:${HOME}/.local/bin:${PATH}"

  cecho ${CYAN} "Setting up for user '${USER}' at seat '${SEAT}' and cluster name '${KUBE_NAME}'"
  echo

  # install_tools
  target_cluster
  create_kube_token
  print_details
  create_source_file
  update_readme

  cecho ${CYAN} "Set up complete"
}

main $1
