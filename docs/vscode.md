# VS Code

## What goes where

| Kind | Where it's installed | How |
|---|---|---|
| Language tools: PHP, Go, Vue, ESLint, Prettier, Vitest, PHPUnit, Python | Inside every dev container | The devbox image. Nothing to do |
| Your personal extras: Claude Code, GitLens, Database Client... | Inside every dev container | `dev.containers.defaultExtensions` in your user settings |
| UI only: theme, icons, one keymap, Dev Containers, WSL, Remote - SSH | Windows | Install normally; Settings Sync carries them |

Language extensions installed on Windows do nothing for containerized projects. They only complain when you open a plain local folder, so remove them there.

## User settings

Add these to your user `settings.json`. With Settings Sync on, every machine gets them.

```jsonc
// Installed in every dev container, on top of what the image brings
"dev.containers.defaultExtensions": [
  "anthropic.claude-code",
  "eamodio.gitlens",
  "cweijan.vscode-database-client2"
],

// Your shell setup in every dev container (see dotfiles-starter/ in this repo)
"dotfiles.repository": "jwill89/dotfiles",
"dotfiles.installCommand": "install.sh"
```

Formatting on save is left to you (`"editor.formatOnSave": true`). The image already sets one formatter per language, so turning it on won't fight itself. On older projects it reformats whole files on first save, so commit that separately.

## Cleanup (from the ASUS audit)

The ASUS had 106 extensions. With Settings Sync, cleaning up on one machine cleans up all of them.

**Settings to fix**

- Remove `"eslint.nodePath": "/node_modules/"`. It points at `C:\node_modules`.
- Remove `"phpsab.executablePathCBF"`. It points to a Gallery folder in OneDrive that no longer exists.
- Remove `"phpCodeStandardSelector.executablePathCS"`. That extension isn't installed.
- Change `"phpsab.snifferMode": "onType"` to `"onSave"`. It currently runs phpcs on every keystroke.
- Remove `"intelephense.environment.phpVersion": "8.5.7"`. Intelephense's default covers 8.5, and a pinned patch version goes stale.

**Extensions to remove**

| Remove | Reason |
|---|---|
| `zobo.php-intellisense` | Deprecated second PHP language server; conflicts with Intelephense |
| `emallin.phpunit` | Duplicate of `recca0120.vscode-phpunit` |
| `hbenl.vscode-test-explorer`, `ms-vscode.test-adapter-converter` | Old test UI; VS Code's Testing view replaces them |
| `waderyan.gitblame`, `donjayamanne.githistory` | GitLens does both |
| `bracketpaircolordlw.bracket-pair-color-dlw` | Built in (`editor.bracketPairColorization`) |
| `formulahendry.auto-rename-tag` | Built in (`editor.linkedEditing`) |
| 3 of the 4 keymaps (`isudox.vscode-jetbrains-keybindings`, `k--kato.intellij-idea-keybindings`, `zewenn.intellij-ify`, `ms-vscode.notepadplusplus-keybindings`) | Keymaps conflict. Keep one |
| `pkief.material-icon-theme`, `soulfriends.atom-file-icon-with-jetbrains`, `trinm1709.dracula-theme-from-intellij` | Not in use; settings use `vscode-icons` and JetBrains Darcula |
| `ms-dotnettools.csdevkit`, `ms-dotnettools.csharp`, `ms-toolsai.jupyter*` | Heavy and not your stack. Keep only if you use C# or notebooks |
| One of `anthropic.claude-code` / `andrepimenta.claude-code-chat` | Two Claude integrations |
| Windows copies of Go, PHP, Vue, ESLint and similar language extensions | The image provides them inside containers |

## TypeScript 7 and Vue (as of September 2026)

TypeScript 7.0, the native Go port, went stable in July 2026 but has no programmatic API yet. Vue's tooling (Vue - Official, `vue-tsc`) and typescript-eslint still need TypeScript 6, so Vue projects stay on TS 6 for now. If VS Code is using the TS 7 language server in a Vue project, switch it back to the workspace's TypeScript 6. The image deliberately doesn't include the TS 7 extension.

TypeScript 7.1, which adds the API, has a beta planned for October 6 and a stable release targeted for November 24, 2026. Revisit then.
