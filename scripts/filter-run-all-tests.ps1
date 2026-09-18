#!/usr/bin/env pwsh

<#
.SYNOPSIS
Keep only the useful progress and failure details from run-all-tests.ps1.
.EXAMPLE
& ./scripts/run-all-tests.ps1 -Workspace examples/a-plus-b 2>&1 6>&1 |
    & ./scripts/filter-run-all-tests.ps1
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline = $true)]
    [AllowNull()]
    [object]$InputObject,
    [ValidateRange(1, 1000)]
    [int]$MaxDiagnosticLines = 40
)

begin {
    $ErrorActionPreference = 'Stop'
    $logDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) '.codex-test-artifacts/logs'
    [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null
    $logName = 'run-all-tests-{0}-{1}-{2}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $PID, [guid]::NewGuid().ToString('N').Substring(0, 8)
    $logPath = Join-Path $logDirectory $logName
    $writer = [System.IO.StreamWriter]::new($logPath, $false, [System.Text.UTF8Encoding]::new($false))
    $sawFailure = $false
    $sawCompletion = $false
    $diagnosticMode = $false
    $diagnosticCount = 0
    $omittedDiagnostics = 0
    $successCount = 0

    function Write-ShortLine {
        param([string]$Line)
        if ($Line.Length -gt 1600) {
            Write-Output ($Line.Substring(0, 1600) + ' ... [truncated; see full log]')
        }
        else {
            Write-Output $Line
        }
    }

    function Write-OmittedDiagnostics {
        if ($script:omittedDiagnostics -gt 0) {
            Write-Output "[filter] omitted $script:omittedDiagnostics diagnostic lines; see full log."
            $script:omittedDiagnostics = 0
        }
    }
}

process {
    if ($null -eq $InputObject) { return }
    if ($InputObject -is [System.Management.Automation.InformationRecord]) {
        $value = [string]$InputObject.MessageData
    }
    else {
        $value = [string]$InputObject
    }

    foreach ($line in [regex]::Split($value, "`r?`n")) {
        $writer.WriteLine($line)
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line -match '^\[success\]') {
            Write-OmittedDiagnostics
            $diagnosticMode = $false
            $successCount++
            Write-ShortLine $line
            continue
        }
        if ($line -match '^全部测试通过。') {
            Write-OmittedDiagnostics
            $sawCompletion = $true
            Write-ShortLine $line
            continue
        }
        if ($line -match '^\[[^]]+\]\[error\]') {
            Write-OmittedDiagnostics
            $sawFailure = $true
            $diagnosticMode = $true
            $diagnosticCount = 0
            Write-ShortLine $line
            continue
        }
        if ($line -match '^\[[^]]+\]\[repro\]' -or $line -match '^\s+repro:') {
            Write-ShortLine $line
            continue
        }
        if ($line -match '^失败的测试用例：' -or $line -match '^- \[[^]]+\] \[[^]]+\]') {
            Write-OmittedDiagnostics
            $sawFailure = $true
            $diagnosticMode = $false
            Write-ShortLine $line
            continue
        }
        if ($line -match '^\[info\] observe\b') {
            Write-ShortLine $line
            continue
        }
        if ($line -match '^\[(workspace|info|compile|generate|validate|run-main|check-reference|check-wrong)\]') {
            Write-OmittedDiagnostics
            $diagnosticMode = $false
            continue
        }
        if ($diagnosticMode -or $line -match '(?i)(fatal error:|\berror:|undefined reference|ParserError|Exception|Traceback|^\s*at .+:\d+)') {
            if ($diagnosticCount -lt $MaxDiagnosticLines) {
                Write-ShortLine $line
                $diagnosticCount++
            }
            else {
                $omittedDiagnostics++
            }
        }
    }
}

end {
    $writer.Dispose()
    Write-OmittedDiagnostics
    if ($sawFailure -or -not $sawCompletion) {
        if (-not $sawFailure) {
            Write-Output '[filter][error] Test runner did not report completion.'
        }
        Write-Output "[filter] Full log: $logPath"
        exit 1
    }
    Write-Output "[filter] $successCount workspace(s) passed. Full log: $logPath"
    exit 0
}
