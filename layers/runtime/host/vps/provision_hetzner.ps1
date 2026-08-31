#Requires -Version 5.1
# Provision Hetzner CX22 for AIONS Milestone C (requires HCLOUD_TOKEN in env)
param(
    [string]$Name = 'aions-milestone-c-vps',
    [string]$Type = 'cx22',
    [string]$Location = 'nbg1',
    [string]$Image = 'ubuntu-22.04',
    [string]$SshKeyPath = 'D:\AIONS_DEV\vm\aions-milestone-c\keys\id_ed25519.pub',
    [string]$LogRoot = 'D:\AIONS_DEV\logs\milestone-c-vps',
    [string]$CloudInitTemplate = 'E:\server wiedzy\runtime\host\vps\cloud-init-user-data.yaml',
    [switch]$RenderOnly
)
$ErrorActionPreference = 'Stop'

$Token = $env:HCLOUD_TOKEN
New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
$Pub = Get-Content $SshKeyPath -Raw
$UserData = (Get-Content $CloudInitTemplate -Raw) -replace '\$\{SSH_PUBLIC_KEY\}', $Pub.Trim()
$UserDataPath = Join-Path $LogRoot 'user-data-rendered.yaml'
Set-Content -Path $UserDataPath -Value $UserData -NoNewline
Write-Host "Cloud-init: $UserDataPath"

if ($RenderOnly) {
    Write-Host 'RenderOnly - create server in Hetzner panel with this YAML or set HCLOUD_TOKEN and rerun.'
    exit 0
}

if (-not $Token) {
    throw 'Set HCLOUD_TOKEN (Hetzner API token) or use -RenderOnly'
}

$hcloud = Get-Command hcloud -ErrorAction SilentlyContinue
if (-not $hcloud) {
    Write-Host 'hcloud CLI missing - install from https://github.com/hetznercloud/cli'
    Write-Host "Or create server manually with cloud-init: $UserDataPath"
    exit 2
}

$env:HCLOUD_TOKEN = $Token
$keyName = 'aions-milestone-key'
& hcloud ssh-key describe $keyName 2>$null
if ($LASTEXITCODE -ne 0) {
    & hcloud ssh-key create --name $keyName --public-key-from-file $SshKeyPath
}

$existing = & hcloud server describe $Name -o json 2>$null | ConvertFrom-Json
if ($existing) {
    $ip = $existing.public_net.ipv4.ip
    Write-Host "Server $Name exists: $ip"
} else {
    & hcloud server create --name $Name --type $Type --image $Image --location $Location `
        --ssh-key $keyName --user-data-from-file $UserDataPath --start-after-create
    Start-Sleep -Seconds 30
    $ip = (& hcloud server describe $Name -o json | ConvertFrom-Json).public_net.ipv4.ip
}

"VPS_IP=$ip" | Set-Content (Join-Path $LogRoot 'vps.env')
Write-Host "VPS ready: $ip"
Write-Host ('Next: continue_milestone_c_vps.ps1 -Ip ' + $ip)
