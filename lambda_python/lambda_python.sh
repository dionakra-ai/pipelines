#!/bin/bash

set -eo pipefail

export CI_COMMIT_BRANCH=${GITHUB_REF_NAME}

export CI_PROJECT_NAME=$(echo "${GITHUB_REPOSITORY}" | awk -F / '{print $2}')

echo "build for python ----------------------------"

if [ -z "${GO_TO_DIR}" ]; then
    export GO_TO_DIR="."
fi

cd $GO_TO_DIR

touch ./requirements.txt

pip install --no-cache --target ./package -r ./requirements.txt;

apt update && apt install -y p7zip-full awscli

echo "upload sequence start -----------------------"

# BEGIN carregando chaves

mkdir ~/.aws
touch ~/.aws/credentials

aws ssm get-parameters --names "/cicd/credentials" --with-decryption --query "Parameters[0].Value" --output text > ~/.aws/credentials

export AWS_PROFILE=${CI_COMMIT_BRANCH}

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY

# END arregando chaves

if [ -z "${SERVICE_NAME}" ]; then
    export SERVICE_NAME=${CI_PROJECT_NAME}
fi

if [ -z "${GO_TO_DIR}" ]; then
    export GO_TO_DIR="."
fi

cd $GO_TO_DIR

touch .lambdaignore;

7z a -mx=9 -mfb=64 -xr'@.lambdaignore' -xr'!.lambdaignore' -xr'!.*' -xr'!*.md' -xr'!*git*' -xr'!*.txt' -xr'!*.h' -xr'!*.hpp' -xr'!*.c' -xr'!*.cpp' -xr'!*.zip' -xr'!*.rar' -xr'!*.sh' -xr'!*.dist-info' -xr'!*.whl' -xr'!*/python/lib/python3.8/site-packages/bin/*' -xr'!*/python/lib/python3.8/site-packages/share/*' -xr'!*__pycache__*' -xr'!*.pyc' -xr'!*.pyo' -xr'!package.json' -xr'!package-lock.json' -xr'!*.go' -xr'!go.mod' -xr'!go.sum' -xr'!function_policy.json' -xr'!function_policy_arguments.json' -r main.zip .;

echo "uploading ----------------------------"

aws lambda update-function-code --function-name $SERVICE_NAME --zip-file fileb://main.zip