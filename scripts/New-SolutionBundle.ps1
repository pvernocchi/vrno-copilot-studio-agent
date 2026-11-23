[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConnectorSolutionPath,

    [Parameter(Mandatory = $true)]
    [string]$AgentSolutionPath,

    [string]$OutputPath = 'artifacts\vrno-cc-copilot-solutions.zip'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Resolve-SolutionZip {
    param([string]$Path, [string]$Label)

    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $archive = [System.IO.Compression.ZipFile]::OpenRead($resolved)
    try {
        if (-not ($archive.Entries | Where-Object { $_.FullName -eq 'solution.xml' })) {
            throw "$Label is not a Power Platform solution ZIP (solution.xml is missing): $resolved"
        }
    } finally {
        $archive.Dispose()
    }

    return $resolved
}

$connectorSolution = Resolve-SolutionZip -Path $ConnectorSolutionPath -Label 'Connector solution'
$agentSolution = Resolve-SolutionZip -Path $AgentSolutionPath -Label 'Agent solution'
if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
} else {
    $outputFullPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputPath))
}

if ($outputFullPath -eq $connectorSolution -or $outputFullPath -eq $agentSolution) {
    throw 'OutputPath must not overwrite either input solution.'
}

$outputDirectory = [System.IO.Path]::GetDirectoryName($outputFullPath)
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$temporaryOutputPath = "$outputFullPath.$([guid]::NewGuid().ToString('N')).tmp"
$backupPath = "$outputFullPath.$([guid]::NewGuid().ToString('N')).bak"
try {
    $fileStream = [System.IO.File]::Open($temporaryOutputPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try {
        $bundle = [System.IO.Compression.ZipArchive]::new($fileStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $bundle,
                $connectorSolution,
                'solutions/01-vrno-cc-connector.zip',
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $bundle,
                $agentSolution,
                'solutions/02-vrno-cc-agent.zip',
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null

            $instructions = @'
Import the solution ZIP files in this order:
1. Import 01-vrno-cc-connector.zip and create a connection using the full value "Bearer <your-token>" as the Authorization header.
2. Import 02-vrno-cc-agent.zip after the connector is registered in the environment.
3. If prompted, bind the agent's connector connection reference to the connection created in step 1.

Do not import this outer bundle ZIP directly. It contains two separate Power Platform solution ZIPs.
'@
            $entry = $bundle.CreateEntry('IMPORT_ORDER.txt')
            $writer = [System.IO.StreamWriter]::new($entry.Open(), [System.Text.Encoding]::UTF8)
            try {
                $writer.WriteLine($instructions)
            } finally {
                $writer.Dispose()
            }
        } finally {
            $bundle.Dispose()
        }
    } finally {
        $fileStream.Dispose()
    }

    if (Test-Path -LiteralPath $outputFullPath -PathType Leaf) {
        [System.IO.File]::Replace($temporaryOutputPath, $outputFullPath, $backupPath)
        [System.IO.File]::Delete($backupPath)
    } else {
        [System.IO.File]::Move($temporaryOutputPath, $outputFullPath)
    }
} finally {
    if (Test-Path -LiteralPath $temporaryOutputPath -PathType Leaf) {
        [System.IO.File]::Delete($temporaryOutputPath)
    }
    if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
        [System.IO.File]::Delete($backupPath)
    }
}

Write-Output "Solution bundle created: $outputFullPath"
