#!/bin/bash
set -e
set -x 


function log() {
    S=$1
    echo $S | sed 's/./& /g'
}


echo "Running action valor-pro-action-get-config "

log "${KUBE_CONFIG}"


if [ ! -z "$KUBE_CONFIG" ]; then
    rm -rf /tmp/config
    echo ${KUBE_CONFIG} | base64 -d > /tmp/config
fi



echo "//////"
cat /tmp/config


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


if  [ ! -z "${VALUES}" ] ; then
    VALUES=${VALUES// /}  # remove all spaces from the variable
    VALUES=${VALUES//\.json/}
    IFS=',' read -ra ARR <<< "$VALUES"

    for ITEM in "${ARR[@]}"
    do
        echo "$ITEM"
        curl -k -o $FOLDER_REPO_NAME/$ITEM.json "https://management.$MANAGEMENT_SUBDOMAIN.valorpro.com.br/api/v1/$ITEM.json?application=$REPO_NAME"
    done
fi


if  [ ! -z "${RESOURCEINSTANCE}" ] && C[ ! -z "${RESOURCEINSTANCE_VALUES}" ] ; then
    RESOURCEINSTANCE_VALUES=${RESOURCEINSTANCE_VALUES// /}  # remove all spaces from the variable
    RESOURCEINSTANCE_VALUES=${RESOURCEINSTANCE_VALUES//\.json/}
    IFS=',' read -ra ARR <<< "$RESOURCEINSTANCE_VALUES"

    for ITEM in "${ARR[@]}"
    do
        echo "$ITEM"
        #curl -k "https://management.$MANAGEMENT_SUBDOMAIN.valorpro.com.br/api/v1/$ITEM.json?application=$REPO_NAME&resourceInstance=$RESOURCEINSTANCE"        
        curl -k -o $FOLDER_REPO_NAME/$ITEM.json "https://management.$MANAGEMENT_SUBDOMAIN.valorpro.com.br/api/v1/$ITEM.json?application=$REPO_NAME&resourceInstance=$RESOURCEINSTANCE"
    done  
fi

ls -lha $FOLDER_REPO_NAME/

#kubectl create configmap "$REPO_NAME-config" --from-file="$FOLDER_REPO_NAME" -dry-run=client -o yaml  -n "$NAMESPACE" | kubectl -n "$NAMESPACE" replace -f -
kubectl -n "$NAMESPACE" delete configmap --ignore-not-found=true "$REPO_NAME-config" 
kubectl -n "$NAMESPACE" create configmap "$REPO_NAME-config" --from-file="$FOLDER_REPO_NAME" 