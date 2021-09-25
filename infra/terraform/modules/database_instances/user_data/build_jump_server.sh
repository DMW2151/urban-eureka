#! /bin/sh
# Script installs basic utilities for the jump server..

sudo amazon-linux-extras install epel

# Basic utils
sudo yum update &&\
sudo yum install -y \
    awscli \
    sysstat \
    postgresql-server \
    jq
