<#
.SYNOPSIS
  Removes the old Windows installs of Node/nvm, Go, PHP, Composer and Python,
  plus the environment variables, PATH entries and folders they leave behind.

.DESCRIPTION
  Run this only after a real project builds, runs and passes its tests inside its
  dev container on this machine. It can't be undone.

  It shows everything it found and asks before each removal. To preview every
  question it would ask, without changing anything (no admin needed):

    powershell -ExecutionPolicy Bypass -File C:\devbox-kit\host\remove-old-tools.ps1 -ListOnly

  To remove (elevated PowerShell):

    powershell -ExecutionPolicy Bypass -File C:\devbox-kit\host\remove-old-tools.ps1

  Git for Windows, VS Code, Docker Desktop and everything else are left alone.
  Local server bundles (XAMPP, Laragon, WampServer, Herd) are only reported, never
  uninstalled here, because they can hold databases and project folders.
#>
[CmdletBinding()]
param(
  [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Text) { Write-Host ''; Write-Host "== $Text" -ForegroundColor Cyan }
function Write-Note([string]$Text) { Write-Host "   $Text" }
function Write-Warn([string]$Text) { Write-Host "   ! $Text" -ForegroundColor Yellow }

function Confirm-Choice([string]$Question) {
  if ($ListOnly) { Write-Host "   (would ask) $Question"; return $false }
  $answer = Read-Host "   $Question [y/N]"
  return ($answer -match '^(y|yes)$')
}

# Uninstall entries (Settings > Apps) whose names match these patterns.
$ProductPatterns = @(
  @{ Tool = 'nvm';      Pattern = '^NVM for Windows' },
  @{ Tool = 'Node.js';  Pattern = '^Node\.js' },
  @{ Tool = 'Go';       Pattern = '^Go Programming Language' },
  @{ Tool = 'Composer'; Pattern = '^Composer\b' },
  @{ Tool = 'PHP';      Pattern = '^PHP\b' },
  @{ Tool = 'Python';   Pattern = '^Python (\d+\.\d+|Launcher|Install Manager|Manager)' }
)

# Bundles with their own web root and database data. Reported only.
$BundlePattern = '^(XAMPP|Laragon|WampServer|Laravel Herd)'

# Folders these tools commonly leave behind.
$LeftoverFolders = @(
  'C:\nvm4w',
  (Join-Path $env:APPDATA 'npm'),
  (Join-Path $env:LOCALAPPDATA 'npm-cache'),
  (Join-Path $env:USERPROFILE 'go'),
  (Join-Path $env:LOCALAPPDATA 'go-build'),
  (Join-Path $env:APPDATA 'Composer'),
  (Join-Path $env:LOCALAPPDATA 'Composer'),
  (Join-Path $env:ProgramFiles 'PHP'),
  (Join-Path $env:ProgramFiles 'Go')
)

$EnvVars = @('NVM_HOME', 'NVM_SYMLINK', 'GOPATH', 'GOROOT', 'COMPOSER_HOME')

# PATH entries that belong to these tools.
$PathPattern = '(?i)(\\nvm|nodejs|\\npm$|\\go\\bin|\\Go\\bin|Composer|\\PHP(\\|$)|\\Python\d*(\\|$)|\\Python\\(Launcher|Python\d+))'

# ---------------------------------------------------------------------------
if (-not $ListOnly) {
  $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warn 'Run this from an elevated PowerShell, or add -ListOnly to just look.'
    exit 1
  }
  Write-Host ''
  Write-Warn 'Only continue if a project already works inside its dev container on this machine.'
  if (-not (Confirm-Choice 'Continue?')) { exit 0 }
}

