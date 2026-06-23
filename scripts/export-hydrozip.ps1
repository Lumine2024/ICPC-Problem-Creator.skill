#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Workspace,
    [string]$Output = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    Import-Module powershell-yaml -ErrorAction Stop
} catch {
    throw "导出 Hydro 包需要 PowerShell 模块 powershell-yaml。请先安装：Install-Module powershell-yaml -Scope CurrentUser"
}
. (Join-Path $PSScriptRoot "lib/icpc-common.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
$callRoot = (Get-Location).Path

function Resolve-InputPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function Resolve-OutputPath {
    param(
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath,
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        return Resolve-InputPath -Path $Path -BasePath $callRoot
    }

    return Join-Path $WorkspacePath ($Config.slug + ".zip")
}

function Read-ProblemConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath
    )

    $configPath = Join-Path $WorkspacePath "config.json"
    Assert-FileExists -Path $configPath -Description "config.json"
    return Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
}

function Test-ExportManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath
    )

    $manifestPath = Join-Path $WorkspacePath "exported-tests/manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        & (Join-Path $PSScriptRoot "export-testdata.ps1") -Workspace $WorkspacePath
    }

    Assert-FileExists -Path $manifestPath -Description "exported-tests/manifest.json"
    return Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
}

function Get-MarkdownTitle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $normalized = ConvertTo-LfText -Content $Content
    foreach ($line in ($normalized -split "`n")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        if ($trimmed -match '^#\s+(.+?)\s*$') {
            return $Matches[1].Trim()
        }
        break
    }

    return $null
}

function Remove-MarkdownTitle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $normalized = ConvertTo-LfText -Content $Content
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($normalized -split "`n")) {
        $lines.Add($line) | Out-Null
    }

    while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[0])) {
        $lines.RemoveAt(0)
    }

    if ($lines.Count -gt 0 -and $lines[0].Trim() -match '^#\s+') {
        $lines.RemoveAt(0)
        while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[0])) {
            $lines.RemoveAt(0)
        }
    }

    return (($lines -join "`n").TrimEnd() + "`n")
}

function Get-ProblemTitle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StatementContent,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    $statementTitle = Get-MarkdownTitle -Content $StatementContent
    if (-not [string]::IsNullOrWhiteSpace($statementTitle)) {
        return $statementTitle
    }

    $outputName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPath)
    if (-not [string]::IsNullOrWhiteSpace($outputName)) {
        return $outputName
    }

    return [string]$Config.title
}

function Copy-StatementAssets {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StatementPath,
        [Parameter(Mandatory = $true)]
        [string]$StatementContent,
        [Parameter(Mandatory = $true)]
        [string]$AdditionalDir
    )

    $statementDir = Split-Path -Parent $StatementPath
    $copiedNames = @{}
    $resolvedPaths = @{}
    $pattern = '!\[[^\]]*\]\(([^)]+)\)'
    $rewritten = [regex]::Replace($StatementContent, $pattern, {
        param($match)

        $rawTarget = $match.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($rawTarget)) {
            return $match.Value
        }
        if ($rawTarget -match '^(?:[a-z]+:)?//') {
            return $match.Value
        }

        $cleanTarget = $rawTarget
        if (($cleanTarget.StartsWith('"') -and $cleanTarget.EndsWith('"')) -or ($cleanTarget.StartsWith("'") -and $cleanTarget.EndsWith("'"))) {
            $cleanTarget = $cleanTarget.Substring(1, $cleanTarget.Length - 2)
        }

        $sourcePath = Resolve-InputPath -Path $cleanTarget -BasePath $statementDir
        Assert-FileExists -Path $sourcePath -Description "题面资源文件"

        $targetName = $resolvedPaths[$sourcePath]
        if (-not $targetName) {
            $baseName = [System.IO.Path]::GetFileName($sourcePath)
            $nameRoot = [System.IO.Path]::GetFileNameWithoutExtension($baseName)
            $extension = [System.IO.Path]::GetExtension($baseName)
            $targetName = $baseName
            $suffix = 2
            while ($copiedNames.ContainsKey($targetName)) {
                $targetName = "{0}-{1}{2}" -f $nameRoot, $suffix, $extension
                $suffix += 1
            }

            Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $AdditionalDir $targetName)
            $copiedNames[$targetName] = $true
            $resolvedPaths[$sourcePath] = $targetName
        }

        return $match.Value.Replace($match.Groups[1].Value, "file://$targetName")
    })

    return $rewritten
}

