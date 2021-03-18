ARG DOCKER_BASE_IMAGE

FROM ${DOCKER_BASE_IMAGE}

ARG AWS_SESSION_TOKEN
ARG NODE_AUTH_TOKEN

RUN set -xe && \
    mkdir -p /root/.ssh && \
    apk add gettext

RUN set -xe && \
    echo "Removing stale /var/www/html dir if it exists" && \
    cd /var/www && \
    rm -rf /var/www/html && \
    mkdir -p /var/www/html

COPY . /var/www/html

RUN set -xe && \
    echo "Loading build configuration from .buildconfig" && \
    [[ -f ./.buildconfig ]] && . ./.buildconfig && \
    if [[ -f /var/www/html/.env.drone ]]; then \
        . /var/www/html/.env.drone; \
    fi; \
    export ALGOLIA_MAIN_ID=0000000000 && \
    export ALGOLIA_MAIN_KEY=00000000000000000000000000000000 && \
    export NODE_AUTH_TOKEN="${NODE_AUTH_TOKEN}" && \
    echo -n "Checking for node auth token..." && \
    if [[ "x${NODE_AUTH_TOKEN}" != "x" ]]; then \
      echo "found."; \
      echo -n "Adding node auth token to npmrc..."; \
      touch "${HOME}/.npmrc"; \
      npm config set always-auth true; \
      echo "//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}" >> "${HOME}/.npmrc"; \
      cat ${HOME}/.npmrc; \
      echo "done."; \
    else \
      echo "not found."; \
    fi

RUN set -xe && \
    echo "Running 'make install'..." && \
    cd /var/www/html && \
    make install && \
    echo " done."

RUN set -xe && \
    echo "Cleaning up unnecessary artifacts after build" && \
    rm -rf /var/www/html/node_modules && \
    rm -rf /var/www/html/.git && \
    echo -n "Changing permissions on /var/www/html..." && \
    chown -R www-data /var/www/html && \
    echo " done."

RUN set -xe && \
    echo -n "Setting laravel log to point to /dev/stderr..." && \
    mkdir -p /var/log/html/storage/logs && \
    ln -sfn /dev/stderr /var/log/html/storage/logs/laravel.log && \
    echo " done."

RUN set -xe && \
    echo -n "Outputting Git information to container..." && \
    echo "${GIT_REPOSITORY}" | sed -e 's/accounts2/accounts/g' -e 's/curriculum/online/g' -e 's/\.git$//g' > /etc/spear-repository && \
    echo "${GIT_BRANCH}" > /etc/spear-branch && \
    echo "${GIT_COMMIT}" > /etc/spear-commit-id && \
    date > /etc/spear-build-date && \
    mkdir -p /var/www/html/public && \
    echo "${GIT_BRANCH}" > /var/www/html/public/release.txt && \
    echo " done."

RUN set -xe && \
    echo -n "Checking for special cases (spear-review)..." && \
    if [[ "x${GIT_REPOSITORY}" == "xspeareducation/spear-review" ]]; then \
        echo " found."; \
        echo -n "Rewriting configs for spear-review..."; \
        sed -i .orig -e $'s%\(<VirtualHost \*:80>\)%\\1\\\n    RedirectMatch ^/spear-review/(.*)/$ /spear-review/$1\\\n    Alias \"/spear-review\" \"/var/www/html/public\"%g' /etc/apache2/conf.d/99_default.conf && \
        rm -f /etc/apache2/conf.d/99_default.conf.orig; \
    fi; \
    echo " done."

RUN set -xe && \
    echo "Configuring application specific php overrides..." && \
    export PHP_INI_DIR=/etc/php7 && \
    export PHP_CONF_DIR=${PHP_INI_DIR}/conf.d && \
    mkdir -p "${PHP_CONF_DIR}" && \
    echo "Configuring target container php limits..." && \
    export DOCKER_PHP_UPLOAD_MAX_FILESIZE=${DOCKER_PHP_UPLOAD_MAX_FILESIZE:-128M} && \
    echo "  Setting max upload size to ${DOCKER_PHP_UPLOAD_MAX_FILESIZE}" && \
    echo "upload_max_filesize = ${DOCKER_PHP_UPLOAD_MAX_FILESIZE}" >> "${PHP_CONF_DIR}/99-limits.ini" && \
    export DOCKER_PHP_POST_MAX_SIZE=${DOCKER_PHP_POST_MAX_SIZE:-128M} && \
    echo "  Setting max post size to ${DOCKER_PHP_POST_MAX_SIZE}" && \
    echo "post_max_size = ${DOCKER_PHP_POST_MAX_SIZE}" >> "${PHP_CONF_DIR}/99-limits.ini" && \
    export DOCKER_PHP_MEMORY_LIMIT=${DOCKER_PHP_MEMORY_LIMIT:-128M} && \
    echo "  Setting memory limit to ${DOCKER_PHP_MEMORY_LIMIT}" && \
    echo "memory_limit = ${DOCKER_PHP_MEMORY_LIMIT}" >> "${PHP_CONF_DIR}/99-limits.ini" && \
    if [[ -f "/var/www/html/app-supervisord.conf" ]]; then \
    echo "  Detected supervisord app configuration. Installing conf file..."; \
    mkdir -p /etc/supervisord/conf.d; \
    cp /var/www/html/app-supervisord.conf /etc/supervisord/conf.d; \
    fi; \
    echo "done."