# ---------------------------------------------------------------------------
Write-Step 'Installed products'
$uninstallKeys = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$products = @()
$bundles = @()
foreach ($entry in (Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue)) {
  if (-not $entry.DisplayName -or $entry.SystemComponent -eq 1) { continue }
  if ($entry.DisplayName -match $BundlePattern) { $bundles += $entry.DisplayName; continue }
  foreach ($p in $ProductPatterns) {
    if ($entry.DisplayName -match $p.Pattern) {
      $products += [pscustomobject]@{
        Tool      = $p.Tool
        Name      = $entry.DisplayName
        KeyName   = $entry.PSChildName
        Uninstall = $entry.UninstallString
        Quiet     = $entry.QuietUninstallString
      }
      break
    }
  }
}
$storeApps = @(Get-AppxPackage -Name 'PythonSoftwareFoundation.*' -ErrorAction SilentlyContinue)

if ($products.Count -eq 0 -and $storeApps.Count -eq 0) { Write-Note 'None found' }
foreach ($p in $products) { Write-Note ("[{0}] {1}" -f $p.Tool, $p.Name) }
foreach ($a in $storeApps) { Write-Note ("[Python] {0} (Microsoft Store)" -f $a.Name) }
foreach ($b in $bundles) {
  Write-Warn ("{0} is installed. This script won't touch it: it can hold MySQL data and project" -f $b)
  Write-Warn '  folders (htdocs, www). Dump its databases and copy out any projects, then uninstall it yourself.'
}

# Programs on PATH that no uninstaller owns (zip installs).
Write-Step 'Programs on PATH'
foreach ($exe in @('node.exe', 'npm.cmd', 'go.exe', 'php.exe', 'composer.bat', 'python.exe', 'py.exe')) {
  foreach ($cmd in @(Get-Command $exe -All -CommandType Application -ErrorAction SilentlyContinue)) {
    if ($cmd.Source -like '*\WindowsApps\*') { continue }   # Store aliases, handled below
    Write-Note ("{0} -> {1}" -f $exe, $cmd.Source)
  }
}

# ---------------------------------------------------------------------------
Write-Step 'Global npm packages that will disappear with Node'
$nvmHome = [Environment]::GetEnvironmentVariable('NVM_HOME', 'User')
if (-not $nvmHome) { $nvmHome = [Environment]::GetEnvironmentVariable('NVM_HOME', 'Machine') }
$nvmSymlink = [Environment]::GetEnvironmentVariable('NVM_SYMLINK', 'User')
if (-not $nvmSymlink) { $nvmSymlink = [Environment]::GetEnvironmentVariable('NVM_SYMLINK', 'Machine') }
$npmRoots = @()
if ($nvmHome -and (Test-Path $nvmHome)) {
  $npmRoots += Get-ChildItem $nvmHome -Directory -Filter 'v*' | ForEach-Object { Join-Path $_.FullName 'node_modules' }
}
$npmRoots += (Join-Path $env:APPDATA 'npm\node_modules')
$foundGlobals = $false
foreach ($root in $npmRoots) {
  if (-not (Test-Path $root)) { continue }
  $names = @()
  foreach ($d in (Get-ChildItem $root -Directory)) {
    if ($d.Name -in @('npm', 'corepack')) { continue }
    if ($d.Name -like '@*') { $names += (Get-ChildItem $d.FullName -Directory | ForEach-Object { "$($d.Name)/$($_.Name)" }) }
    else { $names += $d.Name }
  }
  if ($names.Count -gt 0) {
    $foundGlobals = $true
    Write-Note ("{0}: {1}" -f $root, ($names -join ', '))
  }
}
if ($foundGlobals) {
  Write-Warn 'Write these down. Any you still want on Windows itself (for example the Copilot CLI)'
  Write-Warn 'need another install route; inside containers, add them to a project or your dotfiles.'
} else {
  Write-Note 'None'
}

