#Requires -Version 5.1
# Milestone C on VPS (Hetzner/DO) — SCP/tar, /tmp pack (no drvfs hang)
param(
    [string]$Ip = '',
    [string]$RepoRoot = 'E:\server wiedzy',
    [string]$LogRoot = 'D:\AIONS_DEV\logs\milestone-c-vps'
)
$ErrorActionPreference = 'Stop'

$RunLog      = Join-Path $LogRoot 'continue_run.log'
$VpsEnv      = Join-Path $LogRoot 'vps.env'
$PrivKey     = 'D:\AIONS_DEV\vm\aions-milestone-c\keys\id_ed25519'
$GuestUser   = 'ubuntu'
$HostScripts = Join-Path $RepoRoot 'runtime\host'
$RunScript   = Join-Path $HostScripts 'guest_milestone_c_run.sh'
$RebootScript = Join-Path $HostScripts 'guest_milestone_c_post_reboot.sh'
$RepoTgz     = Join-Path $LogRoot 'aions-repo.tgz'
$WslTgz      = '/tmp/aions-repo-vps.tgz'

function Write-Cont([string]$Msg) {
    $line = "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')][VPS] $Msg"
    Write-Host $line
    Add-Content -Path $RunLog -Value $line
}

function To-LfFile([string]$Src, [string]$Dst) {
    $text = [IO.File]::ReadAllText($Src) -replace "`r`n", "`n"
    [IO.File]::WriteAllText($Dst, $text, (New-Object Text.UTF8Encoding $false))
}

function Invoke-GuestPhase {
    param([string]$LocalScript, [string]$RemoteName, [switch]$PostInstall)
    $sshOpts = @('-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL', '-i', $PrivKey)
    $remote = "/tmp/$RemoteName"
    $tmp = Join-Path $env:TEMP $RemoteName
    To-LfFile $LocalScript $tmp
    & scp @sshOpts $tmp "${GuestUser}@${Ip}:$remote"
    if ($LASTEXITCODE -ne 0) { throw "scp failed: $LocalScript" }
    $wrapperLocal = Join-Path $HostScripts 'scripts\guest_post_install.sh'
    if (-not $PostInstall) { $wrapperLocal = Join-Path $HostScripts 'scripts\guest_pre_install.sh' }
    $wrapperRemote = '/tmp/guest_wrapper.sh'
    $wrapperTmp = Join-Path $env:TEMP 'guest_wrapper.sh'
    To-LfFile $wrapperLocal $wrapperTmp
    & scp @sshOpts $wrapperTmp "${GuestUser}@${Ip}:$wrapperRemote"
    if ($PostInstall) {
        & ssh @sshOpts "${GuestUser}@${Ip}" "bash $wrapperRemote $remote"
    } else {
        & ssh @sshOpts "${GuestUser}@${Ip}" "bash $wrapperRemote $remote /tmp/aions-repo.tgz /tmp/aions-repo"
    }
    return $LASTEXITCODE
}

New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null

if (-not $Ip -and (Test-Path $VpsEnv)) {
    Get-Content $VpsEnv | ForEach-Object {
        if ($_ -match '^VPS_IP=(.+)$') { $Ip = $Matches[1].Trim() }
    }
}
if (-not $Ip) { throw 'Brak -Ip lub VPS_IP w vps.env' }

Write-Cont "=== Milestone C VPS IP=$Ip ==="

if (-not (Test-Path $RepoTgz) -or ((Get-Item $RepoTgz).LastWriteTime -lt (Get-Date).AddHours(-6))) {
    Write-Cont 'Pakowanie repo (WSL /tmp — bez drvfs)...'
    $wslSrc = ($RepoRoot -replace '\\', '/') -replace '^E:', '/mnt/e'
    wsl -d Ubuntu -u root -- bash -lc "set -e; tar -czf '$WslTgz' -C '$wslSrc' . --exclude='./venv' --exclude='./.venv' --exclude='./__pycache__' --exclude='./.git' --exclude='./scan_results' --exclude='./data/chroma'"
    wsl -d Ubuntu -u root -- bash -lc "gzip -t '$WslTgz'"
    Copy-Item -Force "\\wsl.localhost\Ubuntu\tmp\aions-repo-vps.tgz" $RepoTgz
    Write-Cont "repo.tgz: $([math]::Round((Get-Item $RepoTgz).Length/1MB,1)) MB"
}

$sshOpts = @('-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL', '-i', $PrivKey)
Write-Cont 'scp repo.tgz -> guest...'
& scp @sshOpts $RepoTgz "${GuestUser}@${Ip}:/tmp/aions-repo.tgz"

Write-Cont '=== Faza 1 pre-reboot ==='
$ec1 = Invoke-GuestPhase -LocalScript $RunScript -RemoteName 'guest_milestone_c_run.sh'
Write-Cont "pre-reboot exit=$ec1"
if ($ec1 -ne 0) { exit 1 }

Write-Cont '=== Reboot ==='
& ssh @sshOpts "${GuestUser}@${Ip}" 'sudo reboot' 2>$null | Out-Null
Start-Sleep -Seconds 45
for ($i = 0; $i -lt 60; $i++) {
    & ssh @sshOpts "${GuestUser}@${Ip}" "echo up" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Cont 'SSH after reboot OK'; break }
    Start-Sleep -Seconds 10
}

Write-Cont '=== Faza 2 post-reboot ==='
$ec2 = Invoke-GuestPhase -LocalScript $RebootScript -RemoteName 'guest_milestone_c_post_reboot.sh' -PostInstall
Write-Cont "post-reboot exit=$ec2"
$health = if ($ec1 -eq 0 -and $ec2 -eq 0) { 'PASS' } else { 'FAIL' }
Write-Cont "strict-health=$health"
@{ vm_ip = $Ip; pre_reboot_exit = $ec1; post_reboot_exit = $ec2; strict_health = $health; platform = 'vps' } |
    ConvertTo-Json | Set-Content (Join-Path $LogRoot 'result.json')
if ($health -ne 'PASS') { exit 1 }
