+++
date = "2022-02-24T06:32:34+01:00"
draft = false
title = "CICD and IaC - IaC Design a CD Pipeline - Ep.4"
description = "How to design a continuous delivery pipeline for application and infrastructure code"
image = "/img/2022/02/24/cover.jpg"
imagemin = "/img/2022/02/24/cover-min.jpg"
tags = ["IaC", "CICD", "Terraform", "Software Design"]
categories = ["tutorials"]
type = "post"
featured = "cover-min.jpg"
featuredalt = "CICD and IaC"
featuredpath = "img/2022/02/24/"
+++

# IaC Design a CD Pipeline - CICD and IaC Episode 4

This is the last episode of the miniseries CICD and IaC. In this episode we are going to put everything together and see what’s next.

## In the previous episodes

This mini series started with the [first episode](https://www.youtube.com/watch?v=FHDkxk9odLA) about externalising the terraform configuration using yaml decode and yaml files instead of terraform variables. We discussed the different reasons:

1. Store configuration in the env (12 factor app)
2. Easier to review and less surprises compared to the overrides mechanisms offered by TF vars
3. Automatic validation

Then we saw [how to seal our terraform modules with docker](https://www.youtube.com/watch?v=NydC9yMAfSg). We did this to create immutable artifacts for our Infrastructure as code. We also used `terraform providers mirror` in this way we downloaded all the dependencies (providers and modules) and packaged them into our image. The docker images can be executed even in air-gapped environments (environments without connectivity to the public internet).

In the last episode finally we saw [how to test terraform using terratest](https://www.youtube.com/watch?v=0jGKqATMz-A).

## Today

We are going to do some considerations on what we have so far and what we can do next. So in the previous three videos we have applied principles and processes that we normally apply for application development.

### The App pipeline

Now let’s see what happens when we design our CICD pipeline, let’s start with a typical application pipeline:

![application pipeline](/img/2022/02/24/app-pipeline.png)

Here we have a stage where a docker base image for Java services is baked and it triggers the build of other docker images (one per service). Once we have our updated images we deploy them in the dev environment.

### The IaC pipeline

Now if you look at the app pipeline we can see that we have artifacts and configuration defined in different places and with well defined dependencies. But after all the changes we introduced in our IaC we can create a similar pipeline for IaC.

![infrastructure pipeline](/img/2022/02/24/iac-pipeline.png)

In this pipeline we have terraform base images triggering the build of modules’ images that then trigger the provisioning of infrastructure.

### Everything together

We can now connect the two pipelines and trigger application deployments when infrastructure is provisioned.

![full pipeline](/img/2022/02/24/full-pipeline.png)

Remember with CD our goal is to have a systems that for every change at any level of the pipeline automatically executes and breaks in case of issues.

### Conclusions

Now should be clear that if start treating the Infrastructure as Code similarly to how we treat the application code we can apply very similar techniques like this CICD pipeline.

We can also design things in a different way because we can only deploy the application on a working infrastructure, and now that the pipelines are connected, every time we provision a new infrastructure change we don’t want to deploy applications before testing. But this is impossible if we target the same infrastructure components, so this means we have to provision new infrastructure, test it and then deploy the application on the new infra. Only at the end of application testing we can decommission the old infrastructure.

This model is ideal and removes completely the need for terraform plan approval but has trade offs in terms of engineering effort and initial complexity.

Another advantage of constantly re-creating your environments is the ability to continuously test you disaster recovery procedures and your ability to bootstrap without circular dependencies.

Let me know what you think in comment section below.