RemoteRegistry=registry.sloth.com

k8s_modules=("kube-apiserver:v1.15.4" "kube-controller-manager:v1.15.4" "kube-scheduler:v1.15.4" "kube-proxy:v1.15.4" "pause:3.1" "etcd:3.3.10" "coredns:1.3.1")

for module in ${k8s_modules[*]}
do
docker pull jediz90/${module}

docker tag jediz90/${module} ${RemoteRegistry}/google_containers/${module}
docker push ${RemoteRegistry}/google_containers/${module}
docker rmi ${RemoteRegistry}/google_containers/${module}
done

k8s_ui_modules=("dashboard:v2.0.0-beta8" "metrics-scraper:v1.0.1")

for module in ${k8s_ui_modules[*]}
do
docker pull kubernetesui/${module}

docker tag kubernetesui/${module} ${RemoteRegistry}/kubernetesui/${module}
docker push ${RemoteRegistry}/kubernetesui/${module}
docker rmi ${RemoteRegistry}/kubernetesui/${module}
done

docker pull jediz90/metrics-server-amd64:v0.3.6
docker tag jediz90/metrics-server-amd64:v0.3.6 ${RemoteRegistry}/google_containers/metrics-server-amd64:v0.3.6
docker push ${RemoteRegistry}/google_containers/metrics-server-amd64:v0.3.6
docker rmi ${RemoteRegistry}/google_containers/metrics-server-amd64:v0.3.6