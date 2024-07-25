#!/bin/bash
echo "Remove Existing Vagrant Config in .kube folder"
rm -rf  ~/.kube/vagrantconfig
echo "Copy the created Vagrant Config to .kube folder"
cp ./configs/config ~/.kube/vagrantconfig
echo "export Existing Vagrant Config in .kube folder"
export KUBECONFIG=~/.kube/vagrantconfig
echo "Display nodes"
echo "=================="
kubectl get nodes -o wide
sleep 5
echo "Setup NFS master"
echo "=================="
cat setup_nfs | vagrant ssh kmaster
echo "done"
sleep 5
echo "Setup NFS nodes"
echo "=================="
cat setup_nfs | vagrant ssh kworker1
echo "done"
sleep 5
echo "Setup NFS nodes"
echo "=================="
cat setup_nfs | vagrant ssh kworker2
sleep 5
echo "done"
echo "Create nfs provisioner"
echo "=================="
kubectl create -f setup-nfs-provisioner.yml
sleep 5
echo "Setup metallb"
echo "=================="
kubectl create ns metallb-system
kubectl apply -f metallb.yml -n metallb-system
sleep 30
kubectl apply -f metallb-config.yml -n metallb-system
sleep 5
echo "Helm add and setup nginx controller"
echo "=================="
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update
kubectl create ns ingress-nginx
helm install nginx-ingress nginx-stable/nginx-ingress --values nginx-values.yml -n ingress-nginx
sleep 30
echo "display all in ingress-nginx namespace"
echo "=================="
kubectl get all -n ingress-nginx
sleep 5
echo "=================="

#kubectl create ns monitoring

# helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
# helm repo update
# kubectl create namespace sonarqube
# helm upgrade --install -n sonarqube --version '~8' sonarqube sonarqube/sonarqube --values sonar-values.yml


# #flux setup

# flux check --pre

export GITHUB_TOKEN=github_pat_11ASIYMHgBg4nC5oYRTjOwMQdSu4oMGCBDM4DVOZu9t4V
export GITHUB_USER=sunil1252


flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=gitops \
  --branch=main \
  --path=clusters/dev \
  --personal

# Generate GitRepository Resource YAML

flux create source git gitops \
    --url=https://github.com/sunil1252/gitops \
    --branch=main \
    --interval=1m \
    --username=$GITHUB_USER \
    --token=$GITHUB_TOKEN

# Add the loki helm chart
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install grafana grafana/grafana --namespace grafana --create-namespace

helm show values grafana/loki-distributed > loki-distributed-overrides.yaml

helm upgrade --install --values loki-distributed-overrides.yaml loki grafana/loki-distributed -n grafana-loki --create-namespace

kubectl delete pods -n kube-system -l k8s-app=calico-node

helm show values grafana/promtail > promtail-overrides.yaml

helm upgrade --install --values promtail-overrides.yaml promtail grafana/promtail -n grafana-loki

kubectl port-forward service/grafana 8080:80 -n grafana

kubectl get secret grafana -n grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
