#!/usr/bin/env bash

set -e

# shellcheck disable=SC2001
DOCKER_HEALTHCHECK_PATH=${DOCKER_HEALTHCHECK_PATH:-/healthcheck.html}
SERVICE_NAME=$(cat "/etc/spear-repository" | sed -e "s%^.*/%%g")
wget -O/dev/null -q --header "Host: ${SERVICE_NAME}${DOMAIN}" "http://localhost${DOCKER_HEALTHCHECK_PATH}" || exit 1
exit 0
