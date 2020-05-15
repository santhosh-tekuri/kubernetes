#!/usr/bin/env bash

if [ $(id -u) -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

if [ $# -ne 1 ]; then
    echo "usage: lxd-init.sh <num-workers>"
    exit 1
fi
workers=$1
image=ubuntu:18.04

set -ex

# allow access to lxd commands to current user
user_name=$(logname)
gpasswd -a $user_name lxd

modprobe br_netfilter
lxd init --auto

# create k8s profile
lxc profile copy default k8s
#lxc profile set k8s limits.cpu 2
#lxc profile set k8s limits.memory 2GB
lxc profile set k8s limits.memory.swap false
lxc profile set k8s linux.kernel_modules bridge,br_netfilter,ip_tables,ip6_tables,netlink_diag,nf_nat,overlay
lxc profile set k8s raw.lxc $'lxc.apparmor.profile=unconfined\nlxc.cap.drop= \nlxc.cgroup.devices.allow=a\nlxc.mount.auto=proc:rw sys:rw'
lxc profile set k8s security.privileged true
lxc profile set k8s security.nesting true

# configure metallb address range
subnet=$(lxc network get lxdbr0 ipv4.address | cut -d "/" -f 1 | cut -d "." -f 1-3)

# exclude metallb address pool from dhcp pool
lxc network set lxdbr0 ipv4.dhcp.ranges ${subnet}.2-${subnet}.199

# resolve lxd container hostnames from host machine
#lxc network set lxdbr0 raw.dnsmasq $'auth-zone=lxd\ndns-loop-detect'
#echo DNS=${subnet}.1 >> /etc/systemd/resolved.conf
#echo Domains=lxd >> /etc/systemd/resolved.conf
#systemctl restart systemd-resolved

iface=eth0
metallb_addresses="${subnet}.200-${subnet}.250"
registry_ip="${subnet}.250"
ingress_ip="${subnet}.249"

lxc launch $image master --profile k8s
ipaddr=$(lxc exec master -- ip -4 -o addr show ${iface} | awk '{print $4}' | cut -d "/" -f 1)
echo $ipaddr master.lxd >> /etc/hosts
lxc config device add master vagrant disk source=/vagrant path=/vagrant
sleep 5 # wait for network ready
lxc exec master -- /vagrant/kube-install.lxd master $iface $metallb_addresses $registry_ip $ingress_ip

# setup kubectl
user_home=`eval echo ~$user_name`
mkdir -p $user_home/.kube
cp /vagrant/files/admin.conf $user_home/.kube/config
sudo chown -R `id -u $user_name`:`id -g $user_name` $user_home/.kube
echo 'source <(kubectl completion bash)' >> $user_home/.bashrc
echo "export LANG='en_US.UTF-8'" >> $user_home/.bashrc
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl


for i in $(seq $workers); do
    lxc launch $image worker$i --profile k8s
    ipaddr=$(lxc exec worker${i} -- ip -4 -o addr show ${iface} | awk '{print $4}' | cut -d "/" -f 1)
    echo $ipaddr worker${i}.lxd >> /etc/hosts
    lxc config device add worker$i vagrant disk source=/vagrant path=/vagrant
    sleep 10 # wait for network ready
    lxc exec worker$i -- /vagrant/kube-install.lxd worker $iface $metallb_addresses $registry_ip $ingress_ip
    if [ $i = $workers ]; then
        lxc exec worker$i -- /vagrant/kube-install.lxd addons $iface $metallb_addresses $registry_ip $ingress_ip
    fi
done