function New-StableNumericId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Seed
    )

    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Seed)
        $hash = $md5.ComputeHash($bytes)
        return ([int]([BitConverter]::ToUInt16($hash, 0)) % 900) + 100
    } finally {
        $md5.Dispose()
    }
}

function Get-TestdataCaseEntries {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Manifest
    )

    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($caseInfo in @($Manifest.cases)) {
        if ($Manifest.interactive) {
            $entries.Add([ordered]@{
                input  = [System.IO.Path]::GetFileName([string]$caseInfo.interactorInput)
                output = ""
            }) | Out-Null
        } else {
            $entries.Add([ordered]@{
                input  = [System.IO.Path]::GetFileName([string]$caseInfo.input)
                output = [System.IO.Path]::GetFileName([string]$caseInfo.answer)
            }) | Out-Null
        }
    }

    return @($entries)
}

function Build-TestdataConfig {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        [Parameter(Mandatory = $true)]
        [hashtable]$Manifest
    )

    if ([bool]$Config.interactive) {
        $subtask = [ordered]@{
            time  = ([int]$Config.timeLimitMs + 1000).ToString() + "ms"
            score = 100
            if    = @()
            id    = 1
            type  = "min"
            cases = @(Get-TestdataCaseEntries -Manifest $Manifest)
        }
        return [ordered]@{
            type       = "interactive"
            interactor = [ordered]@{
                file = "interactor.cpp"
                lang = "auto"
            }
            subtasks   = @($subtask)
        }
    }

    $subtask = [ordered]@{
        score = 100
        if    = @()
        id    = 1
        type  = "min"
        cases = @(Get-TestdataCaseEntries -Manifest $Manifest)
    }

    return [ordered]@{
        type         = "default"
        checker_type = "testlib"
        checker      = [ordered]@{
            file = "checker.cpp"
            lang = "auto"
        }
        subtasks     = @($subtask)
    }
}

function Copy-TestdataFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath,
        [Parameter(Mandatory = $true)]
        [hashtable]$Manifest,
        [Parameter(Mandatory = $true)]
        [string]$TestdataDir
    )

    foreach ($caseInfo in @($Manifest.cases)) {
        if ([bool]$Manifest.interactive) {
            $inputRelative = [string]$caseInfo.interactorInput
            $inputSource = Resolve-InputPath -Path $inputRelative -BasePath (Join-Path $WorkspacePath "exported-tests")
            Copy-Item -LiteralPath $inputSource -Destination (Join-Path $TestdataDir ([System.IO.Path]::GetFileName($inputRelative)))
            continue
        }

        $inputRelative = [string]$caseInfo.input
        $answerRelative = [string]$caseInfo.answer
        $inputSource = Resolve-InputPath -Path $inputRelative -BasePath (Join-Path $WorkspacePath "exported-tests")
        $answerSource = Resolve-InputPath -Path $answerRelative -BasePath (Join-Path $WorkspacePath "exported-tests")
        Copy-Item -LiteralPath $inputSource -Destination (Join-Path $TestdataDir ([System.IO.Path]::GetFileName($inputRelative)))
        Copy-Item -LiteralPath $answerSource -Destination (Join-Path $TestdataDir ([System.IO.Path]::GetFileName($answerRelative)))
    }
}

function Write-YamlFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    $yaml = ConvertTo-Yaml $Value
    Write-Utf8File -Path $Path -Content $yaml
}

