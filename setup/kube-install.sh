#!/usr/bin/env bash

if [ $(id -u) -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

if [ $# -ne 5 ]; then
    echo "usage: kube-install.sh master|worker|addons <iface> <metallb-addresses> <registry-ip> <ingress-ip>"
    exit 1
fi

set -ex

cd `dirname $0`
mkdir -p files

# get login user and home
user_name=`logname` || user_name="$USER"

# fix for: dpkg-reconfigure: unable to re-open stdin: No file or directory
export DEBIAN_FRONTEND=noninteractive

cmd=$1;shift
iface=$1;shift
metallb_addresses=$1;shift
registry_ip=$1;shift
ingress_ip=$1;shift

ipaddr=$(ip -4 -o addr show ${iface} | awk '{print $4}' | cut -d "/" -f 1)
export KUBECONFIG=`pwd`/files/admin.conf

# https://docs.docker.com/registry/insecure/
function install_registry_certs() {
    echo "$registry_ip registry.local" >> /etc/hosts
    echo "$ingress_ip ingress.local" >> /etc/hosts
    if [ -f /etc/cloud/templates/hosts.debian.tmpl ]; then
        echo "$registry_ip registry.local" >> /etc/cloud/templates/hosts.debian.tmpl
        echo "$ingress_ip ingress.local" >> /etc/cloud/templates/hosts.debian.tmpl
    fi

    if [ "$cmd" = "master" ]; then
        openssl req -x509 -new -keyout files/registry-key.pem -nodes -out files/registry-cert.pem -subj '/C=IN/ST=Karnataka/O=MGMT/CN=registry.local' -days 900000
        openssl req -x509 -new -keyout files/ingress-key.pem -nodes -out files/ingress-cert.pem -subj '/C=IN/ST=Karnataka/O=MGMT/CN=ingress.local' -days 900000
    fi

    # trust the certificate at the OS level
    cp files/registry-cert.pem /usr/local/share/ca-certificates/registry.local.crt
    cp files/ingress-cert.pem /usr/local/share/ca-certificates/ingress.local.crt
    update-ca-certificates

    # make docker daemon trust the certificate
    mkdir -p /etc/docker/certs.d/registry.local:443
    cp files/registry-cert.pem /etc/docker/certs.d/registry.local:443/ca.crt
    mkdir -p /etc/docker/certs.d/registry.local
    cp files/registry-cert.pem /etc/docker/certs.d/registry.local/ca.crt
}

# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker
function install_docker() {
    # Install packages to allow apt to use a repository over HTTPS
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2

    # Add Docker’s official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

    # Add Docker apt repository
    add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
       $(lsb_release -cs) \
       stable"

    # Install Docker CE
    apt-get update && apt-get install -y \
      containerd.io=1.2.13-1 \
      docker-ce=5:19.03.8~3-0~ubuntu-$(lsb_release -cs) \
      docker-ce-cli=5:19.03.8~3-0~ubuntu-$(lsb_release -cs)

    # Setup daemon.
    cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "5m",
    "max-file": "3"
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

# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
function install_kubeadm() {
    apt-get update && apt-get install -y apt-transport-https curl
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
    deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
    apt-get update
    version=1.18
    apt-get install -y kubelet=$(apt-cache madison kubelet | grep $version | head -1 | awk '{print $3}')
    apt-get install -y kubectl=$(apt-cache madison kubectl | grep $version | head -1 | awk '{print $3}')
    apt-get install -y kubeadm=$(apt-cache madison kubeadm | grep $version | head -1 | awk '{print $3}')
    apt-mark hold kubelet kubeadm kubectl

    if [ -f "/etc/default/kubelet" ]; then
        sed -i "s/^KUBELET_EXTRA_ARGS=/KUBELET_EXTRA_ARGS=--node-ip=$ipaddr/" /etc/default/kubelet
    else
        echo "KUBELET_EXTRA_ARGS=--node-ip=$ipaddr" > /etc/default/kubelet
    fi
}

# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#instructions
function init_cluster() {
    kubeadm init $ignore_preflight_errors --apiserver-advertise-address=$ipaddr --pod-network-cidr=10.244.0.0/16
    cp /etc/kubernetes/admin.conf files
    joinCommand=$(kubeadm token create --print-join-command)
    echo "$joinCommand $ignore_preflight_errors" > files/kubeadm-join.sh
}

function setup_kube_config() {
    user_home=`eval echo ~$user_name`
    mkdir -p $user_home/.kube
    cp files/admin.conf $user_home/.kube/config
    sudo chown -R `id -u $user_name`:`id -g $user_name` $user_home/.kube
    type _init_completion || echo 'source /usr/share/bash-completion/bash_completion' >> $user_home/.bashrc
    echo 'source <(kubectl completion bash)' >> $user_home/.bashrc
    echo "export LANG='en_US.UTF-8'" >> $user_home/.bashrc
}

# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
function install_pod_network() {
    # pass bridged IPv4 traffic to iptables’ chains
    sysctl net.bridge.bridge-nf-call-iptables=1 || true

    curl -O -s https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

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

    url=https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/nfs-client/deploy
    curl -sO $url/rbac.yaml
    sed -i'' "s/namespace:.*/namespace: nfs-provisioner/g" rbac.yaml
    kubectl create -n nfs-provisioner -f rbac.yaml
    rm rbac.yaml

    curl -sO $url/class.yaml
    sed -i'' "s/namespace:.*/namespace: nfs-provisioner/g" class.yaml
    kubectl create -n nfs-provisioner -f class.yaml
    rm class.yaml

    curl -sO $url/deployment.yaml
    sed -i'' "s/namespace:.*/namespace: nfs-provisioner/g" deployment.yaml
    master_ip=$(cat files/master-ip)
    sed -i s/10.10.10.60/$master_ip/g deployment.yaml
    sed -i s:/ifs/kubernetes:/kubedata:g deployment.yaml
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


# see https://metallb.universe.tf/configuration/#layer-2-configuration
function install_metallb() {
    kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.1/manifests/metallb.yaml

    curl -sO https://raw.githubusercontent.com/google/metallb/v0.8.1/manifests/example-layer2-config.yaml
    sed -i "s:192.168.1.240/28:$metallb_addresses:g" example-layer2-config.yaml
    kubectl apply -f example-layer2-config.yaml
    rm example-layer2-config.yaml
}

# https://docs.docker.com/registry/deploying/
function install_registry() {
    kubectl create namespace registry
    kubectl create -n registry secret tls tls-secret --cert=files/registry-cert.pem --key=files/registry-key.pem

    sed  "s/loadBalancerIP:.*/loadBalancerIP: $registry_ip/g" docker-registry.yaml > files/docker-registry.yaml
    kubectl create -n registry -f files/docker-registry.yaml
    rm files/docker-registry.yaml
}

# https://github.com/nginxinc/kubernetes-ingress/blob/master/docs/installation.md
function install_nginx_ingress() {
    # create a namespace and a service account
    kubectl apply -f https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/master/deployments/common/ns-and-sa.yaml

    # create a secret with a TLS certificate and a key for the default server
    kubectl create -n nginx-ingress secret tls default-server-secret --cert=files/ingress-cert.pem --key=files/ingress-key.pem
    # kubectl apply -f https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/master/deployments/common/default-server-secret.yaml

    # create a config map for customizing NGINX configuration
    kubectl apply -f https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/master/deployments/common/nginx-config.yaml

    # configure rbac
    kubectl apply -f https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/master/deployments/rbac/rbac.yaml

    # deploy Ingress controller using deployment resource
    kubectl apply -f https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/master/deployments/deployment/nginx-ingress.yaml

    curl -sO https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/master/deployments/service/loadbalancer.yaml
    sed -i "s/type: LoadBalancer/type: LoadBalancer\n  loadBalancerIP: $ingress_ip/g" loadbalancer.yaml
    kubectl apply -f loadbalancer.yaml
    rm loadbalancer.yaml
}

# https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/
function install_metrics_server() {
    curl -sOL https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
    sed -i "s/args:/args:\n          - --kubelet-insecure-tls\n          - --kubelet-preferred-address-types=InternalIP/" components.yaml
    kubectl create -f components.yaml
    rm components.yaml
}

if [ "$cmd" = "master" ]; then
    echo -n $ipaddr > files/master-ip
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
    install_nginx_ingress
    install_metrics_server
else
    echo "invalid command $1"
    exit 1
fi
