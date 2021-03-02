---
name: "Package Spear Site"
author: "Kenzi Stewart <kstewart@speareducation.com>"
description: "Packages a site into a deployable docker image"
inputs:
  aws-access-key-id:
    required: true
    description: "Amazon AWS Access Key ID"
  aws-secret-access-key:
    required: true
    description: "Amazon AWS Secret Access Key"
  node-auth-token:
    require: true
    description: "Authorization key for Node repository"
runs:
  using: "composite"
  steps:
    - name: Package site
      shell: bash
      run: |
        set -ex
        set -a
        . .buildconfig
        set +a
        TARGET_IMAGE_VERSION=$(echo "${{ env.GITHUB_REF }}" | sed -e 's%refs/tags/%%g' -e "s%^v%%g" -e "s%refs/heads/%%g" -e "s%features/%%g" -e "s%releases/%%g" -e "s%/%-%g")
        pwd
        DOCKERFILE_CONTENTS="%%BASE64_DOCKERFILE_CONTENTS%%"
        echo ${DOCKERFILE_CONTENTS} | base64 -d > ./Dockerfile

        docker build \
          --build-arg AWS_ACCESS_KEY_ID="${{ inputs.aws-access-key-id }}" \
          --build-arg AWS_SECRET_ACCESS_KEY="${{ inputs.aws-secret-access-key }}" \
          --build-arg GIT_BRANCH="${TARGET_IMAGE_VERSION}" \
          --build-arg GIT_REPOSITORY="${{ env.GITHUB_REPOSITORY }}" \
          --build-arg ARTIFACT="${ARTIFACT}" \
          --build-arg DOCKER_REGISTRY="${DOCKER_REGISTRY}" \
          --build-arg DOCKER_BASE_IMAGE="${DOCKER_REGISTRY}/${DOCKER_BASE_IMAGE_NAME}:${DOCKER_BASE_IMAGE_VER}" \
          --build-arg NODE_AUTH_TOKEN="${{ inputs.node-auth-token }}" \
          --build-arg GITHUB_TOKEN=${GITHUB_TOKEN} \
          -t "${DOCKER_REGISTRY}/${ARTIFACT}:${TARGET_IMAGE_VERSION}" .
    - name: Test Release Artifact
      shell: bash
      run: |
        set -ex
        DOCKER_IMAGE_TAG="${DOCKER_REGISTRY}/${ARTIFACT}:${TARGET_IMAGE_VERSION}"
        TEST_CONFIG_FILE=./test.config.yml
        TEST_CONFIG_CONTENTS="%%BASE64_TEST_CONFIG_CONTENTS%%"
        echo ${TEST_CONFIG_CONTENTS} | base64 -d > "${TEST_CONFIG_FILE}"

        TEST_NAMES=$(yq -r '.tests | keys[]' < "${TEST_CONFIG_FILE}")
        DGOSS_BIN="./build/dgoss"
        mkdir -p build/goss
        wget -q -O"${BUILD_DIR}/goss-linux-amd64" https://github.com/aelsabbahy/goss/releases/download/v0.3.16/goss-linux-amd64
        wget -q -O"${BUILD_DIR}/dgoss" "https://raw.githubusercontent.com/aelsabbahy/goss/v0.3.16/extras/dgoss/dgoss"
        mkdir -p build
        for TEST_NAME in ${TEST_NAMES}; do
          DOCKER_ARGS=""
          echo "TEST: ${TEST_NAME}"
          echo -n "  "
          yq -r ".tests.${TEST_NAME}.description" < ${TEST_CONFIG_FILE}
          ENV_VARS=$(yq -r ".tests.${TEST_NAME}.environment | keys[]" < "${TEST_CONFIG_FILE}")
          for VAR_NAME in ${ENV_VARS}; do
            VAR_VALUE=$(yq -r ".tests.${TEST_NAME}.environment.${VAR_NAME}" < "${TEST_CONFIG_FILE}")
            DOCKER_ARGS+=" -e ${VAR_NAME}=${VAR_VALUE}"
          done
          yq -Y ".tests.${TEST_NAME}.goss_config" < "${TEST_CONFIG_FILE}" > "build/test-goss.${TEST_NAME}.yml"
          GOSS_FILE="build/test-goss.${TEST_NAME}.yml" ${DGOSS_BIN} run --rm -it ${DOCKER_ARGS} "${DOCKER_IMAGE_TAG}"
        done
    - name: Publish Artifact to ECR
      shell: bash
      run: |
        set -ex
        docker push "${DOCKER_REGISTRY}/${ARTIFACT}:${TARGET_IMAGE_VERSION}"
