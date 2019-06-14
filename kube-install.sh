#!/usr/bin/env bash

if [ $(id -u) -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

if [ $# -ne 6 ]; then
    echo "usage: kube-install.sh master|worker|addons <ipaddr> <iface> <master-ip> <metallb-addresses> <registry-ip>"
    exit 1
fi

set -ex

cd `dirname $0`
mkdir -p files

# get login user and home
user_name=`logname`
user_home=`eval echo ~$user_name`

# fix for: dpkg-reconfigure: unable to re-open stdin: No file or directory
export DEBIAN_FRONTEND=noninteractive

cmd=$1
ipaddr=$2
iface=$3
master_ip=$4
metallb_addresses=$5
registry_ip=$6

export KUBECONFIG=`pwd`/files/admin.conf

# https://docs.docker.com/registry/insecure/
function install_registry_certs() {
    echo "$registry_ip registry.local" >> /etc/hosts

    if [ "$cmd" = "master" ]; then
        openssl req -x509 -new -keyout files/key.pem -nodes -out files/cert.pem -subj '/C=IN/ST=Karnataka/O=MGMT/CN=registry.local' -days 900000
    fi

    # trust the certificate at the OS level
    cp files/cert.pem /usr/local/share/ca-certificates/registry.local.crt
    update-ca-certificates

    # make docker daemon trust the certificate
    mkdir -p /etc/docker/certs.d/registry.local:443
    cp files/cert.pem /etc/docker/certs.d/registry.local:443/ca.crt
    mkdir -p /etc/docker/certs.d/registry.local
    cp files/cert.pem /etc/docker/certs.d/registry.local/ca.crt
}

# https://kubernetes.io/docs/setup/cri/#docker
function install_docker() {
    # Install packages to allow apt to use a repository over HTTPS
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common

    # Add Docker’s official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

    # Add Docker apt repository
    add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
       $(lsb_release -cs) \
       stable"

    # Install Docker CE
    apt-get update && apt-get install -y docker-ce=$(apt-cache madison docker-ce | grep 18.06.2 | head -1 | awk '{print $3}')

    # Setup daemon.
    cat > /etc/docker/daemon.json <<EOF
    {
      "exec-opts": ["native.cgroupdriver=systemd"],
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "100m"
      },
      "storage-driver": "overlay2"
    }
EOF
    mkdir -p /etc/systemd/system/docker.service.d

    # Restart docker
    systemctl daemon-reload
    systemctl restart docker

    # allow docker cli for vagrant user
    usermod -a -G docker $user_name
}

# https://kubernetes.io/docs/setup/independent/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
function install_kubeadm() {
    apt-get update && apt-get install -y apt-transport-https
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
    deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
    apt-get update
    version=1.14
    apt-get install -y kubelet=$(apt-cache madison kubelet | grep $version | head -1 | awk '{print $3}')
    apt-get install -y kubectl=$(apt-cache madison kubectl | grep $version | head -1 | awk '{print $3}')
    apt-get install -y kubeadm=$(apt-cache madison kubeadm | grep $version | head -1 | awk '{print $3}')

    if [ -f "/etc/default/kubelet" ]; then
        sed -i "s/^KUBELET_EXTRA_ARGS=/KUBELET_EXTRA_ARGS=--node-ip=$ipaddr/" /etc/default/kubelet
    else
        echo "KUBELET_EXTRA_ARGS=--node-ip=$ipaddr" > /etc/default/kubelet
    fi
}

# https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#24-initializing-your-master
function init_cluster() {
    kubeadm init --apiserver-advertise-address=$ipaddr --pod-network-cidr=10.244.0.0/16
    kubeadm token create --print-join-command > files/kubeadm-join.sh
    cp /etc/kubernetes/admin.conf files
}

function setup_kube_config() {
    mkdir -p $user_home/.kube
    cp files/admin.conf $user_home/.kube/config
    sudo chown -R `id -u $user_name`:`id -g $user_name` $user_home/.kube
}

# https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#pod-network
function install_pod_network() {    
    curl -O -s https://raw.githubusercontent.com/coreos/flannel/62e44c867a2846fefb68bd5f178daf4da3095ccb/Documentation/kube-flannel.yml

    # note: we have to add --iface=enp0s8 to get flannel working in vagrant
    # see https://coreos.com/flannel/docs/latest/running.html#running-on-vagrant
    sed -i "s/- --kube-subnet-mgr/- --kube-subnet-mgr\n        - --iface=$iface/g" kube-flannel.yml
    kubectl apply -f kube-flannel.yml
    rm kube-flannel.yml

    # wait until network is ready
    arch=`kubectl get node master -o 'jsonpath={.metadata.labels.beta\.kubernetes\.io/arch}'`
    for i in {1..100}; do
      echo iteration $i...
      sleep 5
      if kubectl -n kube-system get daemonset kube-flannel-ds-${arch} -o 'jsonpath={.status.numberAvailable}' | grep 1; then
        break
      fi
    done
    kubectl -n kube-system get daemonset kube-flannel-ds-${arch} -o 'jsonpath={.status.numberAvailable}' | grep 1
}

function install_nfs_server() {
    apt-get install -y nfs-kernel-server
    mkdir /kubedata
    chmod 777 /kubedata
    echo "/kubedata *(rw,sync,no_subtree_check,no_root_squash,no_all_squash,insecure)" >> /etc/exports
    exportfs -rav    
}

function install_nfs_client() {
    apt-get install -y nfs-common
}

# https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client
function install_nfs_provisioner() {
    kubectl create namespace nfs-provisioner

    curl -sO https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/nfs-client/deploy/rbac.yaml
    sed -i'' "s/namespace:.*/namespace: nfs-provisioner/g" rbac.yaml
    kubectl create -n nfs-provisioner -f rbac.yaml
    rm rbac.yaml

    kubectl create -f https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/nfs-client/deploy/class.yaml

    curl -sO https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/nfs-client/deploy/deployment.yaml
    sed -i s/10.10.10.60/$master_ip/g deployment.yaml
    sed -i s:/ifs/kubernetes:/kubedata:g deployment.yaml
    sed -i '0,/---$/d' deployment.yaml # remove service-account duplicate defintion
    kubectl create -n nfs-provisioner -f deployment.yaml
    rm deployment.yaml

    # wait until deployment is ready
    for i in {1..100}; do
      echo iteration $i...
      sleep 5
      if kubectl get -n nfs-provisioner deployment nfs-client-provisioner -o 'jsonpath={.status.availableReplicas}' | grep 1; then
        break
      fi
    done

    # mark storage class as default
    kubectl patch storageclass managed-nfs-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
}


# see https://metallb.universe.tf/tutorial/layer2/
function install_metallb() {
    kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml

    curl -sO https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/example-layer2-config.yaml
    sed -i "s:192.168.1.240/28:$metallb_addresses:g" example-layer2-config.yaml
    kubectl apply -f example-layer2-config.yaml
    rm example-layer2-config.yaml
}

# https://docs.docker.com/registry/deploying/
function install_registry() {
    kubectl create namespace registry
    kubectl create -n registry secret tls tls-secret --cert=files/cert.pem --key=files/key.pem

    sed  "s/loadBalancerIP:.*/loadBalancerIP: $registry_ip/g" docker-registry.yaml > files/docker-registry.yaml
    kubectl create -n registry -f files/docker-registry.yaml
    rm files/docker-registry.yaml
}

if [ "$cmd" = "master" ]; then
    install_registry_certs
    install_docker
    install_kubeadm
    init_cluster
    setup_kube_config
    install_pod_network
    install_nfs_server
elif [ "$cmd" = "worker" ]; then
    install_registry_certs
    install_docker
    install_kubeadm
    /usr/bin/env bash files/kubeadm-join.sh
    setup_kube_config
    install_nfs_client
elif [ "$cmd" = "addons" ]; then
    install_nfs_provisioner
    install_metallb
    install_registry
else
    echo "invalid command $1"
    exit 1
fi
