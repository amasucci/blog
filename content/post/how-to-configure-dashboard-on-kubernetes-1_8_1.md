+++
date = "2017-10-22T12:01:51+01:00"
title = "How to configure dashboard on kubernetes 1.8.1"
image = "/img/kubernetes-logo.png"
imagemin = "/img/kubernetes-logo-min.png"
description = "Step by step notes for kubernetes dashboard setup"
tags = ["kubernetes", "docker", "bash", "devops"]
categories = ["tutorials"]
+++

## Dashboard
This is the second of three articles, the other two are 
- [How to install Kubernetes 1.8.1 on centos 7.3](../../22/how-to-install-kubernetes-1.8.1-on-centos-7.3/) 
- [Configure Nginx as Ingress Controller](../../22/how-to-configure-nginx-on-kubernetes-1.8.1-as-ingress-controller/) 
Kubernetes offers a [dashboard](https://github.com/kubernetes/dashboard) where you can visualise the status of you cluster, as you can see from the picture below you have a global view of everything running on the cluster.


![Kubernetes dashboard](/img/dashboard-ui.png)

The following configuration, is not the most secure, this is for simplicity and you can always disable it by simply running `kubectl delete -f dashboard.yaml`.

### Configuring dashboard
```bash
#Start heapster for dashboard:
git clone https://github.com/kubernetes/heapster.git
cd heapster
kubectl create -f deploy/kube-config/influxdb/
kubectl create -f deploy/kube-config/rbac/heapster-rbac.yaml
```

```yaml
cat <<EOF > ./dashboard.yaml
# ------------------- Dashboard Service Account ------------------- #

apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system

---
# ------------------- Dashboard Role & Role Binding ------------------- #

kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubernetes-dashboard-minimal
  namespace: kube-system
rules:
  # Allow Dashboard to create and watch for changes of 'kubernetes-dashboard-key-holder' secret.
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  # Allow Dashboard to get, update and delete 'kubernetes-dashboard-key-holder' secret.
  resourceNames: ["kubernetes-dashboard-key-holder"]
  verbs: ["get", "update", "delete"]
  # Allow Dashboard to get metrics from heapster.
- apiGroups: [""]
  resources: ["services"]
  resourceNames: ["heapster"]
  verbs: ["proxy"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kubernetes-dashboard-minimal
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kubernetes-dashboard-minimal
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
---
# ------------------- Dashboard Deployment ------------------- #

kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
    spec:
      containers:
      - name: kubernetes-dashboard
        image: gcr.io/google_containers/kubernetes-dashboard-amd64:v1.7.1
        ports:
        - containerPort: 9090
          protocol: TCP
        args:
          # Uncomment the following line to manually specify Kubernetes API server Host
          # If not specified, Dashboard will attempt to auto discover the API server and connect
          # to it. Uncomment only if the default does not work.
          # - --apiserver-host=http://my-address:port
        volumeMounts:
          # Create on-disk volume to store exec logs
        - mountPath: /tmp
          name: tmp-volume
        livenessProbe:
          httpGet:
            path: /
            port: 9090
          initialDelaySeconds: 30
          timeoutSeconds: 30
      volumes:
      - name: tmp-volume
        emptyDir: {}
      serviceAccountName: kubernetes-dashboard
      # Comment the following tolerations if Dashboard must not be deployed on master
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule

---
# ------------------- Dashboard Service ------------------- #

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  ports:
  - port: 80
    targetPort: 9090
  selector:
    k8s-app: kubernetes-dashboard
EOF
kubectl create -f ./dashboard.yaml
```

You can access the dashboard by running from your local machine
```bash
kubectl proxy
```
Now you should be able to see in your browser here http://localhost:8001/ui

next >> [Configure Nginx as Ingress Controller](../../22/how-to-configure-nginx-on-kubernetes-1.8.1-as-ingress-controller/)