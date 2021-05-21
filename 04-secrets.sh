#!/usr/bin/env bash
# Invoked at startup to fetch secrets from AWS
#

set -e

AWS_BIN=$(which aws)

AWS_BIN=${AWS_BIN:-/usr/bin/aws}

if [[ "x${RELEASE_DEBUG}" == "x1" ]]; then
  set -x
fi

if [[ "x${SKIP_SECRETS}" == "x1" ]]; then
    echo "Skipping secrets fetch because SKIP_SECRETS is set."
    exit 0;
fi

if [[ ! -f /etc/spear-repository ]] && [[ -z ${SECRET_NAME} ]]; then
  echo "No repository info found. Skipping secrets."
  exit 0;
fi

REPO_NAME=${SECRET_NAME:-$(sed -e 's/\.git$//g' < /etc/spear-repository)}

if [[ -f /etc/secret-base-name ]]; then
  SECRET_NAME=$(cat /etc/secret-base-name)
else
  SECRET_NAME=${REPO_NAME}
  case "$REPO_NAME" in
    speareducation/spear-zf1)
      SECRET_NAME="speareducation/www"
      ;;
    speareducation/curriculum)
      SECRET_NAME="speareducation/online"
      ;;
    *)
      SECRET_NAME=$(cat /etc/spear-repository)
      ;;
  esac
fi

SECRET_TYPE="env"
if [[ "x${SECRET_NAME}" == "xspeareducation/www" ]]; then
  SECRET_TYPE="ini"
fi

# We massage environment variables with placeholders so they come up empty in the env if defaulted.
if [[ "x${AWS_ACCESS_KEY_ID}" == "x**string**" ]] || [[ "x${AWS_SECRET_ACCESS_KEY}" == "x**string**" ]]; then
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
fi

# Since it's perfect valid to have a access key and a secret key without a session token, we check it separately here.
if [[ "x${AWS_SESSION_TOKEN}" == "x**string**" ]]; then
  unset AWS_SESSION_TOKEN
fi

# Look for aws secrets
if [[ "x${AWS_ACCESS_KEY_ID}" == "x" ]] || [[ "x${AWS_SECRET_ACCESS_KEY}" == "x" ]] || [[ "x${AWS_ACCESS_KEY_ID}" == "x**string**" ]]; then
  echo "Attempting to load secrets from /run/secrets"
  # Look for it in docker secrets
  #
  # shellcheck disable=SC2155
  export AWS_ACCESS_KEY_ID=$(cat /run/secrets/AWS_ACCESS_KEY_ID)
  # shellcheck disable=SC2155
  export AWS_SECRET_ACCESS_KEY=$(cat /run/secrets/AWS_SECRET_ACCESS_KEY)
fi

if [[ -z "${APP_ENVIRONMENT}" ]]; then
  # shellcheck disable=SC2155
  export APP_ENVIRONMENT=$(cat /run/secrets/APP_ENVIRONMENT)
fi

SECRET_ID=${APP_ENVIRONMENT}/${SECRET_NAME}/master/${SECRET_TYPE}
SECRET_DATA=$(${AWS_BIN} --region="${AWS_REGION:-us-east-1}" secretsmanager get-secret-value --secret-id "${SECRET_ID}")
[[ "x${SECRET_DATA}" == "x" ]] && exit 0;

# shellcheck disable=SC2116
SECRET_JSON=$(echo "${SECRET_DATA}")

ENV_FILE_LOCATION=${ENV_FILE_LOCATION:-/var/www/html/.env}

SECRET_TEMP_FILE=$(mktemp /tmp/secret-temp.XXXXXXX)
SECRET_OUTPUT_LOCATION=
case ${SECRET_TYPE} in
    env)
        SECRET_OUTPUT_LOCATION=${ENV_FILE_LOCATION}
        ;;
    ini)
        SECRET_OUTPUT_LOCATION=/var/www/html/application.ini
        ;;
esac

echo "${SECRET_JSON}" >> "${SECRET_TEMP_FILE}"

convert_secrets() {
  SECRET_TEMP_FILE=${1}
  jq -r .SecretString < "${SECRET_TEMP_FILE}" | jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]"
}

convert_secrets "${SECRET_TEMP_FILE}" > "${SECRET_OUTPUT_LOCATION}"
rm -f "${SECRET_TEMP_FILE}"

if [[ -f ${ENV_FILE_LOCATION} ]]; then
  echo "LOG_CHANNEL=stderr" >> "${ENV_FILE_LOCATION}"
fi

