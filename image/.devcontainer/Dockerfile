# devbox: the shared dev environment image.
# CI builds it once per PHP version and pushes it to ghcr.io/jwill89/devbox.
# Node, Go and the GitHub CLI are added afterwards by the features in devcontainer.json.

ARG PHP_VERSION=8.5
FROM mcr.microsoft.com/devcontainers/php:${PHP_VERSION}-trixie

# PHP extensions. SQLite (pdo_sqlite, sqlite3) is already compiled into the base image.
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions pdo_mysql mysqli pdo_pgsql intl zip bcmath gd \
 && cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

# Database clients and Python.
# postgresql-client comes from the PostgreSQL project's apt repo so it matches the
# server major in the postgres template. Debian's own client is older, and an older
# pg_dump refuses to dump a newer server. Bump both together.
ARG PG_CLIENT_MAJOR=18
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends postgresql-common \
 && /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      "postgresql-client-${PG_CLIENT_MAJOR}" default-mysql-client sqlite3 \
      python3 python3-venv python3-pip pipx \
 && rm -rf /var/lib/apt/lists/*

# Debian's mysql client is MariaDB's. Since MariaDB 11.4 it refuses self-signed server
# certificates, which is what the local MySQL container uses. Local dev only.
RUN mkdir -p /etc/mysql/mariadb.conf.d \
 && printf '[client]\nssl-verify-server-cert=off\n' > /etc/mysql/mariadb.conf.d/60-devbox-client.cnf

# Xdebug is loaded but idle, because debug mode slows every composer and phpunit run.
# In a terminal, `xdebug-on` turns it on for that shell and `xdebug-off` turns it off.
RUN printf 'xdebug.mode=off\nxdebug.start_with_request=yes\nxdebug.client_host=localhost\nxdebug.client_port=9003\n' \
      > "$PHP_INI_DIR/conf.d/zz-devbox-xdebug.ini" \
 && printf '%s\n' \
      '' \
      '# devbox: Xdebug switches' \
      'xdebug-on()  { export XDEBUG_MODE="${1:-debug,develop}"; echo "XDEBUG_MODE=$XDEBUG_MODE"; }' \
      'xdebug-off() { unset XDEBUG_MODE; echo "Xdebug idle"; }' \
      >> /etc/bash.bashrc

# Mount points for the shared cache volumes (see "mounts" in devcontainer.json).
# They must exist and belong to vscode here, so new volumes start with that owner.
RUN mkdir -p /home/vscode/.cache /home/vscode/.local/share/pnpm \
 && chown -R vscode:vscode /home/vscode/.cache /home/vscode/.local
