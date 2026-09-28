#!/usr/bin/env bash
# Runs once when this project's dev container is created (and again after a rebuild).
# Installs the project's dependencies based on the files it finds. Safe to re-run.
set -eo pipefail
cd "$(dirname "$0")/.."

# .env files never travel through git. Start from the example if there is one.
if [ -f .env.example ] && [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example. Fill in any secrets it needs."
fi

# Node: the image defaults to Node 24. A project can pin another version in .nvmrc.
if [ -f .nvmrc ]; then
  # nvm is a shell function, so it has to be loaded first.
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  nvm install
  nvm alias default "$(nvm current)"
  if ! command -v pnpm >/dev/null 2>&1 && [ -f pnpm-lock.yaml ]; then
    npm install -g "pnpm@${DEVBOX_PNPM_VERSION:-12}"
  fi
fi

if [ -f pnpm-lock.yaml ]; then
  pnpm install --frozen-lockfile
elif [ -f package-lock.json ]; then
  npm ci
elif [ -f yarn.lock ]; then
  echo "yarn.lock found. Yarn isn't in the image; run 'npm install -g yarn' then 'yarn install'."
elif [ -f package.json ]; then
  npm install
fi

if [ -f composer.json ]; then
  composer install --no-interaction
fi

if [ -f go.mod ]; then
  go mod download
fi

if [ -f requirements.txt ]; then
  python3 -m venv .venv
  .venv/bin/pip install -r requirements.txt
fi
