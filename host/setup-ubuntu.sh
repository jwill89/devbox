#!/usr/bin/env bash
# Ubuntu (WSL) side of devbox setup. setup-host.ps1 runs this from the devbox folder.
# Safe to run again by hand:  cd ~/code/devbox && bash host/setup-ubuntu.sh
#
# 1. Updates Ubuntu and installs git
# 2. Points git at Git for Windows' Credential Manager and fills in your name/email
# 3. Creates ~/code and clones jwill89/devbox into ~/code/devbox
#    (first machine only: if that repo is empty, fills it from this folder and pushes)
# 4. Clones jwill89/dotfiles into ~/.dotfiles if that repo exists, and runs its install.sh
# 5. Checks Docker works from Ubuntu and pulls the devbox image
set -euo pipefail

KIT_DIR="$(pwd -P)"
GITHUB_USER="jwill89"
DEVBOX_URL="https://github.com/${GITHUB_USER}/devbox.git"
DOTFILES_URL="https://github.com/${GITHUB_USER}/dotfiles.git"
CODE_DIR="$HOME/code"
DEVBOX_DIR="$CODE_DIR/devbox"
IMAGE="ghcr.io/${GITHUB_USER}/devbox:php8.5"
GCM_WIN_PATH="/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe"
WIN_GIT="/mnt/c/Program Files/Git/cmd/git.exe"

step() { printf '\n== %s\n' "$1"; }
note() { printf '   %s\n' "$1"; }
warn() { printf '   ! %s\n' "$1"; }

step "Ubuntu packages (asks for your Linux password)"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install git curl ca-certificates

step "Git"
if [ -f "$GCM_WIN_PATH" ]; then
  # The escaped space is intentional: git runs the helper through a shell.
  git config --global credential.helper '/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe'
  note "Signing in to GitHub uses Git Credential Manager from Windows."
else
  warn "Git for Windows isn't installed, so git in Ubuntu has no credential helper."
  warn "Install it (setup-host.ps1 does) and run this again."
  exit 1
fi
for key in user.name user.email; do
  if [ -z "$(git config --global "$key" || true)" ]; then
    value=""
    if [ -f "$WIN_GIT" ]; then
      value="$("$WIN_GIT" config --global "$key" 2>/dev/null | tr -d '\r' || true)"
    fi
    if [ -z "$value" ]; then
      read -r -p "   Git $key: " value
    fi
    git config --global "$key" "$value"
  fi
  note "$key = $(git config --global "$key")"
done
git config --global init.defaultBranch main

# shellcheck disable=SC2088  # display text, not a path
step "~/code and the devbox repo"
mkdir -p "$CODE_DIR"
if [ -d "$DEVBOX_DIR/.git" ]; then
  if git -C "$DEVBOX_DIR" ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
    git -C "$DEVBOX_DIR" pull --ff-only origin main || warn "Couldn't fast-forward ~/code/devbox. Check it with: git -C ~/code/devbox status"
  fi
else
  note "Cloning $DEVBOX_URL (a browser window may open to sign in to GitHub)..."
  if ! git clone "$DEVBOX_URL" "$DEVBOX_DIR"; then
    warn "Couldn't clone $DEVBOX_URL."
    warn "First machine? Create an empty private repository named devbox on GitHub"
    warn "(no README, no .gitignore), then run this again."
    exit 1
  fi
fi

if ! git -C "$DEVBOX_DIR" rev-parse --verify --quiet HEAD >/dev/null; then
  # First machine: the GitHub repo is empty, so fill it from the kit this ran from.
  if [ ! -f "$KIT_DIR/image/.devcontainer/devcontainer.json" ]; then
    warn "The devbox repo is empty. Run setup-host.ps1 from the unzipped kit to fill it."
    exit 1
  fi
  note "The devbox repo is empty. Adding the kit from $KIT_DIR..."
  (cd "$KIT_DIR" && tar --exclude=.git -cf - .) | (cd "$DEVBOX_DIR" && tar -xf -)
  # Files copied from a Windows drive arrive marked executable. Reset the modes.
  find "$DEVBOX_DIR" -path "$DEVBOX_DIR/.git" -prune -o -type d -exec chmod 755 {} +
  find "$DEVBOX_DIR" -path "$DEVBOX_DIR/.git" -prune -o -type f -exec chmod 644 {} +
  find "$DEVBOX_DIR" -path "$DEVBOX_DIR/.git" -prune -o -type f -name '*.sh' -exec chmod 755 {} +
  git -C "$DEVBOX_DIR" add -A
  git -C "$DEVBOX_DIR" commit -q -m "Add devbox kit"
  git -C "$DEVBOX_DIR" branch -M main
fi
# Also covers a first push that failed on an earlier run (sign-in cancelled, network).
if ! git -C "$DEVBOX_DIR" ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
  note "Pushing the kit to GitHub..."
  git -C "$DEVBOX_DIR" push -u origin main
  note "Pushed. GitHub Actions is now building the image (repo > Actions tab)."
fi
note "devbox repo: ~/code/devbox"

step "Dotfiles (optional)"
if [ -d "$HOME/.dotfiles/.git" ]; then
  git -C "$HOME/.dotfiles" pull --ff-only || warn "Couldn't fast-forward ~/.dotfiles"
elif git ls-remote "$DOTFILES_URL" >/dev/null 2>&1; then
  git clone -q "$DOTFILES_URL" "$HOME/.dotfiles"
fi
if [ -f "$HOME/.dotfiles/install.sh" ]; then
  bash "$HOME/.dotfiles/install.sh"
  note "Applied ~/.dotfiles"
else
  note "No ${GITHUB_USER}/dotfiles repo yet. That's fine (see dotfiles-starter in the devbox repo)."
fi

step "Docker"
if command -v docker >/dev/null 2>&1 && docker version >/dev/null 2>&1; then
  note "Docker works from Ubuntu."
  if docker pull "$IMAGE"; then
    note "Pulled $IMAGE"
  else
    warn "Couldn't pull $IMAGE. If the first image build hasn't finished yet, that's expected."
    warn "Check the repo's Actions tab, and that the package is public (see README)."
  fi
else
  warn "Docker isn't reachable from Ubuntu yet."
  warn "Open Docker Desktop, accept its terms, and turn on Settings > Resources > WSL integration > Ubuntu."
  warn "Then check with: docker version"
fi

step "Ubuntu side done"
