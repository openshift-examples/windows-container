FROM fedora:31

RUN yum install -y ansible python3-winrm jq && \
    curl -L -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.4.4/openshift-client-linux.tar.gz &&\
    curl -L -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.4.4/openshift-install-linux.tar.gz &&\
    tar -xzvf openshift-client-linux.tar.gz -C /usr/local/bin/ kubectl oc &&\
    tar -xzvf openshift-install-linux.tar.gz -C /usr/local/bin/ openshift-install &&\
    rm -v  openshift-client-linux.tar.gz openshift-install-linux.tar.gz 


RUN yum install -y unzip && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip -qo awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip ./aws/

RUN curl -L -O https://github.com/openshift/windows-machine-config-bootstrapper/releases/download/v4.4.2-alpha/wni && \
    chmod +x wni &&\
    mv -v wni /usr/local/bin/

RUN yum install -y git && \
    git clone https://github.com/openshift/windows-machine-config-bootstrapper.git /windows-machine-config-bootstrapper && \
    cd /windows-machine-config-bootstrapper && \
    git fetch && git checkout release-4.4

ADD aws-create-cluster.sh /usr/local/bin/

ENV WORKING_DIR="/work/" 
ENV CLUSTER_CONFIG="/work/cluster"
ENV AWS_SSH_KEY_NAME="windows-ssh-key"