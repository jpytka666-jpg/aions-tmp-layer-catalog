#Requires -Version 5.1
# Faza 8 — build AIONS host image via Packer (QEMU/KVM in WSL)
param(
    [string]$RepoRoot = 'E:\server wiedzy',
    [string]$WslDistro = 'Ubuntu',
    [string]$WslUser = 'aions',
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'

function Convert-ToWslPath {
    param([string]$WinPath)
    $p = ($WinPath -replace '\\', '/').TrimEnd('/')
    if ($p -match '^([A-Za-z]):(.*)$') {
        return ('/mnt/{0}{1}' -f $matches[1].ToLower(), $matches[2])
    }
    return $p
}

function Write-CloudInitFile {
    param(
        [string]$Path,
        [string]$Content
    )
    # cloud-init requires #cloud-config as first bytes — no UTF-8 BOM; LF line endings.
    $normalized = ($Content -replace "`r`n", "`n" -replace "`r", "`n").TrimEnd("`n") + "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $normalized, $utf8NoBom)
}

function Prepare-PackerBundle {
    param(
        [string]$PackerDir,
        [string]$RepoRoot
    )
    $Staging = Join-Path $PackerDir 'bundle-staging'
    New-Item -ItemType Directory -Force -Path $Staging | Out-Null

    $excludeDirs = @('data', 'venv', '.venv', '.git', 'backups', '__pycache__', 'bundle-staging', 'output-aions-host', '.packer-build-key')
    $xdArgs = $excludeDirs | ForEach-Object { '/XD', $_ }
    # /MIR odświeża staging in-place — bez rm bundle-staging (Windows: plik nul blokuje Remove-Item)
    & robocopy $RepoRoot $Staging /MIR /NFL /NDL /NJH /NJS /NC /NS /NP /XF *.pyc nul @xdArgs | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy bundle-staging failed (exit $LASTEXITCODE)"
    }
    if (-not (Test-Path (Join-Path $Staging 'requirements-linux.txt'))) {
        throw 'bundle-staging: brak requirements-linux.txt'
    }
    Write-Host "bundle-staging OK: $Staging"
    return $Staging
}

function Prepare-PackerCidata {
    param(
        [string]$PackerDir
    )
    $CidataDir = Join-Path $PackerDir 'cidata'
    $KeyDir = Join-Path $PackerDir '.packer-build-key'
    $Template = Join-Path $PackerDir 'cloud-init-user-data.yaml'
    $PrivateKey = Join-Path $KeyDir 'id_rsa'
    $PublicKey = "$PrivateKey.pub"

    New-Item -ItemType Directory -Force -Path $CidataDir, $KeyDir | Out-Null
    if (-not (Test-Path $Template)) { throw 'Brak cloud-init-user-data.yaml' }
    if (-not (Test-Path (Join-Path $CidataDir 'meta-data'))) {
        throw 'Brak cidata/meta-data'
    }

    if (-not (Test-Path $PrivateKey)) {
        if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
            throw 'Brak ssh-keygen - zainstaluj OpenSSH Client (Windows) lub uruchom z WSL'
        }
        & ssh-keygen -t rsa -b 4096 -f $PrivateKey -N '' -q
    }

    $Pub = (Get-Content $PublicKey -Raw).Trim()
    $UserData = (Get-Content $Template -Raw) -replace '\$\{SSH_PUBLIC_KEY\}', $Pub
    Write-CloudInitFile -Path (Join-Path $CidataDir 'user-data') -Content $UserData

    return $PrivateKey
}

$PackerDir = Join-Path $RepoRoot 'runtime\host\packer'
$Template = Join-Path $PackerDir 'aions-host.pkr.hcl'
$PackerDirWsl = Convert-ToWslPath $PackerDir

if ($ValidateOnly) {
    Write-Host "Manifest: $(Join-Path $PackerDir 'manifest.yaml')"
    Get-Content (Join-Path $PackerDir 'manifest.yaml')
    Write-Host "Template: $Template"
    if (-not (Test-Path $Template)) { throw 'Brak aions-host.pkr.hcl' }
    Write-Host 'ValidateOnly OK - pelny build: .\build_image.ps1 (WSL + QEMU/KVM)'
    exit 0
}

if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    throw 'Brak wsl.exe - zainstaluj WSL2 (Ubuntu) i zobacz PROVISION.md'
}
if (-not (Test-Path $Template)) { throw 'Brak aions-host.pkr.hcl' }

$PrivateKey = Prepare-PackerCidata -PackerDir $PackerDir
$null = Prepare-PackerBundle -PackerDir $PackerDir -RepoRoot $RepoRoot
$PrivateKeyWsl = Convert-ToWslPath $PrivateKey

# Bash -lc + jawny PATH Linux - nie uzywaj Windows PATH (PowerShell expanduje $PATH).
$LinuxPath = '$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
$bashScript = @"
set -euo pipefail
export PATH="$LinuxPath"
cd '$PackerDirWsl'
command -v qemu-system-x86_64 >/dev/null || { echo 'Brak qemu-system-x86_64 w PATH WSL'; exit 3; }
command -v packer >/dev/null || { echo 'Brak packer w PATH WSL (~/bin)'; exit 4; }
packer init aions-host.pkr.hcl
packer build -force -var 'ssh_private_key_file=$PrivateKeyWsl' aions-host.pkr.hcl
"@

Write-Host "Packer build w WSL ($WslDistro / $WslUser): $PackerDirWsl"
Write-Host 'Szacowany czas: ok. 20-45 min'

& wsl -d $WslDistro -u $WslUser -- bash -lc $bashScript
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
