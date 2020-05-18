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

echo "Create cluster..."
openshift-install create cluster --dir ${CLUSTER_CONFIG}

mkdir -v ${CLUSTER_CONFIG}/windows-node-installer/

# ToDo ssh -key
wni aws create \
  --kubeconfig ${CLUSTER_CONFIG}/auth/kubeconfig \
  --credentials ~/.aws/credentials \
  --credential-account default \
  --instance-type m5a.large \
  --ssh-key ${AWS_SSH_KEY_NAME} \
  --private-key ${WORKING_DIR}/${AWS_SSH_KEY_NAME}.pem \
  --dir ${CLUSTER_CONFIG}/windows-node-installer/ \
  2>&1| tee ${CLUSTER_CONFIG}/windows-node-installer/output

grep -q 'Successfully created' ${CLUSTER_CONFIG}/windows-node-installer/output 
if [ $? -ne 0 ] ; then
  echo "Failed to create windows instance"
  exit 1;
fi;

IP=$(grep 'Successfully created' ${CLUSTER_CONFIG}/windows-node-installer/output | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
PASSWORT=$(grep 'Successfully created' ${CLUSTER_CONFIG}/windows-node-installer/output | sed -e "s/.*as user and \(.*\) password.*/\1/")
CLUSTER_ADDRESS=$( jq -r '.cluster_domain' ${CLUSTER_CONFIG}/terraform.tfvars.json )
INSTANCE_ID=$(grep 'Successfully created' ${CLUSTER_CONFIG}/windows-node-installer/output | grep -oE "\bi-[0-9a-z]+\b")
PRIVATE_IP=$(aws ec2  describe-instances --filters Name=instance-id,Values=$INSTANCE_ID --output json  | jq  -r ".Reservations[0].Instances[0].NetworkInterfaces[0].PrivateIpAddress" )

echo -e "
[win]
$IP ansible_password='$PASSWORT' private_ip='$PRIVATE_IP'

[win:vars]
ansible_user=Administrator
cluster_address=$CLUSTER_ADDRESS
ansible_connection=winrm
ansible_ssh_port=5986
ansible_winrm_server_cert_validation=ignore
" > ${CLUSTER_CONFIG}/inventory.ini

ansible win -i ${CLUSTER_CONFIG}/inventory.ini -m win_ping

export KUBECONFIG=${CLUSTER_CONFIG}/auth/kubeconfig
ansible-playbook -i ${CLUSTER_CONFIG}/inventory.ini /windows-machine-config-bootstrapper/tools/ansible/tasks/wsu/main.yaml -v

