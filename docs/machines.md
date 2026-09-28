# Machine checklists

Docker Desktop is already installed on all three machines; `setup-host.ps1` detects that and skips it.

Any machine can go first. Whichever it is, the first machine also fills the GitHub repo and starts the first image build (see the README).

## Every machine, before running anything

- [ ] **Get all code into GitHub.** Look in Documents, Desktop, OneDrive, top-level folders on `C:`, and `%USERPROFILE%\go\src`. For each project: `git status` is clean and pushed. For a folder with no `.git`: `git init`, add a `.gitignore` (`vendor/`, `node_modules/`, `.env`), create a private repo, push.
- [ ] **SSH keys into 1Password.** Import any keys from `%USERPROFILE%\.ssh` (or wherever they are), turn on the 1Password SSH agent, and check `ssh -T git@github.com` still works. Then delete key files from synced folders like OneDrive.
- [ ] **Finish pending Windows Updates** and restart.
- [ ] **See what's installed:** from the unzipped kit, `powershell -ExecutionPolicy Bypass -File .\host\remove-old-tools.ps1 -ListOnly` lists the old toolchains, your global npm packages, and every PATH entry and folder it would offer to remove, without changing anything. Write down any global CLIs you still want.
- [ ] **VS Code Settings Sync:** do the cleanup in [vscode.md](vscode.md) on one machine, then turn Sync on everywhere so the others inherit it.

Then follow "Setting up a machine" in the README.

---

## PC

Not inspected by any session yet, so treat it like the ASUS until proven otherwise.

- [ ] Check where projects live. On the ASUS they were in OneDrive, one of them not even in git.
- [ ] Check RAM. With 16 GB or less and heavy use elsewhere, consider a `host/machines/<COMPUTERNAME>.psd1` memory cap like the ASUS has.
- [ ] If the PC is mostly for development, let Docker Desktop start with Windows (Docker Desktop → Settings → General → *Start Docker Desktop when you sign in*). Then dev mode is just opening VS Code.

---

## ASUS ROG Strix G533ZW (`JWILL-ROGLAPTOP`)

From its audit on September 27, 2026: i9-12900H, 32 GB, RTX 3070 Ti, Windows 11 Home 25H2, WSL and Docker not installed yet.

**Before setup**

- [ ] Clear the pending Windows Update ("Attention needed") and restart.
- [ ] `OneDrive\Documents\dev\uniseal-intranet`: commit and push.
- [ ] `OneDrive\Documents\Gallery Website`: **not in git.** `git init`, `.gitignore` with `vendor/`, decide whether the SQLite file in `db/` is committed or stays local, push to a private repo.
- [ ] Check `OneDrive\Documents\Contract Work` and `OneDrive\Documents\Uniseal Intranet` for code (not inspected).
- [ ] The `.ssh` folder in `OneDrive\Documents`: move the keys into 1Password, then delete that folder once the agent works.

**During setup**

- `host/machines/JWILL-ROGLAPTOP.psd1` caps WSL (and so Docker) at 12 GB, leaving the rest for games.
- In Docker Desktop, turn **off** *Start Docker Desktop when you sign in*. Use `docker desktop start` for dev, and `docker desktop stop` then `wsl --shutdown` before gaming.
- Run `winget list code`. If it shows two VS Codes (the Microsoft Store one and the regular one), uninstall the Store one.

**After a project works in its container**

- [ ] `remove-old-tools.ps1` should find: PHP 8.5.8 in `C:\Program Files\PHP`, Composer (`%APPDATA%\Composer` on PATH), Go 1.27.1 with `GOPATH`, nvm with Node 24.21.0 and 26.10.0, the empty `C:\nvm4w`, and Python Install Manager.
- [ ] Move the project folders out of OneDrive once each is confirmed in GitHub and working from `~/code`.

**Laptop settings** (quick, and independent of dev)

- [ ] Armoury Crate → Operating Mode: **Performance** plugged in, Silent on battery. Silent holds the CPU back during builds.
- [ ] Armoury Crate → GPU Mode: **Optimized** (RTX off on battery, hybrid when plugged in).
- [ ] Settings → Apps → Startup: turn off what you launch yourself (Steam, NordVPN, Razer Synapse, the THX and RZTHX helpers, Flameshot).
- [ ] Settings → System → Advanced → **Enable long paths**.
- Leave as they are: memory integrity (VBS), Defender, Panel Power Saver, Legacy DRM Compatibility off.

---

## Surface Laptop 4 (`jwillsurfacelaptop4`; `$env:COMPUTERNAME` shows `JWILLSURFACELAP`)

32 GB, so the WSL default (16 GB) is plenty and it has no machine settings file.

- [ ] **VirtualBox** is (or was) installed. Uninstall it unless you still use it; its VMs slow down once WSL2 is on.
- [ ] **Copilot CLI:** the `.copilot` folder suggests it's installed as a global npm package under nvm-windows. Removing nvm removes it. If you use it on Windows, reinstall it afterwards another way; for containers, install it from your dotfiles.
- [ ] **GitLab:** the `.gitlab` folder shows some GitLab use. Git Credential Manager signs in to GitLab too, so nothing extra is needed.
- [ ] **Database Client:** the `.dbclient` folder is the VS Code Database Client extension. Add it to `dev.containers.defaultExtensions` (see [vscode.md](vscode.md)) to have it inside containers.
- The PHP install method here is unknown (winget, zip, Herd, XAMPP or Laragon). `remove-old-tools.ps1` finds a plain install either way. If it's Herd, XAMPP or Laragon, it only reports it: dump any databases in it and copy out project folders first, then uninstall it yourself.
