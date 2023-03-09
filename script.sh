#!/bin/bash
set -e
set -x 

echo "${KUBE_CONFIG}" | base64 -d > /tmp/config
export KUBECONFIG=/tmp/config 
kubectl version
kubectl get ns

FOLDER_REPO_NAME="./build/${REPO_NAME//-/_}"
rm -rf "$FOLDER_REPO_NAME"
mkdir -p "$FOLDER_REPO_NAME"

AMBIENTE=${GITHUB_REF_NAME##*/}
AMBIENTE=${AMBIENTE,,}

if [ "$AMBIENTE" = "merge" ]; then
    AMBIENTE=${GITHUB_BASE_REF,,}
fi



SECRETS_PREFIX=${AMBIENTE^^}

if [ "$GITHUB_REF_NAME" = "dev" ] ; then
    SECRETS_PREFIX="DEV"
    MANAGEMENT_SUBDOMAIN=dev
elif [ "$GITHUB_REF_NAME" = "homolog" ] ; then
    SECRETS_PREFIX="HML"
    MANAGEMENT_SUBDOMAIN=hml
elif [ "$GITHUB_REF_NAME" == "master" ] || [ "$GITHUB_REF_NAME" == "main"  ] ; then
    SECRETS_PREFIX="PRD"
    MANAGEMENT_SUBDOMAIN=internal
    #garantir que a pasta seja sempre enviroments/main
    AMBIENTE="main"
fi  


SECRETS_PREFIX=${SECRETS_PREFIX^^}
    


echo "           REPO_NAME=$REPO_NAME"
echo "    FOLDER_REPO_NAME=$FOLDER_REPO_NAME"
echo "            AMBIENTE=$AMBIENTE"
echo "      SECRETS_PREFIX=$SECRETS_PREFIX"
echo "MANAGEMENT_SUBDOMAIN=$MANAGEMENT_SUBDOMAIN"


kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -



CONFIG_NAMES=${CONFIG_NAMES// /}  # remove all spaces from the variable
CONFIG_NAMES=${CONFIG_NAMES//\.json/}
IFS=',' read -ra ARR <<< "$CONFIG_NAMES"

for ITEM in "${ARR[@]}"
do
  echo "$ITEM"
  curl -o $FOLDER_REPO_NAME/$ITEM.json "http://management.$MANAGEMENT_SUBDOMAIN.valorpro.com.br/api/v1/$ITEM.json?application=$REPO_NAME"
done

ls -lha $FOLDER_REPO_NAME/

kubectl create configmap "$REPO_NAME-config" --from-file="$FOLDER_REPO_NAME" -dry-run=client -o yaml  -n "$NAMESPACE" | kubectl -n "$NAMESPACE" replace -f -