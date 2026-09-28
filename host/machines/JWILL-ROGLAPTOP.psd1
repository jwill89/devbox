# ASUS ROG Strix G533ZW (32 GB). Games need the RAM more than dev does.
# setup-host.ps1 reads the file named after $env:COMPUTERNAME.
@{
  # Caps WSL, and so Docker Desktop's containers, at this many GB.
  # Machines without a file get WSL's default: half of RAM.
  WslMemoryGB = 12
}
