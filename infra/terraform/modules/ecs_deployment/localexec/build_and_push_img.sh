#!/bin/sh
set -x

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile=dmw2151 | jq '.Account | tonumber')
export AWS_DEFAULT_REGION='us-east-1'

aws ecr get-login-password --profile=dmw2151 |\
docker login \
    --username AWS \
    --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com

docker build --tag ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/$2:$3 $1

docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/$2:$3
