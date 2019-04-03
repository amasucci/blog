+++
date = "2017-10-22T12:20:34+01:00"
title = "How to configure nginx on kubernetes 1.8.1 as ingress controller"
image = "/img/kubernetes-logo.png"
imagemin = "/img/kubernetes-logo-min.png"
description = "This short tutorial will show you how to configure an Ingress controller based on nginx"
tags = ["kubernetes", "docker", "bash", "devops", "nginx"]
categories = ["tutorials"]
type = "post"
featured = "kubernetes-logo-min.png"
featuredalt = "kubernetes-logo"
featuredpath = "img"
+++

## What is an Ingress controller

An ingress controller is component in the kubernetes cluster that manages the trafic coming into the cluster. Through ingress configurations you can define the rules to access the containers in you pod. For more info refer to the official [documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/#what-is-ingress).

### Default backend

A default backend is required so ingress can redirect all the requests not matching any rule in ingress configuration.

First of all we are going to create a namespace for our ingress controller
```bash
kubectl create namespace ingress
```

Now we can create the `default-backend-service.yaml` and `default-backend-deployment.yaml` and apply them:

```yaml
cat <<EOF > ./default-backend-deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: default-backend
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: default-backend
    spec:
      terminationGracePeriodSeconds: 60
      containers:
      - name: default-backend
        image: gcr.io/google_containers/defaultbackend:1.0
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 5
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: 10m
            memory: 20Mi
          requests:
            cpu: 10m
            memory: 20Mi
EOF
cat <<EOF > default-backend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: default-backend
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    app: default-backend
EOF 
kubectl create -f default-backend-deployment.yaml -f default-backend-service.yaml -n ingress
```

### Ingress controller

The following `nginx-ingress-controller-config-map.yaml`, `nginx-ingress-controller-roles.yaml` and 
`nginx-ingress-controller-deployment.yaml` will, define a config map for the controller, define cluster role permissions and finally define the ingress controller itself.

```yaml
cat <<EOF > ./nginx-ingress-controller-config-map.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-ingress-controller-conf
  labels:
    app: nginx-ingress-lb
data:
  enable-vts-status: 'true'
EOF
```

```yaml
cat <<EOF > ./nginx-ingress-controller-roles.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nginx-role
rules:
- apiGroups:
  - ""
  - "extensions"
  resources:
  - configmaps
  - secrets
  - endpoints
  - ingresses
  - nodes
  - pods
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - services
  verbs:
  - list
  - watch
  - get
  - update
- apiGroups:
  - "extensions"
  resources:
  - ingresses
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
- apiGroups:
  - "extensions"
  resources:
  - ingresses/status
  verbs:
  - update
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nginx-role
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: nginx-role
subjects:
- kind: ServiceAccount
  name: nginx
  namespace: ingress
EOF
```

```yaml
cat <<EOF > ./nginx-ingress-controller-deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-ingress-controller
spec:
  replicas: 1
  revisionHistoryLimit: 3
  template:
    metadata:
      labels:
        app: nginx-ingress-lb
    spec:
      terminationGracePeriodSeconds: 60
      serviceAccount: nginx
      hostNetwork: true
      containers:
        - name: nginx-ingress-controller
          image: gcr.io/google_containers/nginx-ingress-controller:0.8.3
          imagePullPolicy: Always
          readinessProbe:
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
          livenessProbe:
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            timeoutSeconds: 5
          args:
            - /nginx-ingress-controller
            - --default-backend-service=$(POD_NAMESPACE)/default-backend
            - --nginx-configmap=$(POD_NAMESPACE)/nginx-ingress-controller-conf
            - --v=2
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
            - containerPort: 80
            - containerPort: 443
            - containerPort: 18080
            - containerPort: 10254
EOF
```

Now you should have the following files:
- nginx-ingress-controller-config-map.yaml
- nginx-ingress-controller-roles.yaml
- nginx-ingress-controller-deployment.yaml

You can now load them by running the following command:

```bash
kubectl create -f nginx-ingress-controller-config-map.yaml -f nginx-ingress-controller-roles.yaml -f nginx-ingress-controller-deployment.yaml -n ingress
```

This is the third of three articles, the other two are 
- [How to install Kubernetes on Centos 7.3](../../22/how-to-install-kubernetes-1.8.1-on-centos-7.3/) 
- [Configure Kubernetes Dashboard](../../22/how-to-configure-dashboard-on-kubernetes-1.8.1/) 
