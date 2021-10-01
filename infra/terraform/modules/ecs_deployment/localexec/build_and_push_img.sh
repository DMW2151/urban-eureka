#! /bin/bash


# To Push Application
# bash ./utils/aws/build_and_push_img.sh ./src/ tileserver-api development
# bash ./utils/aws/build_and_push_img.sh ./service_images/tile-cache tileserver-cache development

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile=dmw2151 | jq '.Account | tonumber')
export AWS_DEFAULT_REGION='us-east-1'

aws ecr get-login-password --profile=dmw2151 |\
docker login \
    --username AWS \
    --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com

# Sensor API
docker buildx build \
    --platform $4 $1 \
    --tag ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/$2:$3 \
    --output type=registry
