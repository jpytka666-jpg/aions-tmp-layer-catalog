#Requires -Version 5.1
# AIONS image build orchestrator — Faza 8 MVP
param(
    [switch]$QemuOnly,
    [string]$RepoUrl = '',
    [string]$ArtifactDir = 'D:\AIONS_DEV\artifacts'
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$PackerDir = Join-Path $PSScriptRoot '..\packer'
$OutDir = Join-Path $ArtifactDir 'packer'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "[build] manifest: $(Join-Path $PSScriptRoot 'manifest.yaml')"
Write-Host "[build] packer dir: $PackerDir"

if (-not (Get-Command packer -ErrorAction SilentlyContinue)) {
    Write-Warning 'packer not in PATH — install HashiCorp Packer to build qcow2'
    Write-Host '[build] Skipping qemu build; manifest and fixed .pkr.hcl are ready.'
    exit 0
}

Push-Location $PackerDir
try {
    $vars = @()
    if ($RepoUrl) { $vars += @('-var', "repo_bundle=/opt/aions/source") }
    packer init aions-host.pkr.hcl
    packer build @vars -var "output_dir=$OutDir" aions-host.pkr.hcl
    $qcow = Get-ChildItem -Path $OutDir -Filter '*.qcow2' -Recurse | Select-Object -First 1
    if ($qcow -and (Get-Command qemu-img -ErrorAction SilentlyContinue)) {
        $vhdx = Join-Path $OutDir 'aions-host.vhdx'
        qemu-img convert -p -O vhdx -o subformat=dynamic $qcow.FullName $vhdx
        Write-Host "[build] VHDX: $vhdx"
    }
} finally {
    Pop-Location
}
Write-Host '[build] done'
