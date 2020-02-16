#!/usr/bin/env bash

source /vagrant/0.init-env.sh

cp /vagrant/yum/docker.repo /etc/yum.repos.d/

# docker 1.13.1 https://yum.dockerproject.org/repo/main/centos/7/Packages/
# yum -y install --downloadonly --downloaddir=/vagrant/rpm/docker/1.13.1 docker-engine-selinux-1.13.1 docker-engine-1.13.1
yum localinstall -y /vagrant/rpm/docker/1.13.1/*.rpm
# 编辑systemctl的Docker启动文件，docker-1806后不需要此操作
sed -i "13i ExecStartPost=/usr/sbin/iptables -P FORWARD ACCEPT" /usr/lib/systemd/system/docker.service
iptables -nvL

systemctl enable --now docker

# yum -y install --downloadonly --downloaddir=/vagrant/rpm/kubeadm/1.11.10  kubelet-1.11.10 kubeadm-1.11.10 kubectl-1.11.10 --disableexcludes=kubernetes
yum localinstall -y /vagrant/rpm/kubeadm/1.11.10/*.rpm

cat > /etc/sysconfig/kubelet <<EOF
KUBELET_EXTRA_ARGS=" --pod-infra-container-image=registry.sloth.com/google_containers/pause:3.1"
EOF
systemctl enable --now kubelet
# systemctl status kubelet -l
# journalctl -xeu kubelet
# tail -f /var/log/messages

if [[ $1 -eq 1 ]]
then
    mkdir -p /etc/kubernetes/pki

    # 生成 CA 密钥（ca-key.pem）和证书（ca.pem）
    cfssl gencert -initca /vagrant/config/kubernetes/cert/ca-csr.json | cfssljson -bare ca
    cp ca.pem /etc/kubernetes/pki/ca.crt
    cp ca-key.pem /etc/kubernetes/pki/ca.key

    # 安装etcd
    # wget https://github.com/etcd-io/etcd/releases/download/v3.2.18/etcd-v3.2.18-linux-amd64.tar.gz
    cp /vagrant/tools/etcd/etcd-v3.2.18-linux-amd64/{etcd,etcdctl} /usr/local/sbin/
    cfssl gencert -ca=/etc/kubernetes/pki/ca.crt \
      -ca-key=/etc/kubernetes/pki/ca.key \
      -config=/vagrant/config/kubernetes/cert/ca-config.json \
      -profile=kubernetes /vagrant/config/kubernetes/cert/etcd-csr.json | cfssljson -bare etcd
    cp etcd*.pem /etc/kubernetes/pki/
    useradd etcd && mkdir -p /opt/etcd && chown -R etcd:etcd /opt/etcd
    chown -R etcd:etcd /etc/kubernetes/pki/etcd-key.pem
    cp /vagrant/config/etcd/etcd.service /etc/systemd/system/etcd.service
    systemctl daemon-reload && systemctl enable etcd && systemctl start etcd

    # 启动prometheus
    # useradd prometheus && mkdir -p /opt/prometheus && chown -R prometheus:prometheus /opt/prometheus
    # cp /vagrant/config/prometheus/prometheus.service /etc/systemd/system/prometheus.service
    # systemctl daemon-reload && systemctl enable prometheus && systemctl start prometheus

    echo "configure kube-master"
    # kubeadm config images list --kubernetes-version=1.11.10
    # kubeadm config print-default --api-objects=MasterConfiguration
    # 配置 kubernetesVersion: v1.11.10
    # 配置 imageRepository: registry.sloth.com/google_containers
    # 配置 api.advertiseAddress: 172.17.8.101 bindPort: 6443
    # 配置 kubeProxy.config.mode: ipvs
    # 配置 networking.podSubnet: 10.244.0.0/16
    # 配置 外部etcd
    kubeadm init --config=/vagrant/yaml/kubeadm-init-v1.11.10.yaml

    mkdir -p /vagrant/temp/kubernetes
    rm -rf /vagrant/temp/kubernetes/worker-init.sh
cat > /vagrant/temp/kubernetes/worker-init.sh<<EOF
#!/bin/bash
`kubeadm token create --print-join-command`
EOF

    mkdir -p ~/.kube
    cp -i /etc/kubernetes/admin.conf ~/.kube/config

    rm -rf /vagrant/temp/kubernetes/admin.conf
    cp -i /etc/kubernetes/admin.conf /vagrant/temp/kubernetes/admin.conf

    # kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
    # node多网卡时，需要使用–iface参数指定集群主机内网网卡的名称，否则可能会出现dns无法解析。
    kubectl apply -f /vagrant/yaml/flannel/kube-flannel.yml

    # https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
    # kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml
    # 调整image：registry.sloth.com/
    # spec.type: NodePort
    # spec.ports.nodePort: 30001
    # spec.ports.nodePort: 30002
    kubectl apply -f /vagrant/yaml/dashboard/kubernetes-dashboard.yaml
    # 默认安装使用最小的访问权限，用户只能访问UI资源，需要创建可管理集群的ServiceAccount
    kubectl apply -f /vagrant/yaml/admin-role.yaml

    # hpa依赖
    # cp -r /Users/zhangbaohao/repository/github.com/kubernetes-sigs/metrics-server/deploy/kubernetes/ yaml/metrics-server/
    kubectl create -f /vagrant/yaml/metrics-server/
fi

if [[ $1 -eq 2 ]]
then
    echo "configure kube-node1"
    sh /vagrant/temp/kubernetes/worker-init.sh
fi

if [[ $1 -eq 3 ]]
then
    echo "configure kube-node2"
    sh /vagrant/temp/kubernetes/worker-init.sh
fi

echo "Configure Kubectl to autocomplete"
source <(kubectl completion bash) # setup autocomplete in bash into the current shell, bash-completion package should be installed first.
echo "source <(kubectl completion bash)" >> ~/.bashrc # add autocomplete permanently to your bash shell.