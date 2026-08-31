#Requires -Version 5.1
# Milestone C on Proxmox VE — SSH bootstrap + WSL run (no GUI/vmconnect)
param(
    [string]$ProxmoxHost = '192.168.1.220',
    [string]$ProxmoxUser = 'root',
    [string]$ProxmoxStorage = 'local-lvm',
    [string]$RepoRoot = 'E:\server wiedzy',
    [string]$LogRoot = 'D:\AIONS_DEV\logs\milestone-c-proxmox',
    [string]$PrivKey = 'D:\AIONS_DEV\vm\aions-milestone-c\keys\id_ed25519',
    [string]$PubKey = 'D:\AIONS_DEV\vm\aions-milestone-c\keys\id_ed25519.pub',
    [SecureString]$ProxmoxPassword,
    [switch]$SkipBootstrap,
    [switch]$BootstrapOnly
)
$ErrorActionPreference = 'Stop'

$RunLog = Join-Path $LogRoot 'continue_run.log'
$HostScript = Join-Path $RepoRoot 'runtime\host\run_milestone_c_proxmox.sh'

function Write-Cont([string]$Msg) {
    $line = "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')][PROXMOX-CONT] $Msg"
    Write-Host $line
    Add-Content -Path $RunLog -Value $line
}

function Test-ProxmoxSshKey {
    $wslKey = ($PrivKey -replace '\\', '/') -replace '^D:', '/mnt/d'
    $out = wsl -d Ubuntu -- bash -lc "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i '$wslKey' ${ProxmoxUser}@${ProxmoxHost} echo ok 2>&1"
    return ($LASTEXITCODE -eq 0 -and $out -match 'ok')
}

function Install-ProxmoxSshKey {
    param([string]$PlainPassword)
    if (-not $PlainPassword) {
        throw 'Brak hasla Proxmox — podaj -ProxmoxPassword lub ustaw env PROXMOX_ROOT_PASSWORD'
    }
    Write-Cont 'Bootstrap SSH key na Proxmox (sshpass)...'
    $wslKey = ($PrivKey -replace '\\', '/') -replace '^D:', '/mnt/d'
    $wslPub = ($PubKey -replace '\\', '/') -replace '^D:', '/mnt/d'
    $escaped = $PlainPassword -replace "'", "'\\''"
    $cmd = @"
set -e
command -v sshpass >/dev/null 2>&1 || (sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sshpass)
PUB=\$(cat '$wslPub')
sshpass -p '$escaped' ssh -o StrictHostKeyChecking=no ${ProxmoxUser}@${ProxmoxHost} \
  "mkdir -p /root/.ssh && chmod 700 /root/.ssh && grep -Fq \"\${PUB}\" /root/.ssh/authorized_keys 2>/dev/null || echo \"\${PUB}\" >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i '$wslKey' ${ProxmoxUser}@${ProxmoxHost} echo ok
"@
    wsl -d Ubuntu -- bash -lc $cmd
    if ($LASTEXITCODE -ne 0) { throw 'Bootstrap SSH failed' }
    Write-Cont 'Bootstrap SSH OK'
}

New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
Write-Cont "=== Proxmox Milestone C host=${ProxmoxHost} ==="

if (-not (Test-Connection -ComputerName $ProxmoxHost -Count 1 -Quiet)) {
    throw "Proxmox ${ProxmoxHost} nie odpowiada na ping"
}

$plainPwd = $null
if ($ProxmoxPassword) {
    $plainPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ProxmoxPassword))
} elseif ($env:PROXMOX_ROOT_PASSWORD) {
    $plainPwd = $env:PROXMOX_ROOT_PASSWORD
}

if (-not $SkipBootstrap -and -not (Test-ProxmoxSshKey)) {
    Install-ProxmoxSshKey -PlainPassword $plainPwd
} elseif (Test-ProxmoxSshKey) {
    Write-Cont 'SSH key juz dziala (BatchMode)'
} else {
    throw 'SSH key brak i SkipBootstrap — nie mozna kontynuowac'
}

if ($BootstrapOnly) {
    Write-Cont 'BootstrapOnly — koniec'
    exit 0
}

Write-Cont 'Uruchamiam run_milestone_c_proxmox.sh w WSL...'
$wslLog = ($LogRoot -replace '\\', '/') -replace '^D:', '/mnt/d'
$wslRepo = ($RepoRoot -replace '\\', '/') -replace '^E:', '/mnt/e'
$wslKey = ($PrivKey -replace '\\', '/') -replace '^D:', '/mnt/d'
$wslScript = ($HostScript -replace '\\', '/') -replace '^E:', '/mnt/e'

$runCmd = @"
export PROXMOX_HOST=${ProxmoxUser}@${ProxmoxHost}
export PROXMOX_STORAGE=${ProxmoxStorage}
export LOG_DIR=${wslLog}
export REPO_ROOT='${wslRepo}'
export PRIV_KEY=${wslKey}
export PUB_KEY=${wslKey}.pub
bash '${wslScript}'
"@

wsl -d Ubuntu -- bash -lc $runCmd
$ec = $LASTEXITCODE
Write-Cont "run_milestone_c_proxmox.sh exit=$ec"
if (Test-Path (Join-Path $LogRoot 'result.json')) {
    Get-Content (Join-Path $LogRoot 'result.json') | Write-Cont
}
exit $ec
