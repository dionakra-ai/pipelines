#!/bin/sh

set -eo pipefail

export CI_COMMIT_BRANCH=${GITHUB_REF_NAME}

export CI_PROJECT_NAME=$(echo "${GITHUB_REPOSITORY}" | awk -F / '{print $2}')

apk add --no-cache aws-cli git

# BEGIN carregando chaves

mkdir ~/.aws
touch ~/.aws/credentials

aws ssm get-parameters --names "/cicd/credentials" --with-decryption --query "Parameters[0].Value" --output text > ~/.aws/credentials

export AWS_PROFILE=${CI_COMMIT_BRANCH}

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY

# END carregando chaves

if [ -z "${SERVICE_NAME}" ]; then
    export SERVICE_NAME=${CI_PROJECT_NAME}
fi

if [ -z "${GO_TO_DIR}" ]; then
    export GO_TO_DIR="."
fi

export CLUSTER_NAME="cluster not found"

for i in $(aws ecs list-clusters --query 'clusterArns' --output text); do
    for service in $(aws ecs list-services --query 'serviceArns' --output text --cluster $i); do
        if [ $(echo "$service" | grep ${SERVICE_NAME}) ]; then
            CLUSTER_NAME=${i}
            break
        fi
    done
done

export ECR_REGISTRY_ADDRESS=$(aws ecr describe-repositories | grep repositoryUri | awk '{print $2}' | sed -e 's/\"\(.*\)\"\,/\1/' | grep ${SERVICE_NAME})

aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY_ADDRESS}

export TIMESTAMP=$(date +%s)

cd ${GO_TO_DIR}

echo "${ENVIRONMENT}" >> .env.${CI_COMMIT_BRANCH}
echo "${ENVIRONMENT_TEST}" >> .env.test

docker build -t "${ECR_REGISTRY_ADDRESS}:latest" .

docker image tag "${ECR_REGISTRY_ADDRESS}:latest" "${ECR_REGISTRY_ADDRESS}:${TIMESTAMP}"

docker push ${ECR_REGISTRY_ADDRESS}:${TIMESTAMP} &
docker push ${ECR_REGISTRY_ADDRESS}:latest &

wait

docker logout $ECR_REGISTRY_ADDRESS

sleep 5

export OLD_SERVICE_NAME=${SERVICE_NAME}

echo SERVICE_NAME=${SERVICE_NAME}
echo CLUSTER_NAME=${CLUSTER_NAME}

aws ecs update-service --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --force-new-deployment