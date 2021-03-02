#!/usr/bin/env bash

BASE64_DOCKERFILE_CONTENTS=$(cat Dockerfile | base64)
BASE64_TEST_CONFIG_CONTENTS=$(cat test.config.yml | base64)
cat action.yml.tpl | sed -e "s/%%BASE64_DOCKERFILE_CONTENTS%%/${BASE64_DOCKERFILE_CONTENTS}/g" -e "s/%%BASE64_TEST_CONFIG_CONTENTS%%/${BASE64_TEST_CONFIG_CONTENTS}/g" > action.yml
