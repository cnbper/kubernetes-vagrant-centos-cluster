# 使用Vagrant和VirtualBox在本地搭建分布式的Kubernetes集群和Istio Service Mesh

## 使用说明

将该repo克隆到本地，下载Kubernetes的到项目的根目录。

使用vagrant启动集群

```shell
vagrant up
```

### 访问kubernetes集群

访问Kubernetes集群的方式有三种：

- 本地访问
- 在VM内部访问
- Kubernetes dashboard

**通过本地访问**

```shell
rm -rf ~/.kube && mkdir -p ~/.kube
cp temp/kubernetes/admin.conf ~/.kube/config
kubectl get nodes
```

**在VM内部访问**

```shell
vagrant ssh kube-master
sudo -i
kubectl get nodes
```

### 测试集群的各个组件

**首先验证kube-apiserver, kube-controller-manager, kube-scheduler, pod network 是否正常：**

```shell
# 部署一个 Nginx Deployment，包含2个Pod
kubectl create deployment nginx --image=registry.sloth.com/third/nginx:1.15.9
kubectl scale deployment nginx --replicas=2
## 验证Nginx Pod是否正确运行，并且会分配10.244.开头的集群IP
kubectl get pods -l app=nginx -o wide

# 再验证一下kube-proxy是否正常：
## 以 NodePort 方式对外提供服务
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get services nginx
## 可以通过任意 NodeIP:Port 在集群外部访问这个服务：
## 注意调整端口
curl 172.17.8.101:30698

# 最后验证一下dns, pod network是否正常：
## 运行Busybox并进入交互模式
kubectl run -it curl --image=registry.sloth.com/radial/busyboxplus:curl

## 输入nslookup nginx查看是否可以正确解析出集群内的IP，以验证DNS是否正常
$ nslookup nginx
## 通过服务名进行访问，验证kube-proxy是否正常
$ curl http://nginx/
```