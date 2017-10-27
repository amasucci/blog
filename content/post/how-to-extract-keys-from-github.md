+++
date = "2017-10-27T05:08:51+01:00"
title = "How to extract public keys from github enterprise"
image = "/img/ssh-keys.jpg"
imagemin = "/img/ssh-keys-min.jpg"
description = "Bash script to extract public keys for each member of a team in a specific organization in GitHub"
tags = ["github", "bash", "devops"]
categories = ["tutorials"]
+++

![How to extract public keys from github enterprise](/img/ssh-keys.jpg)

The following post will explain how to get all the public keys used by members of a team in github.
This can be useful whenever you want to setup ssh keys to give access to a new machine.

Before starting you need an access token in order to call your [GitHub api](https://developer.github.com/v3/), the easiest way is creating a personal access token and select the `read:org` as in the screenshot below. If you are interested in other in other authorization mechanisms refere to the [official documentation](https://developer.github.com/v3/oauth_authorizations/).

![Create a personal access token](/img/github_permissions.png)


### Script
```bash
#!/usr/bin/env bash

set -eu

if [[ "$#" -ne 5 ]]; then
  echo "Usage: $0 <git_username> <git_personal_token> <api_url> <organization_name> <team_name>" >&2
  exit 1
fi

git_username=$1
git_personal_token=$2
api_url=$3
organization_name=$4
team_name=$5

team=$(curl -s -u $git_username:$git_personal_token $api_url/orgs/$organization_name/teams | jq -r ".[] | select(.slug == \"$team_name\") | .members_url | split(\"{\")[0]")
member_urls=$(curl -s -u $git_username:$git_personal_token $team | jq -r '.[] | .url')
while read -r line; do
    curl -s -u $git_username:$git_personal_token $line/keys | jq -r '.[] | .key'
done <<< "$member_urls"
```
