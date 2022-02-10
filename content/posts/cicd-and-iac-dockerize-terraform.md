+++
date = "2022-02-10T18:00:34+01:00"
draft = false
title = "CICD and IaC - How to Dockerize Terraform - Ep.2"
description = "Using Docker to create terraform artifacts"
image = "/img/2022/02/10/dockerize-terraform.jpg"
imagemin = "/img/2022/02/10/dockerize-terraform-min.jpg"
tags = ["IaC", "CICD", "Terraform", "Software Design"]
categories = ["tutorials"]
type = "post"
featured = "dockerize-terraform-min.jpg"
featuredalt = "CICD and IaC"
featuredpath = "img/2022/02/10/"
+++

# Dockerise terraform

In this second episode of the miniseries CICD and IaC we are going to see how to create immutable artifacts for our terraform code. 

## In the previous episode

We saw how to externalise the configuration of our terraform code → we moved all our variables in a single variable using terraform structured types. While this is nice, because yaml is more readable than HCL, readability is not the only reason for moving the config/variables outside. In the previous video I mentioned the 12factor app, the third factor is config and it requires a strict separation of config from code.

## Why I want to adopt this principle that is specific for app development to IaC?

Because in terraform you can pass values to resources in 5 different ways:

1. Hardcode them
2. Using variables and setting a default value
3. Using variables and passing a `.tfvars` (variable definition file)
4. On the command line using `-var`
5. Environment Variables `TF_VAR_`

With all these ways and their different override mechanisms reviewing a change is painful and error prone.

Separating the config from the code gives us a way to review code changes separated from config changes. It also simplifies automation that is why we started this miniseries in the first place.

## How do we enforce this

To enforce this separation we can go a step further and create an artifact with our terraform code. An artifact is a bundle that contains our terraform code. We could simply zip our code and find a way to distribute it. But I found that docker provides a great way to seal our terraform code and also our execution environment.

## Dockerise Terraform

Now we’ll see how to dockerise the code that we created in the previous video. Let’s look at Dockerfile so I can explain step by step what’s happening.

```docker
#STAGE 1 CA Certificates
FROM alpine:latest as certs
RUN apk --update add ca-certificates

#STAGE 2 Dependencies
FROM hashicorp/terraform:1.1.4 as tf

ENV TF_LOG=DEBUG
RUN git clone -b v3.1.0 --depth 1 \
  https://github.com/terraform-google-modules/terraform-google-cloud-storage \
  /tf/modules/terraform-google-cloud-storage
COPY ./providers.tf /tf/providers.tf
RUN mkdir /mirrors /empty_dir
RUN cd /tf && terraform providers mirror /mirrors
COPY ./modules/wrapper /tf/modules/wrapper
COPY ./main.tf /tf/main.tf

#STAGE 3 Packaging
FROM scratch
ENV PATH=/bin
ENV TF_CLI_CONFIG_FILE=/terraform.rc
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=tf /tf /tf
COPY --from=tf /mirrors /mirrors
COPY --from=tf /empty_dir /tmp
COPY terraform.rc /terraform.rc
COPY --from=tf /bin/terraform /bin/terraform
WORKDIR /working_dir
```

This is a multi-stage build, we have three `FROM` :

- `FROM` alpine
- `FROM` terraform
- `FROM` scratch

 `FROM` scratch is used to build minimal images so this helps to minimise the risk of adding CVEs to our images.

## Stage One

In the first build step we update the CA certificates that we are going to need in the third step.

In the second one instead we are going to copy our code and setup few things.

### Terraform bundle and terraform providers mirror

Before we look in detail at this build step I need to explain two terraform command that are not of common use: `terraform-bundle` and `terraform providers mirror` 

`terraform-bundle` is a command that creates a bundle with all the dependencies needed for the execution of terraform init→ plan→ apply and was now is deprecated and is going to be removed in the future. Its documentation can be found under `tools` → `terraform-bundle` on the `v0.15` tag on the [GitHub terraform repo](https://github.com/hashicorp/terraform/blob/v0.15/tools/terraform-bundle/README.md).

`terraform-bundle` has been replaced by another command: `terraform providers mirror`

This command works in a similar way and is the one we are using in the dockerfile.

```docker
FROM hashicorp/terraform:1.1.4 as tf

RUN git clone -b v3.1.0 --depth 1 \
  https://github.com/terraform-google-modules/terraform-google-cloud-storage \
  /tf/modules/terraform-google-cloud-storage
COPY ./providers.tf /tf/providers.tf
RUN mkdir /mirrors
RUN cd /tf && terraform providers mirror /mirrors
COPY ./modules/gcs /tf/modules/gcs
COPY ./main.tf /tf/main.tf
```

## Stage two

In the second build stage we run `FROM` terraform image where we clone the module (the one from google that we used in the previous video) and we run `terraform providers mirror`.

`terraform providers mirror` needs to know the providers we want to mirror locally, so we copy the `[providers.tf](http://providers.tf)` from our folder to the docker image and then we run `terraform providers mirror /mirrors` (where `/mirrors` is the destination directory).

```json
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.8.0"
    }
    random = {
        source  = "hashicorp/random"
        version = "3.1.0"
    }
  }
}

provider "google" {

}

terraform {
  backend "gcs" {}
}
```

At this point we can copy the rest of the files:

`modules/gcs`

`main.tf`

## Stage three

In this last stage we copy everything from the previous stages and we configure the environment to execute terraform commands in docker.

When using terraform providers mirror we need to specify where the providers have been mirrored and we do that using a file `terraform.rc`

```json
provider_installation {
  filesystem_mirror {
    path    = "/mirrors"
    include = ["hashicorp/google", "hashicorp/random"]
  }
  direct {
    exclude = ["hashicorp/google", "hashicorp/random"]
  }
}
```

## Build and Run

To build and run we can simply run the following commands:

```yaml
#BUILD
docker build . -t terraform-gcs

#VOLUME
docker volume create tf-wd

#INIT
docker run -it -e GOOGLE_APPLICATION_CREDENTIALS=/config/sa.json \
  -v tf-wd:/working_dir -v ~/sa.json:/config/sa.json:ro \
  terraform-gcs terraform init -from-module=/tf \
  -backend-config="prefix=dev" \
  -backend-config="bucket=tf-state-outofdevops"

#PLAN
docker run -it -e GOOGLE_APPLICATION_CREDENTIALS=/config/sa.json \
  -v tf-wd:/working_dir -v ~/sa.json:/config/sa.json:ro \
  -v $PWD/input.yaml:/config/input.yaml:ro \
  terraform-gcs terraform plan -out /working_dir/plan

#APPLY
docker run -it -e GOOGLE_APPLICATION_CREDENTIALS=/config/sa.json \
  -v tf-wd:/working_dir -v ~/sa.json:/config/sa.json:ro \
  -v $PWD/input.yaml:/config/input.yaml:ro \
  terraform-gcs terraform apply /working_dir/plan

#DESTROY
docker run -it -e GOOGLE_APPLICATION_CREDENTIALS=/config/sa.json \
  -v tf-wd:/working_dir -v ~/sa.json:/config/sa.json:ro \
  -v $PWD/input.yaml:/config/input.yaml:ro \
  terraform-gcs terraform destroy
```

## Conclusions

Now we have an immutable artifact that can be configured with a single file. In the next video we are going to see how to test our artifact and we are going to discuss the promotion across environments.
