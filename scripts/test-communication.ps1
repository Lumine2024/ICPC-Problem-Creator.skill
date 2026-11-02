#!/usr/bin/env pwsh
# Infrastructure regression suite; test inputs, fault modes and expected verdicts are external.
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Workspace)
. (Join-Path $PSScriptRoot 'lib/icpc-common.ps1')
. (Join-Path $PSScriptRoot 'lib/communication.ps1')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$auditRepoRoot = Split-Path -Parent $PSScriptRoot
$workspacePath = (Resolve-Path -LiteralPath $Workspace).Path
$config = Get-Content (Join-Path $workspacePath 'config.json') -Raw | ConvertFrom-Json -AsHashtable
$spec = Read-CommunicationConfig -Config $config
if ($null -eq $spec) { throw '工作区未声明 communication。' }
$suite = Get-Content (Join-Path $workspacePath 'tests/communication-audit.json') -Raw | ConvertFrom-Json -AsHashtable
$isWindowsAudit = [Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows)
$extension = Get-ExecutableExtension -IsWindowsHost $isWindowsAudit
$buildRoot = Join-Path $auditRepoRoot ('.codex-test-artifacts/build/' + $config.slug)
$auditRoot = Join-Path $auditRepoRoot ('.codex-test-artifacts/communication-audit/' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($auditRoot) | Out-Null
$fixturePath = Join-Path $auditRoot ('fixture' + $extension)
$compileProblem = [pscustomobject]@{ BuildConfig = $config.build; Standard = $config.standard; IncludeDir = Join-Path $workspacePath 'include'; WorkspacePath = $workspacePath }
$compiled = Invoke-CppCompilation -RepoRoot $auditRepoRoot -Problem $compileProblem -SourcePath (Join-Path $workspacePath $suite.fixture) -OutputPath $fixturePath
if ($compiled.ExitCode -ne 0) { throw $compiled.Stderr }
$checker = Join-Path $buildRoot ('bin/checker' + $extension)
$interactor = Join-Path $buildRoot ('bin/interactor' + $extension)
$python = Find-PythonCommand -BuildConfig $config.build
$reports = @()
foreach ($test in $suite.tests) {
    $relativeInput = if ($test.ContainsKey('large') -and $test.large) { $suite.largeInput } else { $suite.input }
    $inputPath = Join-Path $buildRoot ('generated/' + $relativeInput)
    $answerPath = [IO.Path]::ChangeExtension($inputPath, '.ans')
    $result = Invoke-Communication -RepoRoot $auditRepoRoot -Spec $spec -FilePath $fixturePath -Arguments $test.arguments -InputFile $inputPath -TimeoutMs $config.timeLimitMs -MemoryLimitMb $config.memoryLimitMb -InteractorFilePath $interactor -PythonCommand $python
    $firstRun = Get-Content (Join-Path $result.ArtifactPath 'alice.result.json') -Raw | ConvertFrom-Json
    if ($firstRun.verdict -eq 'AC') {
        $hidden = @([regex]::Matches([IO.File]::ReadAllText($inputPath), '\S+') | ForEach-Object Value)
        $forwarded = @([regex]::Matches([IO.File]::ReadAllText((Join-Path $result.ArtifactPath 'bob.in')), '\S+') | ForEach-Object Value)
        $encoded = @([regex]::Matches([IO.File]::ReadAllText((Join-Path $result.ArtifactPath 'alice.out')), '\S+') | ForEach-Object Value)
        $count = [int]$hidden[0]
        if ($forwarded.Count -ne 2 + 2 * $count -or $forwarded[0] -ne '2' -or [int]$forwarded[1] -ne $count) { throw 'tout 的 Bob 输入头或字段数量错误。' }
        for ($index = 0; $index -lt $count; $index++) {
            if ($forwarded[2 + 2 * $index] -cne $hidden[1 + 2 * $index] -or $forwarded[3 + 2 * $index] -cne $encoded[$index]) { throw 'tout 并非精确的 s,t 通道。' }
        }
    } else {
        if (Test-Path -LiteralPath (Join-Path $result.ArtifactPath 'bob.result.json')) { throw 'interactor 拒绝后仍运行了 Bob。' }
        $intermediate = Get-Item -LiteralPath (Join-Path $result.ArtifactPath 'bob.in') -ErrorAction SilentlyContinue
        if ($null -ne $intermediate -and $intermediate.Length -ne 0) { throw 'interactor 拒绝前写入了 tout。' }
    }
    $verdict = 'AC'
    if ($result.MemoryExceeded) { $verdict = 'MLE' }
    elseif ($result.TimedOut) { $verdict = 'TLE' }
    elseif ($result.ExitCode -ne 0) { $verdict = 'reject' }
    else {
        $outPath = Join-Path $auditRoot ($test.name + '.out')
        [IO.File]::WriteAllText($outPath, $result.Stdout, [Text.UTF8Encoding]::new($false))
        $checked = Invoke-External -RepoRoot $auditRepoRoot -FilePath $checker -Arguments @($inputPath, $outPath, $answerPath) -TimeoutMs $config.timeLimitMs
        if ($checked.ExitCode -eq 1) { $verdict = 'WA' }
        elseif ($checked.ExitCode -ne 0) { throw "checker 异常：$($checked.Stderr)" }
    }
    if ($verdict -ne $test.expected) { throw "$($test.name): expected=$($test.expected) actual=$verdict $($result.Stderr) 日志=$($result.ArtifactPath)" }
    if ($test.ContainsKey('diagnostic') -and -not $result.Stderr.Contains($test.diagnostic)) {
        throw "$($test.name): missing diagnostic $($test.diagnostic)"
    }
    $reports += [pscustomobject]@{ name = $test.name; verdict = $verdict; logs = $result.ArtifactPath }
    Write-Host "[audit] $($test.name): $verdict"
}
[IO.File]::WriteAllText((Join-Path $auditRoot 'report.json'), ($reports | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
Write-Host "[success] communication audit passed $($reports.Count) tests; report=$auditRoot/report.json"
