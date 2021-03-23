#!/usr/bin/env bash

set -e

DOMAIN=""
case $APP_ENVIRONMENT in
  development)
    DOMAIN=".speareducation.localhost"
    ;;
  staging)
    DOMAIN=".speareducation.net"
    ;;
  sandbox)
    DOMAIN=".speareducation.info"
    ;;
  production)
    DOMAIN=".speareducation.com"
    ;;
  dotco)
    DOMAIN=".speareducation.co"
    ;;
  *)
    ;;
esac

# shellcheck disable=SC2001
SERVICE_NAME=$(echo "${ARTIFACT}" | sed -e "s%^.*/%%g")
wget -O/dev/null -q --header "Host: ${SERVICE_NAME}${DOMAIN}" http://localhost/healthcheck.html || exit 1
exit 0
