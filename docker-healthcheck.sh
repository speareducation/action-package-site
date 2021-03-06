#!/usr/bin/env bash

set -e

[[ -f /var/www/html/.buildconfig ]] && . /var/www/html/.buildconfig
# shellcheck disable=SC2001
DOCKER_HEALTHCHECK_PATH=${DOCKER_HEALTHCHECK_PATH:-/healthcheck.html}
SERVICE_NAME=${DOCKER_HOSTNAME:-$(cat "/etc/spear-repository" | sed -e "s%^.*/%%g")}
wget -O/dev/null -q --header "Host: ${SERVICE_NAME}${DOMAIN}" "http://localhost${DOCKER_HEALTHCHECK_PATH}" || exit 1
exit 0
