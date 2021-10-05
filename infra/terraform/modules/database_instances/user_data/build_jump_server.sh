#! /bin/sh

# Script installs basic utilities for the jump server, only needs to
# do some very light data processing...
sudo amazon-linux-extras install epel

# Basic utils
sudo yum update &&\
sudo yum install -y \
    awscli \
    sysstat \
    postgresql-server \
    jq
