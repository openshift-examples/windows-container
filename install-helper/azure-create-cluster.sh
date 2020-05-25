#!/usr/bin/env bash

set -e
set -f pipeline
# set -x 


# export WORKING_DIR="/work/" 
# export CLUSTER_CONFIG="${WORKING_DIR}cluster"
# export AWS_SSH_KEY_NAME="windows-ssh-key"

echo "Run installer..."

if [ -d $CLUSTER_CONFIG ] ; then
  mv -v $CLUSTER_CONFIG ${CLUSTER_CONFIG}.$( date +%s )
fi

mkdir -v $CLUSTER_CONFIG

if [ -f ${WORKING_DIR}/install-config.yaml ] ; then
  cp -v ${WORKING_DIR}/install-config.yaml ${CLUSTER_CONFIG}/
else
  openshift-install create install-config --dir ${CLUSTER_CONFIG}
  sed -i 's/OpenShiftSDN/OVNKubernetes/g' ${CLUSTER_CONFIG}/install-config.yaml
fi

# openshift-install create install-config --dir ${CLUSTER_CONFIG}
openshift-install create manifests --dir ${CLUSTER_CONFIG}

echo "6d1bf1d5dad7e0f4a12a24854f73bd5a  ${CLUSTER_CONFIG}/manifests/cluster-network-02-config.yml" | md5sum --check
if [ $? -ne 0 ] ; then
  echo "Failed to patch cluster-network-02-config.yml - please check"
  exit 1;
fi;

cat - > ${CLUSTER_CONFIG}/manifests/cluster-network-03-config.yml <<EOF
apiVersion: operator.openshift.io/v1
kind: Network
metadata:
  creationTimestamp: null
  name: cluster
spec:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  externalIP:
    policy: {}
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
  defaultNetwork:
    type: OVNKubernetes
    ovnKubernetesConfig:
      hybridOverlayConfig:
        hybridClusterNetwork:
        - cidr: 10.132.0.0/14
          hostPrefix: 23
status: {}
EOF

echo "Update cloud provider config"

NEW_RATE_LIMIT='
{
  "cloudProviderRateLimit": false,
  "cloudProviderRateLimitQPS": 0,
  "cloudProviderRateLimitBucket": 0,
  "cloudProviderRateLimitQPSWrite": 0,
  "cloudProviderRateLimitBucketWrite": 0
}
' 

NEW_CONFIG=$(jq -s '.[0] * .[1]' <(yq read ${CLUSTER_CONFIG}/manifests/cloud-provider-config.yaml 'data.config' ) <( echo "$NEW_RATE_LIMIT" ))
yq write --inplace ${CLUSTER_CONFIG}/manifests/cloud-provider-config.yaml 'data.config' "$NEW_CONFIG" 

echo "Create cluster..."
openshift-install create cluster --dir ${CLUSTER_CONFIG}

mkdir -v ${CLUSTER_CONFIG}/windows-node-installer/

# Not all timezones supported: https://github.com/openshift/windows-machine-config-bootstrapper/blob/master/tools/windows-node-installer/pkg/cloudprovider/azure/vm.go#L675-L685
# Use own wni build based on : https://github.com/openshift-examples/windows-machine-config-bootstrapper
wni-az-with-westeurope azure create \
  --kubeconfig  ${CLUSTER_CONFIG}/auth/kubeconfig \
  --credentials ~/.azure/osServicePrincipal.json \
  --image-id MicrosoftWindowsServer:WindowsServer:2019-Datacenter-with-Containers:latest \
  --instance-type Standard_D2s_v3 \
  --dir ${CLUSTER_CONFIG}/windows-node-installer/ \
  2>&1| tee ${CLUSTER_CONFIG}/windows-node-installer/output

IP=$(grep 'External IP' ${CLUSTER_CONFIG}/windows-node-installer/output | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
PRIVATE_IP=$( grep 'Internal IP' ${CLUSTER_CONFIG}/windows-node-installer/output | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" )

NODENAME=$( grep -oE 'Please check file [^ ]+ in directory' ${CLUSTER_CONFIG}/windows-node-installer/output | sed -e "s/.*Please check file \(.*\) in directory.*/\1/" )
PASSWORT=$( cat ${CLUSTER_CONFIG}/windows-node-installer/${NODENAME} | grep '/p:' | sed -e 's/.*p:\(.*\)/\1/' | tr -d "'" )

CLUSTER_ADDRESS=$( jq -r '.cluster_domain' ${CLUSTER_CONFIG}/terraform.tfvars.json )

echo -e "
[win]
$IP ansible_password='$PASSWORT' private_ip='$PRIVATE_IP'

[win:vars]
ansible_user=core
cluster_address=$CLUSTER_ADDRESS
ansible_connection=winrm
ansible_ssh_port=5986
ansible_winrm_server_cert_validation=ignore
" > ${CLUSTER_CONFIG}/inventory.ini

ansible win -i ${CLUSTER_CONFIG}/inventory.ini -m win_ping

export KUBECONFIG=${CLUSTER_CONFIG}/auth/kubeconfig
ansible-playbook -i ${CLUSTER_CONFIG}/inventory.ini /windows-machine-config-bootstrapper/tools/ansible/tasks/wsu/main.yaml -v

