#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [string[]]$Workspace,
    [string]$OutputRoot
)

. (Join-Path $PSScriptRoot "lib/icpc-common.ps1")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactRoot = Join-Path $repoRoot ".codex-test-artifacts"
$script:IsWindowsHost = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$script:Failures = [System.Collections.Generic.List[object]]::new()

New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
$tempRoot = Join-Path $repoRoot "tmp"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$env:TEMP = $tempRoot
$env:TMP = $tempRoot

function Write-Stage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Stage,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $color = switch ($Stage) {
        "workspace" { "Cyan" }
        "compile" { "Yellow" }
        "generate" { "Magenta" }
        "validate" { "Blue" }
        "answer" { "Green" }
        "export" { "DarkGreen" }
        "success" { "Green" }
        default { "White" }
    }

    Write-Host "[$Stage] $Message" -ForegroundColor $color
}

function Add-Failure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Workspace,
        [Parameter(Mandatory = $true)]
        [string]$Stage,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Command = ""
    )

    $script:Failures.Add([pscustomobject]@{
        Workspace = $Workspace
        Stage     = $Stage
        Message   = $Message
        Command   = $Command
    }) | Out-Null

    Write-Host "[$Stage][error] ${Workspace}: $Message" -ForegroundColor Red
    if ($Command) {
        Write-Host "[$Stage][repro] $Command" -ForegroundColor DarkYellow
    }
}

function Read-ProblemConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath
    )

    $configPath = Join-Path $WorkspacePath "config.json"
    Assert-FileExists -Path $configPath -Description "config.json"
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable

    foreach ($required in @("slug", "title", "interactive", "timeLimitMs", "memoryLimitMb", "standard", "statement", "tutorial", "validator", "generator", "solutions")) {
        if (-not $config.ContainsKey($required)) {
            throw "config.json 缺少字段：$required"
        }
    }
    if (-not $config.generator.ContainsKey("path") -or -not $config.generator.ContainsKey("cases")) {
        throw "config.json 缺少 generator.path 或 generator.cases"
    }

    $interactive = [bool]$config.interactive
    $buildConfig = if ($config.ContainsKey("build")) { [hashtable]$config.build } else { @{} }
    if (-not $buildConfig.ContainsKey("cppCompiler")) { $buildConfig.cppCompiler = "g++" }
    if (-not $buildConfig.ContainsKey("cppFlags")) { $buildConfig.cppFlags = @("-std={{standard}}", "-O2", "-pipe") }
    $pythonCommand = Find-PythonCommand -BuildConfig $buildConfig

    $includeDir = Join-Path $WorkspacePath "include"
    Assert-FileExists -Path (Join-Path $includeDir "testlib.h") -Description "include/testlib.h"

    $solutions = @($config.solutions | ForEach-Object {
        [pscustomobject]@{
            Name           = [string]$_.name
            Path           = Resolve-ProblemPath -WorkspaceRoot $WorkspacePath -RelativePath ([string]$_.path) -Description "solution $($_.name)"
            Language       = [string]$_.language
            Role           = [string]$_.role
            CompileCommand = ConvertTo-Array $(if ($_.ContainsKey("compileCommand")) { $_.compileCommand } else { $null })
            RunCommand     = ConvertTo-Array $(if ($_.ContainsKey("runCommand")) { $_.runCommand } else { $null })
        }
    })

    $mains = @($solutions | Where-Object { $_.Role -eq "main" })
    if ($mains.Count -ne 1) {
        throw "solutions 中必须且只能有一个 role=main"
    }

    $cases = @($config.generator.cases | ForEach-Object {
        foreach ($requiredCaseKey in @("name", "type", "seed", "group")) {
            if (-not $_.ContainsKey($requiredCaseKey)) {
                throw "generator.cases 缺少字段：$requiredCaseKey"
            }
        }
        [pscustomobject]@{
            Name  = [string]$_.name
            Type  = [string]$_.type
            Seed  = [string]$_.seed
            Group = [string]$_.group
        }
    })

    return [pscustomobject]@{
        WorkspacePath = $WorkspacePath
        Slug          = [string]$config.slug
        Title         = [string]$config.title
        Interactive   = $interactive
        TimeLimitMs   = [int]$config.timeLimitMs
        MemoryLimitMb = [int]$config.memoryLimitMb
        Standard      = [string]$config.standard
        IncludeDir    = $includeDir
        ValidatorPath = Resolve-ProblemPath -WorkspaceRoot $WorkspacePath -RelativePath ([string]$config.validator) -Description "validator"
        GeneratorPath = Resolve-ProblemPath -WorkspaceRoot $WorkspacePath -RelativePath ([string]$config.generator.path) -Description "generator"
        BuildConfig   = $buildConfig
        PythonCommand = $pythonCommand
        Solutions     = $solutions
        Cases         = $cases
    }
}


