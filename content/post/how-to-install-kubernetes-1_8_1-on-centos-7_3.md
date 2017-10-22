+++
date = "2017-10-22T12:01:51+01:00"
title = "How to install Kubernetes 1.8.1 on centos 7.3"
image = "/img/kubernetes-logo.png"
imagemin = "/img/kubernetes-logo-min.png"
description = "This tutorial walks you through a complete kubernetes cluster setup"
tags = ["kubernetes", "docker", "bash", "devops"]
categories = ["tutorials"]
+++

![Kubernetes logo](/img/kubernetes-logo.png)

This step by step tutorial is based on the [official kubeadm tutorial](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/) and few other resources I found online. Add comments if something is not working or you have problems, I also found very useful the [k8s slack channel](http://slack.k8s.io/). This is the first of three articles, the other two are 
- [Configure Kubernetes Dashboard](../../22/how-to-configure-dashboard-on-kubernetes-1.8.1/) 
- [Configure Nginx as Ingress Controller](../../22/how-to-configure-nginx-on-kubernetes-1.8.1-as-ingress-controller/) 


### What you need:

- A box running Centos 7.3 few gigs of ram (I would suggest at least 4)
- One hour of your time.

# Preparing the machine
As `root` run the following commands to pass bridged IPv4 traffic to iptables’ chains:
```bash
yum update -y
modprobe br_netfilter
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1

cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
```
### Dependencies
Now you have to install the following dependencies:
- ebtables
- ethtools
- docker

and the following kubernetes components:
- kubelet
- kebeadm
- kubectl

before proceding with the installation let's add the required yum repository:

```bash
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
```

Now you can install them:
```bash
setenforce 0
yum install -y ebtables ethtool docker kubelet kubeadm kubectl
```

After the installation completes you have to enable and start docker and kubelet you can do it running th following commands:

```bash
systemctl enable docker && systemctl start docker
systemctl enable kubelet && systemctl start kubelet
```

### Open firewall ports
You need to open few ports on the firewall

```bash
firewall-cmd --zone=public --add-port=6443/tcp --permanent
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --zone=public --add-port=18080/tcp --permanent
firewall-cmd --zone=public --add-port=10254/tcp --permanent
firewall-cmd --reload
```

## Cluster setup
Now we can initialize the cluster using kubeadm:

```bash
kubeadm init --pod-network-cidr=10.244.0.0/16
```

now we can leave the root mode and proceed as standard user, probably you need to create one:

```bash
adduser admin
passwd admin
usermod -aG wheel admin
su - admin
```

configure kubectl

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

`Notes: If you want you can install kubectl on your machine and copy the admin.conf file locally.
I prefer to work on a local machine for various reasons such as aliases, autocompletion and history. I do that by running:` 
```bash
scp root@xx.xx.xx.xx:/etc/kubernetes/admin.conf ./
export KUBECONFIG=$PWD/admin.conf
```
## Pod/cluster network setup
Kubernetes requires a network implementation in order to work, a cluster network is used to connect containers, from the ufficial guide:
_The network must be deployed before any applications. Also, `kube-dns`, a helper service, will not start up before a network is installed. kubeadm only supports Container Network Interface (CNI) based networks (and does not support kubenet)._

In following spec defines flannel network, there are other implementations if you want to read more please check the [official docs](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#pod-network)
```yaml
cat <<EOF > ./kube-flannel.yaml
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
rules:
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes/status
    verbs:
      - patch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
- kind: ServiceAccount
  name: flannel
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flannel
  namespace: kube-system
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-flannel-cfg
  namespace: kube-system
  labels:
    tier: node
    app: flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "type": "flannel",
      "delegate": {
        "isDefaultGateway": true
      }
    }
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: kube-flannel-ds
  namespace: kube-system
  labels:
    tier: node
    app: flannel
spec:
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      hostNetwork: true
      nodeSelector:
        beta.kubernetes.io/arch: amd64
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni
        image: quay.io/coreos/flannel:v0.9.0-amd64
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conf
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: quay.io/coreos/flannel:v0.9.0-amd64
        command: [ "/opt/bin/flanneld", "--ip-masq", "--kube-subnet-mgr" ]
        securityContext:
          privileged: true
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: run
          mountPath: /run
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      volumes:
        - name: run
          hostPath:
            path: /run
        - name: cni
          hostPath:
            path: /etc/cni/net.d
        - name: flannel-cfg
          configMap:
            name: kube-flannel-cfg
EOF
kubectl apply -f kube-flannel.yaml
```

Run `kubectl get pods --all-namespaces`
check that flannel is up and running
check that dns is starting (may take few minutes).

If you are configuring a single node cluster you have to run this too:

```bash
kubectl taint nodes --all node-role.kubernetes.io/master-
```

next >> [Configure Kubernetes Dashboard](../../22/how-to-configure-dashboard-on-kubernetes-1.8.1/) 

