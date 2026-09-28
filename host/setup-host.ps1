<#
.SYNOPSIS
  Sets up, or updates, the Windows side of devbox on this machine.

.DESCRIPTION
  Run it from an elevated Windows PowerShell (not ISE), in the devbox folder:

    powershell -ExecutionPolicy Bypass -File .\host\setup-host.ps1

  It is safe to run again at any time. Each step checks what is already done.
  It sometimes stops and asks you to restart or sign in, then run it again.

  What it does, in order:
    1. Reports this machine (model, CPU, RAM, Windows build)
    2. Installs or updates WSL
    3. Updates %UserProfile%\.wslconfig (merges; never overwrites your other settings)
    4. Installs Git for Windows, VS Code and Docker Desktop with winget
    5. Installs the VS Code Dev Containers and WSL extensions
    6. Installs Ubuntu in WSL and makes it the default distro
    7. Runs host/setup-ubuntu.sh inside Ubuntu (git, ~/code, the devbox repo, Docker check)

  It never uninstalls anything. Removing the old Windows toolchains is a separate
  script, remove-old-tools.ps1, for after a project works in its container.

  Per-machine settings live in host\machines\<COMPUTERNAME>.psd1 (optional).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = '1'   # makes wsl.exe print UTF-8 instead of UTF-16
$KitRoot = Split-Path -Parent $PSScriptRoot

function Write-Step([string]$Text) { Write-Host ''; Write-Host "== $Text" -ForegroundColor Cyan }
function Write-Note([string]$Text) { Write-Host "   $Text" }
function Write-Warn([string]$Text) { Write-Host "   ! $Text" -ForegroundColor Yellow }
function Stop-ForNow([string]$Text) {
  Write-Host ''
  Write-Host ">> $Text" -ForegroundColor Green
  Write-Host '>> Then run this script again. It picks up where it left off.' -ForegroundColor Green
  exit 0
}

function Update-SessionPath {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
              [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Install-WingetPackage([string]$Id, [string]$Name) {
  winget list --id $Id --exact --accept-source-agreements | Out-Null
  if ($LASTEXITCODE -eq 0) { Write-Note "$Name is installed"; return }
  Write-Note "Installing $Name..."
  winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -eq -1978335991 -or $LASTEXITCODE -eq 3010) {   # 0x8A150109: restart required
    Stop-ForNow "$Name is installed but needs a restart. Restart Windows."
  }
  if ($LASTEXITCODE -ne 0) { throw "winget could not install $Name ($Id). Exit code $LASTEXITCODE." }
  Update-SessionPath
}

# Sets key=value inside [section] of an INI-style list of lines. Adds the section if needed.
function Set-IniValue {
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [string]$Section,
    [string]$Key,
    [string]$Value
  )
  $inSection = $false
  $sectionFound = $false
  $insertAt = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    $t = $Lines[$i].Trim()
    if ($t -match '^\[(.+)\]$') {
      if ($inSection) { break }
      $inSection = ($Matches[1].Trim() -ieq $Section)
      if ($inSection) { $sectionFound = $true; $insertAt = $i + 1 }
      continue
    }
    if ($inSection) {
      if ($t -match '^([^=#;]+?)\s*=' -and $Matches[1].Trim() -ieq $Key) {
        $Lines[$i] = "$Key=$Value"
        return
      }
      if ($t -ne '') { $insertAt = $i + 1 }
    }
  }
  if (-not $sectionFound) {
    if ($Lines.Count -gt 0 -and $Lines[$Lines.Count - 1].Trim() -ne '') { $Lines.Add('') }
    $Lines.Add("[$Section]")
    $Lines.Add("$Key=$Value")
    return
  }
  $Lines.Insert($insertAt, "$Key=$Value")
}

# ---------------------------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Warn 'Run this from an elevated PowerShell (right-click PowerShell > Run as administrator).'
  exit 1
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Warn 'winget is missing. Update "App Installer" from the Microsoft Store, then run this again.'
  exit 1
}

# Optional per-machine settings, e.g. host\machines\JWILL-ROGLAPTOP.psd1
$machine = @{}
$machineFile = Join-Path $PSScriptRoot ("machines\{0}.psd1" -f $env:COMPUTERNAME)
if (Test-Path $machineFile) { $machine = Import-PowerShellDataFile $machineFile }

# ---------------------------------------------------------------------------
Write-Step 'This machine'
$cs  = Get-CimInstance Win32_ComputerSystem
$os  = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB)
Write-Note ("{0}: {1} {2}" -f $env:COMPUTERNAME, $cs.Manufacturer, $cs.Model)
Write-Note ("{0} ({1} cores, {2} threads)" -f $cpu.Name.Trim(), $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)
Write-Note ("{0} GB RAM, {1} build {2}" -f $ramGB, $os.Caption, $os.BuildNumber)
if (Test-Path $machineFile) { Write-Note "Machine settings: $machineFile" }
else { Write-Note 'No machine settings file (host\machines). Using defaults.' }
if (-not $cs.HypervisorPresent -and -not $cpu.VirtualizationFirmwareEnabled) {
  Write-Warn 'Virtualization looks off in the BIOS/UEFI. WSL2 needs it.'
}
if (Test-Path (Join-Path $env:ProgramFiles 'Oracle\VirtualBox')) {
  Write-Warn 'VirtualBox is installed. Its VMs run slower once WSL2 is on. Uninstall it if you no longer use it.'
}