function Get-ExportOutputRoot {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Problem
    )

    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        return Join-Path $Problem.WorkspacePath "exported-tests"
    }

    $base = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
        [System.IO.Path]::GetFullPath($OutputRoot)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputRoot))
    }

    if ($WorkspaceList.Count -eq 1) {
        return $base
    }

    return Join-Path $base $Problem.Slug
}

function Test-OneWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath
    )

    $problem = $null
    try {
        $problem = Read-ProblemConfig -WorkspacePath $WorkspacePath
    } catch {
        Add-Failure -Workspace (Split-Path -Leaf $WorkspacePath) -Stage "config" -Message $_.Exception.Message
        return
    }

    if ($problem.Interactive) {
        Add-Failure -Workspace $problem.Slug -Stage "config" -Message "交互题不能导出为静态测试数据。"
        return
    }

    $outputPath = Get-ExportOutputRoot -Problem $problem
    $buildRoot = Join-Path $artifactRoot (Join-Path "export" $problem.Slug)
    if (Test-Path -LiteralPath $buildRoot) {
        Remove-Item -LiteralPath $buildRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $outputPath) {
        Remove-Item -LiteralPath $outputPath -Recurse -Force
    }

    $binRoot = Join-Path $buildRoot "bin"
    foreach ($directory in @($buildRoot, $binRoot, $outputPath)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Write-Stage -Stage "workspace" -Message "$($problem.Slug) -> $outputPath"
    Write-Stage -Stage "export" -Message "runtime memoryLimitMb=$($problem.MemoryLimitMb) 仅对主解生效；generator 与 validator 使用更宽松的本地导出额度。"

    $compiledPrograms = @{}
    $compileFailed = $false
    $extension = Get-ExecutableExtension -IsWindowsHost $script:IsWindowsHost
    $compileEntries = @(
        [pscustomobject]@{ Name = "validator"; OutputName = "validator"; Path = $problem.ValidatorPath; CompileCommand = @() },
        [pscustomobject]@{ Name = "generator"; OutputName = "generator"; Path = $problem.GeneratorPath; CompileCommand = @() }
    )

    $mainSolution = @($problem.Solutions | Where-Object { $_.Role -eq "main" })[0]
    $compileEntries += $mainSolution

    $compiledPrograms = @{}
    Write-Stage -Stage "compile" -Message $problem.Slug
    foreach ($entry in $compileEntries) {
        if ($entry.PSObject.Properties.Name -contains "Language" -and $entry.Language -eq "python") {
            if (-not $problem.PythonCommand) {
                Add-Failure -Workspace $problem.Slug -Stage "compile" -Message "未找到 python 解释器：$($entry.Name)"
                $compileFailed = $true
                continue
            }
            $versionResult = Invoke-External -RepoRoot $repoRoot -FilePath $problem.PythonCommand -Arguments @("--version") -WorkingDirectory $problem.WorkspacePath -TimeoutMs 10000
            if ($versionResult.ExitCode -ne 0) {
                Add-Failure -Workspace $problem.Slug -Stage "compile" -Message "python 不可用：$($entry.Name)" -Command $versionResult.Command
                $compileFailed = $true
            }
            continue
        }

        $outputBaseName = if ($entry.PSObject.Properties.Name -contains "OutputName" -and -not [string]::IsNullOrWhiteSpace([string]$entry.OutputName)) {
            [string]$entry.OutputName
        } else {
            [string]$entry.Name
        }
        $outputFile = Join-Path $binRoot ($outputBaseName + $extension)
        $result = Invoke-CppCompilation -RepoRoot $repoRoot -Problem $problem -SourcePath $entry.Path -OutputPath $outputFile -Override $entry.CompileCommand
        if ($result.TimedOut -or $result.ExitCode -ne 0) {
            $message = "编译失败：$($entry.Name)"
            if ($result.Stderr) {
                $message += "`n$($result.Stderr.Trim())"
            }
            Add-Failure -Workspace $problem.Slug -Stage "compile" -Message $message -Command $result.Command
            $compileFailed = $true
            continue
        }
        if (-not (Wait-ForFile -Path $outputFile)) {
            Add-Failure -Workspace $problem.Slug -Stage "compile" -Message "编译命令返回成功，但在 120000ms 内未等到产物出现：$outputFile" -Command $result.Command
            $compileFailed = $true
            continue
        }
        $compiledPrograms[$entry.Name] = $outputFile
    }

    if ($compileFailed) {
        return
    }

    $validatorPath = [string]$compiledPrograms["validator"]
    $generatorPath = [string]$compiledPrograms["generator"]
    $mainInvocation = Get-Invocation -Problem $problem -Entry $mainSolution -CompiledPrograms $compiledPrograms
    $timeoutMs = [Math]::Max($problem.TimeLimitMs * 3, $problem.TimeLimitMs + 1000)
    $toolTimeoutMs = [Math]::Max($problem.TimeLimitMs * 60, 60000)
    $runtimeMemoryLimitMb = [Math]::Max($problem.MemoryLimitMb, 1)
    $toolMemoryLimitMb = 0
    $manifestCases = [System.Collections.Generic.List[object]]::new()
    $generatedCases = [System.Collections.Generic.List[object]]::new()
    $validatedCases = [System.Collections.Generic.List[object]]::new()

    foreach ($groupName in @($problem.Cases | ForEach-Object { $_.Group } | Sort-Object -Unique)) {
        New-Item -ItemType Directory -Path (Join-Path $outputPath $groupName) -Force | Out-Null
    }

    foreach ($caseInfo in $problem.Cases) {
        $groupDir = Join-Path $outputPath $caseInfo.Group
        $inputPath = Join-Path $groupDir ($caseInfo.Name + ".in")
        $answerPath = Join-Path $groupDir ($caseInfo.Name + ".ans")

        Write-Stage -Stage "generate" -Message "$($problem.Slug) case=$($caseInfo.Name)"
        $generateResult = Invoke-External -RepoRoot $repoRoot -FilePath $generatorPath -Arguments @($caseInfo.Type, [string]$caseInfo.Seed) -WorkingDirectory $problem.WorkspacePath -TimeoutMs $toolTimeoutMs -MemoryLimitMb $toolMemoryLimitMb
        if ($generateResult.TimedOut -or $generateResult.ExitCode -ne 0) {
            $message = "generator 失败：case=$($caseInfo.Name)"
            if ($generateResult.MemoryExceeded) {
                $message += " (MLE)"
            }
            if ($generateResult.Stderr) {
                $message += "`n$($generateResult.Stderr.Trim())"
            }
            Add-Failure -Workspace $problem.Slug -Stage "generate" -Message $message -Command $generateResult.Command
            continue
        }
        [System.IO.File]::WriteAllText($inputPath, (ConvertTo-LfText -Content $generateResult.Stdout), [System.Text.UTF8Encoding]::new($false))
        $generatedCases.Add([pscustomobject]@{
            Name       = $caseInfo.Name
            Type       = $caseInfo.Type
            Seed       = $caseInfo.Seed
            Group      = $caseInfo.Group
            InputPath  = $inputPath
            AnswerPath = $answerPath
        }) | Out-Null
    }

    if ($generatedCases.Count -eq 0) {
        Add-Failure -Workspace $problem.Slug -Stage "generate" -Message "没有任何成功生成的测试点。"
        return
    }

    foreach ($caseInfo in $generatedCases) {
        Write-Stage -Stage "validate" -Message "$($problem.Slug) case=$($caseInfo.Name)"
        if ($script:IsWindowsHost) {
            $cmdPath = Join-Path $binRoot ("validate-" + $caseInfo.Name + ".cmd")
            $cmdContent = @(
                "@echo off"
                'type "' + $caseInfo.InputPath + '" | "' + $validatorPath + '"'
                "exit /b %errorlevel%"
            ) -join "`r`n"
            [System.IO.File]::WriteAllText($cmdPath, $cmdContent, [System.Text.ASCIIEncoding]::new())
            $validatorResult = Invoke-External -RepoRoot $repoRoot -FilePath "cmd.exe" -Arguments @("/d", "/c", $cmdPath) -WorkingDirectory $problem.WorkspacePath -TimeoutMs $toolTimeoutMs -MemoryLimitMb $toolMemoryLimitMb
        } else {
            $validatorResult = Invoke-External -RepoRoot $repoRoot -FilePath $validatorPath -WorkingDirectory $problem.WorkspacePath -InputFile $caseInfo.InputPath -TimeoutMs $toolTimeoutMs -MemoryLimitMb $toolMemoryLimitMb
        }
        if ($validatorResult.TimedOut -or $validatorResult.ExitCode -ne 0) {
            $message = "validator 失败：case=$($caseInfo.Name), input=$($caseInfo.InputPath), exit=$($validatorResult.ExitCode)"
            if ($validatorResult.MemoryExceeded) {
                $message += " (MLE)"
            }
            if ($validatorResult.Stderr) {
                $message += "`n$($validatorResult.Stderr.Trim())"
            }
            Add-Failure -Workspace $problem.Slug -Stage "validate" -Message $message -Command $validatorResult.Command
            continue
        }
        $validatedCases.Add($caseInfo) | Out-Null
    }

    if ($validatedCases.Count -eq 0) {
        Add-Failure -Workspace $problem.Slug -Stage "validate" -Message "没有任何通过 validator 的测试点。"
        return
    }

    foreach ($caseInfo in $validatedCases) {
        Write-Stage -Stage "answer" -Message "$($problem.Slug) case=$($caseInfo.Name)"
        $mainResult = Invoke-External -RepoRoot $repoRoot -FilePath $mainInvocation.FilePath -Arguments $mainInvocation.Arguments -WorkingDirectory $problem.WorkspacePath -InputFile $caseInfo.InputPath -TimeoutMs $timeoutMs -MemoryLimitMb $runtimeMemoryLimitMb
        if ($mainResult.TimedOut -or $mainResult.ExitCode -ne 0) {
            $message = "主解失败：case=$($caseInfo.Name)"
            if ($mainResult.TimedOut) {
                $message += " (TLE)"
            }
            if ($mainResult.MemoryExceeded) {
                $message += " (MLE)"
            }
            if ($mainResult.Stderr) {
                $message += "`n$($mainResult.Stderr.Trim())"
            }
            Add-Failure -Workspace $problem.Slug -Stage "answer" -Message $message -Command $mainResult.Command
            continue
        }
        [System.IO.File]::WriteAllText($caseInfo.AnswerPath, (ConvertTo-LfText -Content $mainResult.Stdout), [System.Text.UTF8Encoding]::new($false))

        $manifestCases.Add([pscustomobject]@{
            name   = $caseInfo.Name
            type   = $caseInfo.Type
            seed   = $caseInfo.Seed
            group  = $caseInfo.Group
            input  = (Join-Path $caseInfo.Group ($caseInfo.Name + ".in"))
            answer = (Join-Path $caseInfo.Group ($caseInfo.Name + ".ans"))
        }) | Out-Null
    }

    if ($manifestCases.Count -eq 0) {
        Add-Failure -Workspace $problem.Slug -Stage "answer" -Message "没有任何成功导出的测试点。"
        return
    }

    $manifest = [pscustomobject]@{
        slug        = $problem.Slug
        title       = $problem.Title
        exportedAt  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
        workspace   = $problem.WorkspacePath
        outputRoot  = $outputPath
        caseCount   = $manifestCases.Count
        cases       = @($manifestCases)
    }
    $manifestPath = Join-Path $outputPath "manifest.json"
    [System.IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 5) + "`n"), [System.Text.UTF8Encoding]::new($false))

    Write-Stage -Stage "success" -Message "$($problem.Slug) exported $($manifestCases.Count) cases to $outputPath"
}

$WorkspaceList = Resolve-WorkspaceList -RepoRoot $repoRoot -Requested $Workspace
foreach ($workspacePath in $WorkspaceList) {
    Test-OneWorkspace -WorkspacePath $workspacePath
}

if ($script:Failures.Count -gt 0) {
    Write-Host ""
    Write-Host "失败的导出任务：" -ForegroundColor Red
    foreach ($failure in $script:Failures) {
        Write-Host "- [$($failure.Workspace)] [$($failure.Stage)] $($failure.Message)"
        if ($failure.Command) {
            Write-Host "  command: $($failure.Command)" -ForegroundColor DarkGray
        }
    }
    exit 1
}

Write-Host "全部导出完成。" -ForegroundColor Green
