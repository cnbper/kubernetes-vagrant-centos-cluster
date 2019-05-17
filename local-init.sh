rm -rf ~/.kube && mkdir -p ~/.kube
cp temp/kubernetes/admin.conf ~/.kube/config
kubectl get nodes