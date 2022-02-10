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

# Externalise Terraform Configuration

This article is part of a miniseries. In the miniseries I will show with practical examples how to apply concepts of CI/CD to IaC, we are going to see how to create independent immutable artifacts for our IaC. How to package them and how to test their deployment.

This is for experienced terraform users so I won’t describe the terraform and how it works (let me know if you are interested I can make a miniseries to cover that too).

### Introducing the miniseries

If you think that using terraform is enough to say that you are doing IaC I am sorry but you are wrong. The C in IaC indicates that we treat our infrastructure as we treat our application code.

When we write application code we follow a process and in the process we have a number of best practices:

1. Use design patterns and principles
2. Source Control
3. Review Code
4. Continuous Integration
5. Testing
6. Automated deployments

What I see instead for IaC are the following two things:

1. Keep everything in source control (sometime in one single repo)
2. Review terraform plan (this is guess work)

{{< rawhtml >}}
<figure style="white-space:pre-wrap;display:flex;background: rgba(241, 241, 239, 1);border-radius: 3px;padding: 1rem;"><div style="font-size:1.5em"><span class="icon">💡</span></div><div style="width:100%">Let me pause here for a second, this topic requires its own article. Doing a review of terraform changes by inspecting the plan is like reviewing changes to a payment system by waiting for failed transactions. Results of a terraform change depend on local changes and remote state. Terraform plan is a speculative plan and returns what could potentially happen. So what the reviews become is a style check (and you can automate it with a terraform fmt) and  this line: Plan: 1 to add, 0 to change, 0 to destroy.</span></div></figure>
{{< /rawhtml >}}

In this mini series I will try to address these issues.

### Config management

In this first article, we are going to see how to separate the config (all the attributes of our terraform resource and modules) from the code (the resources themselves). 

Let’s start with a practical example, let’s say we want to create a `gcs` bucket, we can use the module from the google-terraform-modules repo:


`git clone [https://github.com/terraform-google-modules/terraform-google-cloud-storage.git](https://github.com/terraform-google-modules/terraform-google-cloud-storage.git) ./modules/terraform-google-cloud-storage`

There is a folder with examples [https://github.com/terraform-google-modules/terraform-google-cloud-storage/blob/master/examples/multiple_buckets/main.tf](https://github.com/terraform-google-modules/terraform-google-cloud-storage/blob/master/examples/multiple_buckets/main.tf)

```jsx
resource "random_string" "prefix" {
  length  = 4
  upper   = false
  special = false
}

module "cloud_storage" {
  source     = "../.."
  project_id = var.project_id
  prefix     = "multiple-buckets-${random_string.prefix.result}"

  names              = var.names
  bucket_policy_only = var.bucket_policy_only
  folders            = var.folders

  lifecycle_rules = [{
    action = {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition = {
      age                   = "10"
      matches_storage_class = "MULTI_REGIONAL,STANDARD,DURABLE_REDUCED_AVAILABILITY"
    }
  }]
}
```

Now if we look at this example we have some values hardcoded and some others passed from variables. We want to externalise the configuration so we can decouple config from code and apply something similar to the [12 factor app](https://12factor.net/config "12 Factor App config").

{{< rawhtml >}}
<figure style="white-space:pre-wrap;display:flex;background: rgba(241, 241, 239, 1);border-radius: 3px;padding: 1rem;"><div style="font-size:1.5em"><span class="icon">💡</span></div><div style="width:100%">12 Factor App are 12 best practices for application development and one of them is about storing the configuration with the environment</span></div></figure>
{{< /rawhtml >}}

### Create the object structure

The first thing we want to do is create the object structure:

```javascript
variable "input" {
    type = object({
        project_id = string
        prefix     = string

        names              = list(string)
        bucket_policy_only = map(string)
        folders            = map(list(string))
        force_destroy      = bool
        lifecycle_rules    = list(object(
            {
                action = object({
                    type = string
                    storage_class = string
                })
                condition = object({
                    age = string
                    matches_storage_class = string
                })
            })    
        )
    })
}
```

And now we can use this single variable defined as object for a module that wraps the google one.

```javascript
module "wrapper" {
  source     = "../terraform-google-cloud-storage"
  project_id = var.input.project_id
  prefix     = var.input.prefix

  names              = var.input.names
  bucket_policy_only = var.input.bucket_policy_only
  folders            = var.input.folders

  lifecycle_rules = var.input.lifecycle_rules
}
```

We wrapped the google module with a module that uses a single variable. Now  let’s invoke this module using.

```javascript
module "cloud_storage" {
  source     = "./modules/wrapper"
  input = local.input
}
```

To externalise the configuration into a yaml file we can use the function `yamldecode` , if we add this section:

```javascript
locals {
  input_file         = "./input.yaml"
  input_file_content = fileexists(local.input_file) ? file(local.input_file) : "NoInputFileFound: true"
  input  = yamldecode(local.input_file_content)
}
```

now we need to create the yaml file with the configuration: 

```yaml
---
project_id: "seed-334620"
prefix: "storage"
names: ["anto","general"]
folders:
  anto: ["/documents","/private/anto"]
  general: ["/docs","/public/general"]
bucket_policy_only:
  anto: true
  general: false
force_destroy: false
lifecycle_rules:
  - action:
      type: "SetStorageClass"
      storage_class: "NEARLINE"
    condition:
      age: "10"
      matches_storage_class: "MULTI_REGIONAL,STANDARD,DURABLE_REDUCED_AVAILABILITY"
```
# Dockerize terraform

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

## Dockerize Terraform

Now we’ll see how to dockerize the code that we created in the previous video. Let’s look at Dockerfile so I can explain step by step what’s happening.

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

```bash
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