function Remove-PathWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$RetryCount = 20,
        [int]$DelayMs = 200
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Force
            return
        } catch {
            if ($attempt -eq $RetryCount) {
                throw
            }
            Start-Sleep -Milliseconds $DelayMs
        }
    }
}

function Move-FileWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination,
        [int]$RetryCount = 20,
        [int]$DelayMs = 200
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            Move-Item -LiteralPath $Source -Destination $Destination -Force
            return
        } catch {
            if ($attempt -eq $RetryCount) {
                throw
            }
            Start-Sleep -Milliseconds $DelayMs
        }
    }
}

$workspacePath = Resolve-InputPath -Path $Workspace -BasePath $callRoot
if (-not (Test-Path -LiteralPath $workspacePath -PathType Container)) {
    throw "Workspace 不存在：$workspacePath"
}

$config = Read-ProblemConfig -WorkspacePath $workspacePath
$outputPath = Resolve-OutputPath -Path $Output -WorkspacePath $workspacePath -Config $config
$outputDirectory = Split-Path -Parent $outputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$manifest = Test-ExportManifest -WorkspacePath $workspacePath
$statementPath = Resolve-InputPath -Path ([string]$config.statement) -BasePath $workspacePath
$statementContent = Get-Content -LiteralPath $statementPath -Raw
$problemTitle = Get-ProblemTitle -StatementContent $statementContent -OutputPath $outputPath -Config $config
$problemId = New-StableNumericId -Seed ([string]$config.slug)

$stagingRoot = Join-Path $repoRoot ("tmp/hydrozip-" + [System.Guid]::NewGuid().ToString("N"))
$problemRoot = Join-Path $stagingRoot ([string]$problemId)
$testdataDir = Join-Path $problemRoot "testdata"
$additionalDir = Join-Path $problemRoot "additional_file"

try {
    New-Item -ItemType Directory -Path $testdataDir -Force | Out-Null
    New-Item -ItemType Directory -Path $additionalDir -Force | Out-Null

    $trimmedStatement = Remove-MarkdownTitle -Content $statementContent
    $rewrittenStatement = Copy-StatementAssets -StatementPath $statementPath -StatementContent $trimmedStatement -AdditionalDir $additionalDir

    $problemYaml = [ordered]@{
        pid     = "T$problemId"
        owner   = 1
        title   = $problemTitle
        tag     = @()
        nSubmit = 0
        nAccept = 0
    }

    Write-YamlFile -Path (Join-Path $problemRoot "problem.yaml") -Value $problemYaml
    Write-Utf8File -Path (Join-Path $problemRoot "problem_zh.md") -Content $rewrittenStatement
    Write-YamlFile -Path (Join-Path $testdataDir "config.yaml") -Value (Build-TestdataConfig -Config $config -Manifest $manifest)

    if ([bool]$config.interactive) {
        $interactorPath = Resolve-InputPath -Path ([string]$config.interactor) -BasePath $workspacePath
        Copy-Item -LiteralPath $interactorPath -Destination (Join-Path $testdataDir "interactor.cpp")
    } else {
        $checkerPath = Resolve-InputPath -Path ([string]$config.checker) -BasePath $workspacePath
        Copy-Item -LiteralPath $checkerPath -Destination (Join-Path $testdataDir "checker.cpp")
    }

    Copy-TestdataFiles -WorkspacePath $workspacePath -Manifest $manifest -TestdataDir $testdataDir

    if ((Get-ChildItem -LiteralPath $additionalDir -Force | Measure-Object).Count -eq 0) {
        Remove-Item -LiteralPath $additionalDir -Force
    }

    $temporaryZipPath = Join-Path $stagingRoot "package.zip"
    Compress-Archive -Path (Join-Path $stagingRoot "*") -DestinationPath $temporaryZipPath -CompressionLevel Optimal
    Remove-PathWithRetry -Path $outputPath
    Move-FileWithRetry -Source $temporaryZipPath -Destination $outputPath
    Write-Host "Hydro zip 已导出到: $outputPath" -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}
