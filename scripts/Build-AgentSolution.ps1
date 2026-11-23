[CmdletBinding()]
param(
    [string]$WorkspacePath = 'build\agent-workspace',
    [string]$OutputDirectory = 'artifacts',
    [switch]$Initialize
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Resolve-RepositoryPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $Path))
}

$workspace = Resolve-RepositoryPath $WorkspacePath
$output = Resolve-RepositoryPath $OutputDirectory
$instructionsPath = Join-Path $repositoryRoot 'agent\instructions.md'
$pac = Get-Command 'pac' -ErrorAction SilentlyContinue

if ($null -eq $pac) {
    $pacLauncher = Join-Path $env:LOCALAPPDATA 'Microsoft\PowerAppsCli\pac.cmd'
    if (Test-Path -LiteralPath $pacLauncher -PathType Leaf) {
        $pacPath = $pacLauncher
    } else {
        throw "Power Platform CLI was not found. Install it from https://learn.microsoft.com/power-platform/developer/cli/introduction"
    }
} else {
    $pacPath = $pac.Source
}

if ($Initialize) {
    if (Test-Path -LiteralPath $workspace) {
        if ((Get-ChildItem -LiteralPath $workspace -Force | Measure-Object).Count -gt 0) {
            throw "Initialization requires an empty workspace directory: $workspace"
        }
    } else {
        New-Item -ItemType Directory -Path $workspace | Out-Null
    }

    $instructions = Get-Content -LiteralPath $instructionsPath -Raw
    & $pacPath copilot init `
        --name 'vrno.cc Link Assistant' `
        --publisher-prefix vrno `
        --schema-name vrno_ccLinkAssistant `
        --instructions $instructions `
        --project-dir $workspace
    if ($LASTEXITCODE -ne 0) {
        throw "pac copilot init failed with exit code $LASTEXITCODE."
    }
    if ((Get-ChildItem -LiteralPath $workspace -Force | Measure-Object).Count -eq 0) {
        throw "pac copilot init did not scaffold the workspace. Verify that the current Power Platform CLI is installed."
    }
}

if (-not (Test-Path -LiteralPath $workspace -PathType Container)) {
    throw "Agent workspace not found. Run this script with -Initialize to scaffold one: $workspace"
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
$existingPackages = @{}
Get-ChildItem -LiteralPath $output -Filter '*.zip' -File | ForEach-Object {
    $existingPackages[$_.FullName] = $_.LastWriteTimeUtc
}

& $pacPath copilot pack `
    --publisher-prefix vrno `
    --solution-name vrno_ccAgent `
    --project-dir $workspace `
    --output-path $output
if ($LASTEXITCODE -ne 0) {
    throw "pac copilot pack failed with exit code $LASTEXITCODE."
}

$newPackages = @(
    Get-ChildItem -LiteralPath $output -Filter '*.zip' -File |
        Where-Object { -not $existingPackages.ContainsKey($_.FullName) -or $_.LastWriteTimeUtc -gt $existingPackages[$_.FullName] }
)
if ($newPackages.Count -eq 0) {
    throw "pac copilot pack did not create or update a solution ZIP. Verify that the current Power Platform CLI is installed."
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$validPackage = $false
foreach ($package in $newPackages) {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($package.FullName)
    try {
        if ($archive.Entries | Where-Object { $_.FullName -eq 'solution.xml' }) {
            $validPackage = $true
            break
        }
    } finally {
        $archive.Dispose()
    }
}
if (-not $validPackage) {
    throw 'pac copilot pack did not produce a ZIP containing a Power Platform solution.xml.'
}

Write-Output "Agent solution package created in $output. Add the custom connector tools in Copilot Studio and export the configured agent solution before bundling."