# ---------------------------------------------------------------------------
Write-Step 'WSL'
$vmp = (Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State
wsl.exe --version | Out-Null
$wslOk = ($LASTEXITCODE -eq 0)
if ($vmp -ne 'Enabled' -or -not $wslOk) {
  Write-Note 'Installing WSL...'
  wsl.exe --install --no-distribution
  Stop-ForNow 'WSL is installed. Restart Windows.'
}
Write-Note 'Updating WSL...'
wsl.exe --update

# ---------------------------------------------------------------------------
Write-Step '.wslconfig'
$wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
$lines = New-Object 'System.Collections.Generic.List[string]'
if (Test-Path $wslConfig) { foreach ($l in (Get-Content $wslConfig)) { $lines.Add($l) } }
$before = $lines -join "`n"

# New virtual disks give space back to Windows when files are deleted.
Set-IniValue -Lines $lines -Section 'experimental' -Key 'sparseVhd' -Value 'true'
if ($machine.ContainsKey('WslMemoryGB')) {
  # Docker Desktop's containers run in this same VM, so this caps them too.
  Set-IniValue -Lines $lines -Section 'wsl2' -Key 'memory' -Value ('{0}GB' -f $machine.WslMemoryGB)
}

if (($lines -join "`n") -ne $before) {
  if (Test-Path $wslConfig) {
    $backup = '{0}.bak-{1}' -f $wslConfig, (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item $wslConfig $backup
    Write-Note "Backed up the old file to $backup"
  }
  Set-Content -Path $wslConfig -Value $lines -Encoding Ascii
  Write-Note 'Updated. It takes effect after: wsl --shutdown'
} else {
  Write-Note 'Already up to date'
}
$memLine = $lines | Where-Object { $_ -match '^\s*memory\s*=' } | Select-Object -First 1
if ($memLine) { Write-Note ("WSL memory cap: {0}" -f $memLine.Trim()) }
else { Write-Note ("WSL memory cap: WSL default, half of RAM (about {0} GB)" -f [math]::Floor($ramGB / 2)) }

# ---------------------------------------------------------------------------
Write-Step 'Windows apps'
Install-WingetPackage 'Git.Git' 'Git for Windows (its Credential Manager signs git in, in Ubuntu and in containers)'
Install-WingetPackage 'Microsoft.VisualStudioCode' 'VS Code'
Install-WingetPackage 'Docker.DockerDesktop' 'Docker Desktop'

$addedToDockerUsers = $false
try {
  Add-LocalGroupMember -Group 'docker-users' -Member ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME) -ErrorAction Stop
  $addedToDockerUsers = $true
} catch {
  if ($_.FullyQualifiedErrorId -like 'MemberExists*') { Write-Note 'You are in the docker-users group' }
  else { Write-Warn ("Couldn't check the docker-users group: {0}" -f $_.Exception.Message) }
}
if ($addedToDockerUsers) {
  Stop-ForNow 'You were added to the docker-users group. Sign out of Windows and back in.'
}

# ---------------------------------------------------------------------------
Write-Step 'VS Code extensions'
$code = Get-Command code -ErrorAction SilentlyContinue
if (-not $code) {
  foreach ($p in @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
                   "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd")) {
    if (Test-Path $p) { $code = Get-Command $p; break }
  }
}
if ($code) {
  foreach ($ext in @('ms-vscode-remote.remote-containers', 'ms-vscode-remote.remote-wsl')) {
    & $code.Source --install-extension $ext
  }
} else {
  Write-Warn 'Could not find the code command. Install "Dev Containers" and "WSL" from the VS Code Extensions view.'
}

# ---------------------------------------------------------------------------
Write-Step 'Ubuntu'
$distros = @((wsl.exe --list --quiet) | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
if ($distros -notcontains 'Ubuntu') {
  Write-Note 'Installing Ubuntu...'
  wsl.exe --install --distribution Ubuntu --no-launch
  if ($LASTEXITCODE -ne 0) { throw "wsl --install Ubuntu failed (exit $LASTEXITCODE)." }
}
$linuxUser = wsl.exe --distribution Ubuntu --user root --exec getent passwd 1000
if (-not $linuxUser) {
  Stop-ForNow 'Open "Ubuntu" from the Start menu, choose a Linux username and password, then type exit.'
}
wsl.exe --set-default Ubuntu
Write-Note ('Ubuntu is ready (Linux user: {0}) and is the default distro' -f ($linuxUser -split ':')[0])

# ---------------------------------------------------------------------------
Write-Step 'Ubuntu side (host/setup-ubuntu.sh)'
# The copy of the script may have Windows line endings if it came through a Windows
# git checkout, so strip them before bash runs it.
$bashCommand = 'tr -d ''\r'' < host/setup-ubuntu.sh > /tmp/devbox-setup-ubuntu.sh && bash /tmp/devbox-setup-ubuntu.sh'
wsl.exe --distribution Ubuntu --cd $KitRoot --exec bash -c $bashCommand
if ($LASTEXITCODE -ne 0) {
  Write-Warn 'The Ubuntu side stopped early. Read its message above, fix that, and run this script again.'
  exit 1
}

# ---------------------------------------------------------------------------
Write-Step 'Done'
Write-Note 'If Docker Desktop has never been opened on this machine: open it, accept the terms,'
Write-Note 'and check Settings > Resources > WSL integration shows Ubuntu turned on.'
Write-Note 'Then open a project: in Ubuntu, cd ~/code/<project> && code .  and choose "Reopen in Container".'
