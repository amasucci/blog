+++
date = "2019-04-10T10:06:46+01:00"
title = "Helm alternative: versioned configuration and deployments in kubernetes"
image = "/img/2019/04/10/kubernetes-logo.png"
imagemin = "/img/kubernetes-logo-min.png"
description = "How to use Spring Cloud Config features to version deployments' configurations"
tags = ["kubernetes", "docker", "spring", "devops"]
categories = ["tutorials"]
type = "post"
featured = "kubernetes-logo-min.png"
featuredalt = "kubernetes-logo"
featuredpath = "img/2019/04/10"
+++

How are you deploying your pods to **Kubernetes**? You are about to say <a href="https://helm.io" target="_blank">**helm**</a>, aren't you? You ended up on this page probably because you are looking for an alternative to helm. Stop googling and start reading, here I am going to explain what works for me. A while ago I was looking for a tool with the following features:

- Versioned deployments
- Centralised configuration
- With a template engine
- Able to manage secrets
- Easy to run from the command line
- Multi environment *[ dev | staging | prod ]*
- Able to keep track of changes and deployment history


but I couldn't find anything. So, I decided to put something together using <a href="https://spring.io/projects/spring-cloud-config" target="_blank">***Spring Cloud Config***</a>.

Wait Wait Wait... Be patient...

When colleagues ask me how we deploy to Kubernetes I say: 

> **"I do *Kubernetes* deployments using *Spring Cloud Config*"**

and their first reaction generally is:

>***"Oh no, I don't use Spring..."*** or ***"Oh no no, my services are written in Go not Java"***

**THIS IS NOT ABOUT JAVA**, this solution *works* for any type of deployments, among other things that are Spring/Java specific, *Spring Cloud Config* offers:

- a template engine over a REST Api
- a way to version configuration (based on **Git**)
- multi environment
- encryption and decryption of secrets

this combined with the ability of ***kubectl*** to work directly with urls makes deployments as easy as:

```bash
> kubectl apply -f http://config-server/${service-name}/${environment}/${version}/k8s/${template-name}.yaml
```

As you can see, the only values needed, are the ones required to populate the following variables:

- `${service-name}` -> The name of the service you want to deploy
- `${environment}` -> The environment where you want to deploy
- `${version}` -> The version of your service
- `${template-name}` -> The name of the template you want to use

This will tell **config service** to point to the right version (branch/tag) in Git containing the value used to populate the template (store in Git too).

Sold??? Let's do it then.

## Getting Started

Now I am going to describe how to use **Spring Cloud Config** in a Kubernetes Cluster to orchestrate deployments and keep *secrets* secret. Spring cloud config uses Git as default backed and this means that the history of every single config change and deployment will be stored (and consequently versioned) in Git.

### Before you start
Familiarity with CD concepts will be usefull to understand the reasoning behind this solution. Other things you need are 30 / 60 minutes of your time and a Kubernetes *"cluster"* (minikube, k3s, microk8s, eks, aks, gke, etc...). </br>
Additional requirements:
- Java runtime enviroment
- Code editor
- Docker

### What's Spring Cloud Config
The <a href="https://spring.io/projects/spring-cloud-config" target="_blank">official web site</a> describes it this way:

> *"Spring Cloud Config provides server and client-side support for externalized configuration in a distributed system. With the Config Server you have a central place to manage external properties for applications across all environments."*

### The Service
Ready to get your hands dirty? Cool, go to <a href="https://start.spring.io/" target="_blank">Spring Initializr</a> to define you project metadata and add your dependencies, in this case the only dependency required is **Config Server** *[Cloud Config]*, the end result should look like this:

![alt text](/img/2019/04/10/start_spring_io.png "Start spring https://start.spring.io/")

now you can click on *Generate Project*. 
A zip file will be generated, unzip it and open it with your preferred IDE. Now we need to enable the config server, guess how we can do that in spring? Yesss, with annotations 😁, annotate the main class with `@EnableConfigServer` you should have something like this:

```java
package com.amasucci.config;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.config.server.EnableConfigServer;

@EnableConfigServer
@SpringBootApplication
public class ConfigServiceApplication {
	public static void main(String[] args) {
		SpringApplication.run(ConfigServiceApplication.class, args);
	}
}
```

If you try to run this it will fail to start because we haven't configured the service yet. Let's do it then.

### Configure Config Server

