+++
date = "2018-03-18T08:20:30+01:00"
title = "Simplify secret management with OpenSSL and Docker"
image = "/img/encrypt-openssl-docker.jpg"
imagemin = "/img/encrypt-openssl-docker-min.jpg"
description = "If you are looking for a secure and easy way to store and access secrets you may find the following post useful"
tags = ["encryption", "secrets management", "openssl", "bash", "devops", "docker"]
categories = ["tutorials"]
type = "post"
featured = "encrypt-openssl-docker-min.jpg"
featuredalt = "encrypt-openssl-docker"
featuredpath = "img"
+++

Simplify secret management with OpenSSL and Docker, if you are looking for a secure and easy way to store and access secrets you may find the following post useful.

A while ago I covered something similar in this post [How to encrypt and decrypt a file on the command line](../../../../2017/05/13/how-to-encrypt-and-decrypt-a-file-on-the-command-line/).

This post can be seen as the next step to not only encrypt and decrypt values but also to manage secrets across multiple environments, I am going to show you how combine OpenSSL with Docker to get the best of both tools. Complete source code can be found on [GitHub](https://github.com/amasucci/secret-box).

The idea is to store your passwords as encrypted values in a Docker image, in this way you can always have access to the secrets by simply running `docker run -it secret-box $secret_name $encryption_password`.
Values are AES-256 encrypted using OpenSSL and it is considered secure.

#### Requirements
- 10 minutes
- Docker installed
- OpenSSL installed

To create your Docker image you need to create following files:

- Dockerfile
- encrypt.sh
- entrypoint.sh

Copy and paste the following snippet in a file named `Dockerfile`.
```Docker
FROM alpine:3.5

RUN addgroup SecretBOX && \
    adduser -D -G SecretBOX SecretBOX && \
    apk add --no-cache openssl

COPY entrypoint.sh /entrypoint.sh
COPY ./vaults/ /vaults

RUN chown -R SecretBOX:SecretBOX /vaults && chown SecretBOX:SecretBOX /entrypoint.sh

USER SecretBOX

ENTRYPOINT ["/entrypoint.sh"]
```

Now you need the entrypoint.sh, copy the content of the next snippet in `entrypoint.sh`

```bash
#!/usr/bin/env sh
set -eu

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 [Secret Name] [Decryption Password]"
    exit 1
fi

secret_name=$1
password=$2

cat /vaults/${secret_name} | openssl enc -a -d -aes-256-cbc -salt -k ${password}
```

Now you have everything you need to build your Docker image, but you still have to add secrets.
To add secrets you can do it from the command line or use a script like this:

```bash
#!/usr/bin/env bash

set -eu

echo -n "Secret name: "
read secret_name
echo -n "Secret to encrypt: "
read -s secret
echo
echo -n "Encryption password: "
read -s password
echo

mkdir -p vaults
echo "${secret}" | openssl enc -a -e -aes-256-cbc -salt -k ${password} > ./vaults/${secret_name}
```

Save it in a file I named it `encrypt.sh` and run it:
```bash
$bash <> ./encrypt.sh
Secret name: mysql_password
Secret to encrypt: ********
Encryption password: ********
$bash <> 
```

You should be able to see a new directory `vaults` with a mysql_password file inside. Everything is ready for the Docker image to be built:

```bash
$bash > docker build . -t secret-box:latest
ending build context to Docker daemon  10.24kB
Step 1/7 : FROM alpine:3.5
..
..
Successfully built 0efa296aa899
$bash > 
```

To test it:
```bash
$bash > export decryption_password=super_secret_password
$bash > docker run --rm secret-box mysql_password ${decryption_password}
P455W0Rd_!
```

Comments and feedback are welcome.
