# this vagrant files setups kubernetes 1.14 cluster

# in addition to master, how many worker nodes needed in cluster
workers=1

# the master will have ip <subnet>.10
# worker nodes will have ip <subnet>.11, <subnet>.12, ...
# ip range <subnet>.200 to <subnet>.250 is reserved for metallb
subnet="172.28.128"
master_ip="#{subnet}.10"
iface="enp0s8"
metallb_addresses="#{subnet}.200-#{subnet}.250"
registry_ip="#{subnet}.250"
worker_ip = lambda { |i| "#{subnet}.#{i+10}" }

Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.cpus = 2
  end  
  config.vm.box = "ubuntu/bionic64"

  config.vm.define "master", primary: true do |master|
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: master_ip
    master.vm.provision "shell" do |s|
      s.inline = "/usr/bin/env bash /vagrant/kube-install.sh $*"
      s.args = ["master", master_ip, iface, master_ip, metallb_addresses, registry_ip]
    end
  end

  (1..workers).each do |i|
    config.vm.define "worker#{i}" do |node|
      node.vm.hostname = "worker#{i}"
      node.vm.network "private_network", ip: worker_ip.(i)
      node.vm.provision "shell" do |s|
        s.inline = "/usr/bin/env bash /vagrant/kube-install.sh $*"
        s.args = ["worker", worker_ip.(i), iface, master_ip, metallb_addresses, registry_ip]
      end
      if i == workers
        node.vm.provision "shell" do |s|
          s.inline = "/usr/bin/env bash /vagrant/kube-install.sh $*"
          s.args = ["addons", worker_ip.(i), iface, master_ip, metallb_addresses, registry_ip]
        end
      end
    end
  end
end
