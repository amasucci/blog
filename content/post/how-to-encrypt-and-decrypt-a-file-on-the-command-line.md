+++
date = "2017-05-13T18:12:37+01:00"
title = "How to encrypt and decrypt a file on the command line"
image = "/img/lock.jpg"
description = "Encrypt and decrypt files using bash and OpenSSL"
tags = ["encryption", "secrets management", "openssl", "bash", "devops"]
categories = ["tutorials"]
+++

![Lock image](/img/lock.jpg)

Soon or later we may need to encrypt files, here a quick way to encrypt/decrypt file from the command line.

How to Encrypt

<pre>
<code class="bash">#!/bin/bash
set -eu
if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Usage $0 filename"
    exit 1
fi
ORIGINAL_FILE=$1
echo -n Password:
read -s ENCRYPTION_PASSWORD
echo
ENCRYPTED_EXTENSION=".enc"
ENCRYPTED_FILE="${ORIGINAL_FILE}${ENCRYPTED_EXTENSION}"
openssl enc -aes-256-cbc -in $ORIGINAL_FILE -out $ENCRYPTED_FILE -k "$ENCRYPTION_PASSWORD"
echo "$ENCRYPTED_FILE created"
</code>
</pre>

How to Decrypt

<pre>
<code class="bash">#!/bin/bash
set -eu

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Usage $0 filename"
    exit 1
fi
ENCRYPTED_FILE=$1
echo -n Password:
read -s ENCRYPTION_PASSWORD
echo
ENCRYPTED_EXTENSION=".enc"
DECRYPTED_FILE="${ENCRYPTED_FILE%.enc}"
openssl enc -aes-256-cbc -d -in $ENCRYPTED_FILE -k "$ENCRYPTION_PASSWORD" > $DECRYPTED_FILE
echo "$DECRYPTED_FILE"
</code>
</pre>