Spring Cloud Config Server is a spring boot application and as a spring boot application can be configured using a property file (or a yaml file) under resources. 

```yaml
spring:
  cloud:
    config:
      server:
        git:
          uri: git@github.com:amasucci/configurations-examples.git
          clone-on-start: true
          basedir: ~/configs

logging:
  level:
    org:
      springframework:
        cloud: INFO
```

The configuration is very flexible and I recommend to have a look at the <a href="https://cloud.spring.io/spring-cloud-config/multi/multi__spring_cloud_config_server.html" target="_blank">docs</a>.

As you can see, I am pointing it to <a href="https://github.com/amasucci/configurations-examples" target="_blank">git@github.com:amasucci/configurations-examples.git</a>, that repo is structured as follows:
```console
> tree  
├── account-service-dev.yaml
└── kubernetes
    └── account-service-deployment.yaml
```

Start the service, run `curl localhost:8080/account-service/dev/master/kubernetes/account-service-deployment.yaml` and you should see something like this:
```bash
> curl localhost:8080/account-service/dev/master/kubernetes/account-service-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: account-service
  labels:
    app: account-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: account-service
  template:
    metadata:
      labels:
        app: account-service
    spec:
      containers:
      - name: account-service
        image: amasucci/account-service:2.0.21
        ports:
        - containerPort: 80
```

### Secrets
What we have so far is something very similar to helm, now let's see what else *Spring Cloud Config* can do for us. As I mentioned already, *Spring Cloud Config* can manage encryption and decryption of secret with a number of options (docs: <a href="https://cloud.spring.io/spring-cloud-config/multi/multi__spring_cloud_config_server.html#_encryption_and_decryption" target="_blank">encryption and decryption</a>). The easiest way is to enable it using a symmetric key, you can do it by exporting an environment variable (`export ENCRYPT_KEY=super_secret_symmetric_key`) or by creating a `bootstrap.yaml` file containing the encrypt.key property:

```yaml
encrypt:
  key: super_secret_symmetric_key
```

If everything went fine you should be able to encrypt and decrypt like in the example below:

```bash
> curl localhost:8080/encrypt -d mysecret
88717e467c345e57334910670834a778570fe16bd96d6fb37332d7201f1fdcf4%
> curl localhost:8080/decrypt -d 88717e467c345e57334910670834a778570fe16bd96d6fb37332d7201f1fdcf4 
mysecret%
```

Now we only need to add these to our git repo (https://github.com/amasucci/configurations-examples/), I created a new branch for version 1.0.1 and modified `account-service-dev.yaml` and `kubernetes/account-service-deployment.yaml`.

account-service-dev.yaml:
```yaml
---
deployment:
  replicas: 3
  image-name: amasucci/account-service
  image-version: 2.0.21
  secret: '{cipher}88717e467c345e57334910670834a778570fe16bd96d6fb37332d7201f1fdcf4'
---
application:
  name: account-service
```
kubernetes/account-service-deployment.yaml:
```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${application.name}
  labels:
    app: ${application.name}
spec:
  replicas: ${deployment.replicas}
  selector:
    matchLabels:
      app: ${application.name}
  template:
    metadata:
      labels:
        app: ${application.name}
    spec:
      containers:
      - name: ${application.name}
        image: ${deployment.image-name}:${deployment.image-version}
        env:
        - name: secret
          value: "${deployment.secret}"
        ports:
        - containerPort: 80
```

Now:
```bash
> curl localhost:8080/account-service/dev/1.0.1/kubernetes/account-service-deployment.yaml
```
will return your template interpolated with the values from `account-service-dev.yaml`:
```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: account-service
  labels:
    app: account-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: account-service
  template:
    metadata:
      labels:
        app: account-service
    spec:
      containers:
      - name: account-service
        image: amasucci/account-service:2.0.21
        env:
        - name: secret
          value: "mysecret"
        ports:
        - containerPort: 80
```

## Conclusions
What I described here, are just the building blocks, there is much more that can be achieved. For example, you could create a docker image with a deployment script (and the config service) and it could be executed as Kubernetes job. I like this because 	 I don’t have to install anything in the cluster and I can reproduce the same deployments in other clusters and environments. In addition, it doesn’t rely on Kubernetes secrets instead, secrets are encrypted at rest and only decrypted during deployments. What do you think? Comments and feedback are welcome, feel free to reach out.
