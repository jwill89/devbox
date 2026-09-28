# Dotfiles starter

Your personal shell setup (aliases, prompt, small scripts) lives in its own repo, not in the devbox image, so changing an alias doesn't need an image rebuild.

To use it:

1. Create a private GitHub repo named `dotfiles`.
2. Copy this folder's files into it and push.
3. In VS Code user settings (Settings Sync carries them to every machine):

   ```jsonc
   "dotfiles.repository": "jwill89/dotfiles",
   "dotfiles.installCommand": "install.sh"
   ```

VS Code then clones the repo into every dev container and runs `install.sh`. `host/setup-ubuntu.sh` also applies it in Ubuntu on each machine.
