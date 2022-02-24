+++
date = "2022-02-24T06:32:34+01:00"
draft = false
title = "CICD and IaC - Test terraform with terratest in Docker - Ep.3"
description = "How to test terraform using Golang and Terratest"
image = "/img/2022/02/24/cover.jpg"
imagemin = "/img/2022/02/17/cover-min.jpg"
tags = ["IaC", "CICD", "Terraform", "Software Design"]
categories = ["tutorials"]
type = "post"
featured = "cover-min.jpg"
featuredalt = "CICD and IaC"
featuredpath = "img/2022/02/17/"
+++


# Test terraform

In this third episode of the miniseries CICD and IaC we are going to see how to test the artifact we created in the previous video.

## In the previous episodes

In previous episodes (link to the playlist) I showed you how to externalise the terraform configuration using the yamldecode function in terraform and how to create artifacts for terraform code using Docker.

## Today

we are going to start from where we left, and I am going to create a simple test for our module. We want to to test our terraform code and our docker artifact. So, I will create a test and I will dockerise that too.

Ok let’s move to code ([https://github.com/outofdevops/cicd-iac](https://github.com/outofdevops/cicd-iac)):

```bash
cicd-iac
├── configuration/
├── dockerisation/
└── testing/
│   ├── test/
│   │   ├── gcs_test.go
│   │   ├── go.mod
│   │   └── go.sum
│   ├── modules/
│   ├── Dockerfile
│   ├── main.tf
│   ├── providers.tf
│   └── terraform.rc
├── .gitignore
└── README.md
```

Now I have here a third folder `testing`, this is going to contain the same code from the previous videos. In addition you may have noticed that it also contains a `test` folder.

## The Test file

This folder contains our test files, let’s look at them:

```go
package test

import (
	"context"
	"os"
	"testing"

	"cloud.google.com/go/storage"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

const input_yaml = `
---
project_id: "seed-423789"
prefix: "storage"
names: ["anto","general"]
folders:
  anto: ["/documents","/private/anto"]
  general: ["/docs","/public/general"]
bucket_policy_only:
  anto: true
  general: false
force_destroy: true
lifecycle_rules:
  - action:
      type: "SetStorageClass"
      storage_class: "NEARLINE"
    condition:
      age: "10"
      matches_storage_class: "MULTI_REGIONAL,STANDARD,DURABLE_REDUCED_AVAILABILITY"
`

func writeInput(content string) {
	d1 := []byte(content)
	e := os.WriteFile("/config/input.yaml", d1, 0644)
	if e != nil {
		panic(e)
	}
}

func TestTerraformGCS(t *testing.T) {
	// retryable errors in terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "/tf",
		BackendConfig: map[string]interface{}{
			"prefix": "test",
			"bucket": "tf-state-outofdevops",
		},
	})

	writeInput(input_yaml)
	defer terraform.Destroy(t, terraformOptions)

	assert.Equal(t, false, bucketExists("storage-eu-anto"))
	assert.Equal(t, false, bucketExists("storage-eu-general"))
	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, true, bucketExists("storage-eu-anto"))
	assert.Equal(t, true, bucketExists("storage-eu-general"))
}

func bucketExists(bucketName string) bool {
	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		return false
	}
	defer client.Close()

	bucket := client.Bucket(bucketName)

	_, err = bucket.Attrs(ctx)

	return err == nil
}
```

This is our test written in Go, we are using terratest to manage the terraform lifecycle.

The test is very simple:

1. we specify our input file in yaml (lines 13-32)
2. we write that to disk (line 52)
3. we verify that the buckets we want to create don’t exist already (lines 55-56)
4. we `InitAndApply` or terraform code (line 57)
5. we verify again that the buckets exist (lines 59-60)

## The Dockerfile

The other file we have in this folder is a Dockerfile, with want to run our test on top of the image we already have.

Let’s look inside it:

```docker
#STAGE 1 Build your test
FROM golang:1.16 as build
WORKDIR /work_dir
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY gcs_test.go .
ENV CGO_ENABLED=0
RUN go test -c -o gcs_test

#STAGE 2 Run Test
FROM terraform-gcs as test

COPY --from=build /work_dir/gcs_test /working_dir/gcs_test
```

This is another multi-stage build where in the first stage we compile our Go test and in the second we copy the executable `gcs_test` on top of the `terraform_gcs` this is the name on the image we built in the [previous episode](posts/cicd-and-iac-dockerize-terraform/).

{{< rawhtml >}}
<figure style="white-space:pre-wrap;display:flex;background: rgba(241, 241, 239, 1);border-radius: 3px;padding: 1rem;" id="f9fabd1f-5b46-4239-bedd-c622fa8f6eb5"><div style="font-size:1.5em"><span class="icon">💡</span></div><div style="width:100%">Why we need to compile the test?
If you remember our docker image is based on the SCRATCH image this means that we don’t have a go runtime environment so we cannot run go test.</span></div></figure>
{{< /rawhtml >}}

## Build and Test

So now we have to just build: `docker build . -t terraform_test`

and run:

```bash
docker run -it -e GOOGLE_APPLICATION_CREDENTIALS=/config/sa.json \
    -v ~/sa.json:/config/sa.json:ro \
    terraform_test /working_dir/gcs_test
```

## Conclusions

Now we have our terraform code in a container and tested. We are treading our IaC like application code because:

1. Externalised the configuration
2. Packaged our artifact
3. Tested our code

In the next episode we will see how we can build a CD pipeline for Application and Infrastructure code.
