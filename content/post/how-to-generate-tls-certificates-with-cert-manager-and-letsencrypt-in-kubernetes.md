+++
date = "2018-03-17T15:05:10+01:00"
title = "How to generate TLS certificates with cert-manager and Let's Encrypt in Kubernetes"
image = "/img/certs.jpg"
imagemin = "/img/certs-min.jpg"
description = "Kubernetes simplifies management of containerised applications and promotes automation of all the aspects of a deployment. It can do even more if combined with third parties components that's what we are going to do today, we are going to use cert-manager and Let's Encrypt to generate TLS certificates automatically"
tags = ["kubernetes", "helm", "devops"]
categories = ["tutorials"]
+++

![How to generate certificates with cert-manager and letsencrypt in kubernetes](/img/certs.jpg)

Kubernetes simplifies management of containerised applications and promotes automation of all the aspects of a deployment. 
It can do even more if combined with third parties components that's what we are going to do today, we are going to use cert-manager and letsencrypt to generate TLS certificates automatically. 

### Requirements
This guide assumes that you are already familiar with kubernetes and that you have access to kubernetes cluster with an ingress controller, if you don't, you can have a look at the previous posts:
- [How to install Kubernetes on Centos 7.3](../../../../2017/10/22/how-to-install-kubernetes-1.8.1-on-centos-7.3/) 
- [Configure Nginx as Ingress Controller](../../../../2017/10/22/how-to-configure-nginx-on-kubernetes-1.8.1-as-ingress-controller/)

We are also going to use helm, so make sure you have it installed in your cluster.

### What's cert-manager and Let's Encrypt and how they work together
- Cert-manager is a Kubernetes add-on that automates the management and issuance of TLS certificates from various issuing sources.
- Let’s Encrypt is a free, automated, and open Certificate Authority.

![Create a personal access token](/img/cert-manager-schema.png)

Cert-manager will ensure certificates are valid and up to date periodically, and attempt to renew certificates before expiry.

### Let's get started

Copy and paste the following line in your terminal this will deploy cert-manager:
```bash
helm install --namespace kube-system --name cm stable/cert-manager --set ingressShim.extraArgs={--default-issuer-name=letsencrypt-prod,--default-issuer-kind=ClusterIssuer}
```
Note the extra args, `--default-issuer-name` specifies the name of the issuer and `--default-issuer-kind` specifies the type of issuer. You can have two types of issuers:
- `ClusterIssuer`
- `Issuer`

`ClusterIssuer` is accessible from any namespaces while `Issuer` can only be used from the namespace where it is deployed. To keep it simple we can just use the `ClusterIssuer` so we have to create a certificate issuer named `letsencrypt-prod` and of type `ClusterIssuer` to do it copy and paste this to your console:

```yaml
cat <<EOF > ./issuer.yaml
---
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v01.api.letsencrypt.org/directory
    email: me@email.com
    privateKeySecretRef:
      name: letsencrypt-prod
    http01: {}
EOF
```
Replace the email with a valid one, this will be used by Let's Encrypt to send you messages about expiry dates and certificate revocation.

Now you can run: `kubectl apply -f issuer.yaml` and voila if everything worked you should have your cluster ready to work with Let's Encrypt to automate the certificate management.

### How to test it
I guess you want to make sure it is working but probably you don't have a deployment ready, no worries the following is a quick way to test. It will deploy nginx with a service and an ingress config, as usual copy and paste in your console.

```yaml
cat <<EOF > ./depl.yaml
---
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: test-deployment
  labels:
    app: test-app
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-service
spec:
  selector:
    app: test-app
  ports:
    - name: http
      protocol: 'TCP'
      port: 80
      targetPort: 80
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test-ingress
  annotations:
    ingress.kubernetes.io/rewrite-target: /
    kubernetes.io/tls-acme: "true"
spec:
  tls:
  - hosts:
    - your.domain.com
    secretName: your-domain-com
  rules:
  - host: your.domain.com
    http:
      paths:
      - path: "/"
        backend:
          serviceName: test-service
          servicePort: http
EOF
```

Note the ingress config, the TLS section is the one monitored by cert-manager.

Replace `your.domain.com` with, ehm... your domain, and run the following command:
```bash
kubectl apply -f depl.yaml
```

Wait few seconds for the deployment to be ready and hit your domain from your favourite browser, it should now have a valid certificate.

Hope you found this post useful for feedback and questions use the comments below.
