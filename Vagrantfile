# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false
  config.vm.provider 'virtualbox' do |vb|
   vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 1000 ]
  end  
  config.vm.synced_folder ".", "/vagrant", type: "nfs", nfs_udp: false
  $etcd_cluster = "node1=http://172.17.8.101:2380"
  $master_ip = "172.17.8.101"

  config.vm.define "kube-master" do |node|
    node.vm.box = "centos/7"
    node.vm.hostname = "kube-master"
    node.vm.network "private_network", ip: $master_ip
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
      vb.name = "kube-master"
    end
    node.vm.provision "shell", path: "install.sh", args: [1, $master_ip, $etcd_cluster]
  end

  $node_instances=2
  (1..$node_instances).each do |i|
    config.vm.define "kube-node#{i}" do |node|
      node.vm.box = "centos/7"
      node.vm.hostname = "kube-node#{i}"
      ip = "172.17.8.#{i+101}"
      node.vm.network "private_network", ip: ip
      node.vm.provider "virtualbox" do |vb|
        # vb.memory = "5120"
        vb.memory = "4096"
        vb.cpus = 2
        vb.name = "kube-node#{i}"
      end
      node.vm.provision "shell", path: "install.sh", args: [i+1, ip, $etcd_cluster]
    end
  end
end