# ---------------------------------------------------------------------------
Write-Step 'Uninstall'
foreach ($p in $products) {
  if (-not (Confirm-Choice ("Uninstall {0}?" -f $p.Name))) { continue }
  if ($p.Quiet) {
    $command = $p.Quiet
  } elseif ($p.Uninstall -match '(?i)msiexec') {
    $guid = if ($p.KeyName -match '^\{[0-9A-Fa-f-]+\}$') { $p.KeyName } else { ([regex]::Match($p.Uninstall, '\{[0-9A-Fa-f-]+\}')).Value }
    $command = "msiexec.exe /x $guid /qn /norestart"
  } elseif ($p.Uninstall -match '(?i)unins\d+\.exe') {
    $command = "$($p.Uninstall) /VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
  } else {
    $command = $p.Uninstall   # no silent option known; its own window will open
  }
  Write-Note "Running: $command"
  $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList ('/d /s /c "' + $command + '"') -Wait -PassThru
  if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) { Write-Note 'Done' }
  else { Write-Warn ("Exit code {0}. Check Settings > Apps for {1}." -f $proc.ExitCode, $p.Name) }
}
foreach ($a in $storeApps) {
  if (Confirm-Choice ("Remove {0} (Microsoft Store)?" -f $a.Name)) {
    Remove-AppxPackage -Package $a.PackageFullName
    Write-Note 'Done'
  }
}

# ---------------------------------------------------------------------------
Write-Step 'Environment variables'
foreach ($scope in @('User', 'Machine')) {
  foreach ($name in $EnvVars) {
    $value = [Environment]::GetEnvironmentVariable($name, $scope)
    if ($value -and (Confirm-Choice ("Remove {0} variable {1}={2}?" -f $scope, $name, $value))) {
      [Environment]::SetEnvironmentVariable($name, $null, $scope)
    }
  }
}

Write-Step 'PATH entries'
$pathKeys = @{
  User    = @{ Hive = [Microsoft.Win32.Registry]::CurrentUser;  Sub = 'Environment' }
  Machine = @{ Hive = [Microsoft.Win32.Registry]::LocalMachine; Sub = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment' }
}
foreach ($scope in @('User', 'Machine')) {
  $key = $pathKeys[$scope].Hive.OpenSubKey($pathKeys[$scope].Sub, (-not $ListOnly))
  # Read the raw value so %VARIABLES% inside PATH survive the rewrite.
  $raw = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
  $keep = @()
  $changed = $false
  foreach ($entry in ($raw -split ';')) {
    if ($entry -eq '') { continue }
    $expanded = [Environment]::ExpandEnvironmentVariables($entry).Trim().Trim('"')
    $isTool = $expanded -match $PathPattern
    $isDead = ($expanded -eq '') -or -not (Test-Path -LiteralPath $expanded)
    if (($isTool -or $isDead) -and (Confirm-Choice ("Remove {0} PATH entry {1}{2}?" -f $scope, $entry, $(if ($isDead) { ' (folder is gone)' } else { '' })))) {
      $changed = $true
      continue
    }
    $keep += $entry
  }
  if ($changed) {
    $key.SetValue('Path', ($keep -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)
    Write-Note "$scope PATH updated"
  }
  $key.Close()
}

# ---------------------------------------------------------------------------
Write-Step 'Leftover folders'
$folders = @($LeftoverFolders)
if ($nvmHome) { $folders += $nvmHome }
if ($nvmSymlink) { $folders += $nvmSymlink }
$goSrc = Join-Path $env:USERPROFILE 'go\src'
if ((Test-Path -LiteralPath $goSrc) -and (Get-ChildItem -LiteralPath $goSrc -ErrorAction SilentlyContinue)) {
  Write-Warn "$goSrc has files in it. If that's code from old GOPATH-style projects, push it to GitHub before deleting the go folder."
}
foreach ($f in ($folders | Select-Object -Unique)) {
  if (-not (Test-Path -LiteralPath $f)) { continue }
  if (Confirm-Choice "Delete $f ?") {
    Remove-Item -LiteralPath $f -Recurse -Force
    Write-Note 'Deleted'
  }
}

# ---------------------------------------------------------------------------
Write-Step 'Done'
if ($ListOnly) {
  Write-Note 'List only. Nothing was changed. Run again without -ListOnly, as administrator, to remove.'
  exit 0
}
Write-Note 'Restart Windows (or sign out and in) so every app sees the new PATH.'
Write-Note 'Then, in a new PowerShell, these should all say "not recognized": node, go, php, composer'
Write-Note 'If "python" opens the Microsoft Store, turn off its App execution aliases in'
Write-Note 'Settings > Apps > Advanced app settings > App execution aliases.'
