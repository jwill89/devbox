# devbox

One dev environment for every machine: the PC, the ASUS ROG laptop, the Surface Laptop 4, and whatever comes next. It merges the plans from the three per-machine sessions of September 27, 2026.

Your tools live in one container image that's built on GitHub. Every machine runs that same image, so updating it once updates everything. Windows only hosts it.

## How it fits together

| Layer | What it is | Where it's defined | How often it changes |
|---|---|---|---|
| **Host** | Windows 11, WSL2 with Ubuntu, Docker Desktop, Git for Windows, VS Code with Dev Containers | `host/setup-host.ps1` | Rarely |
| **Environment** | The devbox image: PHP, Node, Go, Python, database clients, VS Code extensions and settings | `image/` in this repo, built by GitHub Actions into `ghcr.io/jwill89/devbox` | When you want, plus an automatic weekly patch rebuild |
| **Project** | A small `.devcontainer/` folder committed in each project, pointing at the image | Copied from `templates/` | Per project |

Code lives in Ubuntu at `~/code` on each machine. Git is the only thing that syncs code between machines, so push before you switch.

## What's in the image

| | Version | Notes |
|---|---|---|
| PHP | 8.5 (`:php8.5`, also `:latest`); 8.4 (`:php8.4`) | Composer, Xdebug (idle until `xdebug-on`), dev `php.ini`. Extensions include pdo_mysql, mysqli, pdo_pgsql, pdo_sqlite, intl, zip, bcmath, gd |
| Node | 24 (LTS), via nvm | pnpm 12. A project's `.nvmrc` picks another version automatically |
| Go | 1.27.x | gopls, dlv, staticcheck, golangci-lint |
| Python | 3 (Debian's) | venv, pip, pipx. `requirements.txt` gets a `.venv` automatically |
| Database clients | psql 18, mysql (MariaDB client), sqlite3 | |
| Other | GitHub CLI (`gh`) | |
| VS Code | Vue, ESLint, Prettier, Vitest, Go, Intelephense, PHP Debug, PHPUnit, Python, EditorConfig | Plus file-watcher exclusions and one formatter per language |

The weekly rebuild picks up patch releases within those lines. Moving to a new line (Node 26, Go 1.28) is always a deliberate one-line change; see [Updating](#updating).

## Daily use

**Start dev mode:** `docker desktop start` in any terminal (or let Docker Desktop start with Windows on the PC). In VS Code, **File → Open Recent** and pick a project marked **[Dev Container]**. For a project you haven't opened yet: in Ubuntu, `cd ~/code/<project> && code .`, then **Reopen in Container**.

**Stop dev mode:** close the VS Code windows, then `docker desktop stop` and `wsl --shutdown` to give all the memory back. On the ASUS, do this before gaming.

**Debug PHP:** in the container terminal run `xdebug-on`, start VS Code's "Listen for Xdebug", run the request or test. `xdebug-off` when you're done. Leaving Xdebug on slows every composer and phpunit run, which is why it's idle by default.

**Databases:** the MySQL and Postgres templates start a database next to the app. Inside the container it's host `db`; from Windows tools like DBeaver it's `localhost:3306` or `localhost:5432` while the project is open. User, password and database are all `app`. Data lives in a Docker volume per project, so it survives "Rebuild Container" but not deleting the volume.

**Switching machines:** commit and push, then `git pull` on the other machine. `.env` files don't go through git: keep a `.env.example` in each repo (post-create copies it to `.env`) and keep real secrets in 1Password.

## Starting or moving a project

```bash
# New project
mkdir -p ~/code/myapp && cd ~/code/myapp && git init
cp -r ~/code/devbox/templates/mysql/.devcontainer .    # or sqlite / postgres
code .                                                  # then "Reopen in Container"

# Existing project
cd ~/code && git clone https://github.com/jwill89/<repo>.git && cd <repo>
cp -r ~/code/devbox/templates/sqlite/.devcontainer .
code .
```

Commit `.devcontainer/` so every machine opens the project the same way. On first open, `post-create.sh` installs whatever the project needs: `.nvmrc`, `pnpm-lock.yaml` / `package-lock.json`, `composer.json`, `go.mod`, `requirements.txt`, `.env.example`.

- **PHP 8.4 instead of 8.5:** change the image tag to `php8.4` in `devcontainer.json` (SQLite template) or `compose.yaml` (the others).
- **Different Node:** add `.nvmrc` with the version, e.g. `26`.
- **Different database password or name:** edit `compose.yaml`. These are local-only credentials.

## Updating

**The environment.** Edit `image/`, push to `main`. GitHub Actions builds and tests both PHP versions and pushes them (watch the repo's Actions tab). Then on each machine:

```bash
docker pull ghcr.io/jwill89/devbox:php8.5
```

and run **Dev Containers: Rebuild Container** in each project when convenient. Every Monday CI also rebuilds from scratch for OS security fixes and patch releases, so pulling now and then keeps a machine current even if you changed nothing.

**Version bumps** are one-line changes:

| To move | Change | Note |
|---|---|---|
| Node 24 → 26 | `"version"` under the node feature in `image/.devcontainer/devcontainer.json` | Node 26 becomes LTS in October 2026. Projects can use it sooner via `.nvmrc` |
| Go 1.27 → 1.28 | `"version"` under the go feature | |
| pnpm | `pnpmVersion` and `DEVBOX_PNPM_VERSION` in the same file | Keep them equal |
| Add PHP 8.6, drop 8.4 | the `matrix` in `.github/workflows/build.yml` | Then change tags in projects that should move |
| Postgres 18 → 19 | `postgres:` in `templates/postgres/.devcontainer/compose.yaml` **and** `PG_CLIENT_MAJOR` in `image/.devcontainer/Dockerfile` | 19 is due in October 2026. Existing projects need a dump and restore to move majors |
| MySQL | `mysql:` in `templates/mysql/.devcontainer/compose.yaml` | Stay on the LTS line, not `latest` |

**Rolling back.** Every build is also tagged with its date, like `php8.5-2026.10.05`. If a new image breaks something, put that tag in the project's `devcontainer.json` or `compose.yaml`, rebuild, and fix `image/` at leisure.

**Dependabot** opens pull requests when a dev container feature or a GitHub Action gets a new major version. CI tests the PR without publishing it. Merge to ship.

**Templates** are copied into projects, so a template change only reaches the projects you copy it into.

**The host.** `winget upgrade --all` and `wsl --update` now and then. Docker Desktop and VS Code update themselves. Re-running `host/setup-host.ps1` is always safe.

## Setting up a machine

Before touching any machine, read its section in [docs/machines.md](docs/machines.md). The first job on every machine is making sure its code is pushed to GitHub.

### First machine (once)

1. Create an **empty private** GitHub repo named `devbox` (no README, no .gitignore).
2. Unzip this kit somewhere like `C:\devbox-kit`, open PowerShell **as administrator**, and run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\devbox-kit\host\setup-host.ps1
   ```
   It stops to ask for a restart, a sign-out, or creating your Ubuntu user. Each time, do that and run it again until it says **Done**. On this first run it fills the empty repo from the kit and pushes, which starts the first image build.
3. Open Docker Desktop once and accept its terms (skip if you already have).
4. Wait for the first build in the repo's **Actions** tab to go green. If no run appears, open **Actions → Build devbox image → Run workflow**.
5. **Make the image public** (one time): on GitHub, open your profile → **Packages** → **devbox** → **Package settings** → **Danger Zone** → **Change visibility** → **Public**. No machine then needs a token to pull. GitHub says a public package can't be made private again, which is fine since it only contains public tools. If GitHub won't offer the option, making the `devbox` repo itself public works too; nothing in it is secret.
6. In Ubuntu: `docker pull ghcr.io/jwill89/devbox:php8.5`
7. Move one real project in (see above) and confirm it builds, runs and passes its tests in the container.
8. Remove the old Windows toolchains. First preview every question it would ask, without changing anything:
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\devbox-kit\host\remove-old-tools.ps1 -ListOnly
   ```
   Then run the same command without `-ListOnly` in an administrator PowerShell. It asks before every removal. It only reports XAMPP, Laragon, WampServer or Herd, since those can hold databases and project folders; back those up and uninstall them yourself.

### Every other machine

1. On GitHub, **devbox → Code → Download ZIP**, unzip, and run `host\setup-host.ps1` the same way. This time it clones the repo into `~/code/devbox` and pulls the image.
2. Open Docker Desktop once and accept its terms (skip if you already have).
3. Clone your projects into `~/code`, open each in its container, and run its tests.
4. Run `remove-old-tools.ps1` from the unzipped folder the same way as step 8 above: `-ListOnly` first, then for real.

### A new machine later

Same as "every other machine." If it needs settings of its own (like a memory cap), add `host/machines/<COMPUTERNAME>.psd1`, modeled on the ASUS one. Use the name `$env:COMPUTERNAME` prints in PowerShell; Windows cuts it to 15 characters, so the Surface is `JWILLSURFACELAP`.

## Decisions

Made across the three sessions and confirmed by you. Changing one is fine; this is the record of why things are the way they are.

| Decision | Why |
|---|---|
| One shared image, built by CI | Identical tools on every machine; update once. Beats three installs that drift apart |
| Public image, private repo | No token on any machine. The image only holds public tools |
| Docker Desktop | Handles WSL integration and credentials for you. Free for personal use |
| Code in Ubuntu's `~/code`, not `C:` or OneDrive | Mounting `C:` into containers is slow, and OneDrive syncing `.git` and `node_modules` corrupts things |
| Git over HTTPS with Git Credential Manager | Sign in once per machine; it flows into Ubuntu and every container. 1Password's SSH agent covers SSH to servers |
| Versions pinned to a line (Node 24, Go 1.27, pnpm 12) | The weekly rebuild can't surprise you with a new major |
| Dated image tags | One-line rollback |
| Xdebug installed but idle | Debug mode slows every CLI run |
| No Docker CLI inside containers | Mounting Docker's socket would let any npm or Composer install script control Docker. Use Docker from Ubuntu |
| Python in the image only | Removed from Windows with the other toolchains |
| Personal extensions and aliases stay out of the image | They go in `dev.containers.defaultExtensions` and a dotfiles repo, so changing them needs no rebuild ([docs/vscode.md](docs/vscode.md)) |
| Templates copied, no helper script | You prefer common tools; `cp -r` is enough |
| WSL memory: default (half of RAM), ASUS capped at 12 GB | Room for games on the ASUS; plenty everywhere else |
| Windows toolchains removed last, by a separate script | Nothing gets uninstalled until the new setup is proven on that machine |
| Windows PATH left visible inside Ubuntu | Dev tools run in containers, which don't see it. Hiding it would break `code .` in Ubuntu |

## When something goes wrong

- **`docker: command not found` in Ubuntu:** Docker Desktop isn't running, or Settings → Resources → WSL integration → Ubuntu is off.
- **`docker pull` says denied or not found:** the first build hasn't finished, or the package is still private (step 5 above).
- **File watching or builds are slow:** the project is probably under `/mnt/c`. Clone it into `~/code` instead.
- **"ENOSPC: System limit for number of file watchers reached":** in Ubuntu run `echo fs.inotify.max_user_watches=524288 | sudo tee /etc/sysctl.d/60-watches.conf`, then `wsl --shutdown`.
- **A container won't start after an image update:** pin the previous dated tag (see Rolling back) and check the Actions log for the build that changed it.
- **Vue projects and TypeScript 7:** see [docs/vscode.md](docs/vscode.md).

## What's in this repo

```
image/.devcontainer/           the environment: Dockerfile + devcontainer.json
templates/{sqlite,mysql,postgres}/.devcontainer/
                               copy one into each project (post-create.sh is the same in all three)
host/setup-host.ps1            Windows side, re-runnable
host/setup-ubuntu.sh           Ubuntu side, called by setup-host.ps1
host/remove-old-tools.ps1      removes old Windows Node/nvm, Go, PHP, Composer, Python
host/machines/                 per-machine settings, named after COMPUTERNAME
dotfiles-starter/              seed for a separate jwill89/dotfiles repo
docs/machines.md               checklists for the PC, ASUS and Surface
docs/vscode.md                 Windows-side VS Code setup and cleanup
.github/                       image build workflow and Dependabot
```
