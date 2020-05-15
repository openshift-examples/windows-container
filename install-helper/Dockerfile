FROM fedora:31

RUN yum install -y ansible python3-winrm && \
    curl -L -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.4.4/openshift-client-linux.tar.gz &&\
    curl -L -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.4.4/openshift-install-linux.tar.gz &&\
    tar -xzvf openshift-client-linux.tar.gz -C /usr/local/bin/ kubectl oc &&\
    tar -xzvf openshift-install-linux.tar.gz -C /usr/local/bin/ openshift-install &&\
    rm -v  openshift-client-linux.tar.gz openshift-install-linux.tar.gz 


