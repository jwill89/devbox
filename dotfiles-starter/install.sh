#!/usr/bin/env bash
# Links these dotfiles into $HOME. Runs in Ubuntu (setup-ubuntu.sh calls it) and in every
# dev container (VS Code's "dotfiles.repository" setting clones this repo and runs it).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"

ln -sf "$here/bash_aliases" "$HOME/.bash_aliases"

# Most .bashrc files already load ~/.bash_aliases. Make sure this one does.
if ! grep -q 'bash_aliases' "$HOME/.bashrc" 2>/dev/null; then
  printf '\n[ -f ~/.bash_aliases ] && . ~/.bash_aliases\n' >> "$HOME/.bashrc"
fi
