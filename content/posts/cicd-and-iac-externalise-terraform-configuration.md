+++
date = "2022-02-03T18:00:34+01:00"
draft = false
title = "CICD and IaC - How to Externalise the terraform configuration - Ep.1"
description = "Using YAML to define terraform resources attributes and get automatic validation"
image = "/img/2022/02/03/external.jpg"
imagemin = "/img/2022/02/03/external-min.jpg"
tags = ["IaC", "CICD", "Terraform", "Software Design"]
categories = ["tutorials"]
type = "post"
featured = "external-min.jpg"
featuredalt = "CICD and IaC ithout breaking"
featuredpath = "img/2022/02/03/"
+++

# Dockerising Terraform

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

```jsx
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

```jsx
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

```jsx
module "cloud_storage" {
  source     = "./modules/wrapper"
  input = local.input
}
```

To externalise the configuration into a yaml file we can use the function `yamldecode` , if we add this section:

```jsx
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

Why? Few reasons:

1. it’s easier to read and to manage
2. input validation for free because we are using structural types and type constraints in TF
3. the yaml file can be generated by another component of the pipeline

In the next article we will see how to seal all this in an immutable artifact using docker.

For questions comment down below.
