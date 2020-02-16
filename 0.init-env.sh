#!/usr/bin/env bash

# change time zone
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
timedatectl set-timezone Asia/Shanghai

rm /etc/yum.repos.d/CentOS-Base.repo
cp /vagrant/yum/CentOS7-Base-163.repo /etc/yum.repos.d/
cp /vagrant/yum/kubernetes.repo /etc/yum.repos.d/
mv /etc/yum.repos.d/CentOS7-Base-163.repo /etc/yum.repos.d/CentOS-Base.repo

# using socat to port forward in helm tiller
# install kmod and ceph-common for rook
# yum -y install --downloadonly --downloaddir=/vagrant/rpm/base vim wget curl conntrack-tools net-tools telnet tcpdump bind-utils socat ntp kmod ceph-common dos2unix  ipset ipvsadm
yum localinstall -y /vagrant/rpm/base/*.rpm

# 安装cfssl
# wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
# wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
# wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
# chmod +x cfssl_linux-amd64 cfssljson_linux-amd64 cfssl-certinfo_linux-amd64
# https://kubernetes.io/zh/docs/concepts/cluster-administration/certificates/
cp /vagrant/tools/cfssl/cfssl_linux-amd64 /usr/local/sbin/cfssl
cp /vagrant/tools/cfssl/cfssljson_linux-amd64 /usr/local/sbin/cfssljson
cp /vagrant/tools/cfssl/cfssl-certinfo_linux-amd64 /usr/local/sbin/cfssl-certinfo

echo 'enable ntp to sync time'
systemctl enable --now ntpd

echo 'disable selinux'
setenforce 0
sed -i 's/=enforcing/=disabled/g' /etc/selinux/config

echo 'set host name resolution'
cat >> /etc/hosts <<EOF
172.17.8.101 kube-master
172.17.8.102 kube-node1
172.17.8.103 kube-node2
192.168.110.200 registry.sloth.com
172.20.10.2 nginx.sloth.com
EOF
cat /etc/hosts

echo "copy harbor files"
mkdir -p /etc/docker/certs.d/registry.sloth.com
cp /vagrant/harbor/registry.sloth.com/registry.sloth.com.crt /etc/docker/certs.d/registry.sloth.com/registry.sloth.com.crt

echo 'set nameserver'
echo "nameserver 8.8.8.8">/etc/resolv.conf
cat /etc/resolv.conf

echo 'disable swap'
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

echo 'enable iptable kernel parameter'
cat <<EOF >  /etc/sysctl.d/k8s.conf
vm.swappiness = 0
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
modprobe br_netfilter
echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
sysctl -p /etc/sysctl.d/k8s.conf

echo 'set ulimit'
ulimit -SHn 65535
echo "ulimit -SHn 65535" >> /etc/rc.local
cat >> /etc/security/limits.conf<< EOF
*      soft  nofile    60000
*      hard  nofile    65535
EOF
# check : `ulimit -n`

cat >> /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules
# check : `lsmod | grep -e ip_vs -e nf_conntrack_ipv4`

cat >> ~/.bash_profile<< EOF
export PATH=$PATH:/vagrant/bin
export PATH=$PATH:/vagrant/tools/prometheus/prometheus-2.3.1.linux-amd64
EOF
source ~/.bash_profile
