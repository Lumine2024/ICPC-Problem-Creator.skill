#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [string[]]$Workspace
)

. (Join-Path $PSScriptRoot "lib/icpc-common.ps1")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactRoot = Join-Path $repoRoot ".codex-test-artifacts"
$script:IsWindowsHost = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$script:Failures = [System.Collections.Generic.List[object]]::new()

New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
$tempRoot = Join-Path $artifactRoot "tmp"
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
        "info" { "DarkCyan" }
        "compile" { "Yellow" }
        "generate" { "Magenta" }
        "validate" { "Blue" }
        "run-main" { "Green" }
        "check-reference" { "DarkGreen" }
        "check-wrong" { "DarkYellow" }
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

function Invoke-InteractivePair {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContestantFilePath,
        [string[]]$ContestantArguments = @(),
        [Parameter(Mandatory = $true)]
        [string]$InteractorFilePath,
        [string[]]$InteractorArguments = @(),
        [string]$WorkingDirectory = $repoRoot,
        [int]$TimeoutMs = 0
    )

    $contestantCommand = Format-Command -FilePath $ContestantFilePath -Arguments $ContestantArguments
    $interactorCommand = Format-Command -FilePath $InteractorFilePath -Arguments $InteractorArguments
    Write-Host $contestantCommand -ForegroundColor DarkGray
    Write-Host $interactorCommand -ForegroundColor DarkGray

    $python = $null
    foreach ($candidate in @("python", "python3")) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            $python = $candidate
            break
        }
    }
    if (-not $python) {
        throw "交互题本地联调需要 python 作为 broker，但当前环境未找到 python。"
    }

    $runnerPath = Join-Path $artifactRoot "interactive-runner.py"
    $runnerTemplatePath = Join-Path $PSScriptRoot "lib/interactive-runner.py"
    $runnerLibPath = Join-Path $artifactRoot "interactlib.py"
    Copy-Item -LiteralPath $runnerTemplatePath -Destination $runnerPath -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "lib/interactlib.py") -Destination $runnerLibPath -Force

    $contestantList = @($ContestantFilePath) + $ContestantArguments
    $interactorList = @($InteractorFilePath) + $InteractorArguments
    $runnerResult = Invoke-External -RepoRoot $repoRoot -FilePath $python -Arguments @($runnerPath, (ConvertTo-Json $contestantList -Compress), (ConvertTo-Json $interactorList -Compress), $WorkingDirectory, ([string]([Math]::Max($TimeoutMs, 1) / 1000.0))) -WorkingDirectory $repoRoot -TimeoutMs ([Math]::Max($TimeoutMs + 5000, 10000))
    if ($runnerResult.ExitCode -ne 0) {
        throw "交互 broker 执行失败：$($runnerResult.Stderr)"
    }

    $payload = $runnerResult.Stdout | ConvertFrom-Json
    $verdict = "AC"
    if ($payload.timedOut) {
        $verdict = "TLE"
    } elseif ($payload.contestantExitCode -ne 0) {
        $verdict = "RE"
    } elseif ($payload.interactorExitCode -ne 0) {
        $verdict = "WA"
    }

    return [pscustomobject]@{
        ContestantCommand  = $contestantCommand
        InteractorCommand  = $interactorCommand
        ContestantExitCode = [int]$payload.contestantExitCode
        InteractorExitCode = [int]$payload.interactorExitCode
        ContestantStderr   = [string]$payload.contestantStderr
        InteractorStderr   = [string]$payload.interactorStderr
        Verdict            = $verdict
        TimedOut           = [bool]$payload.timedOut
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
    if ($interactive) {
        if (-not $config.ContainsKey("interactor")) {
            throw "交互题必须声明 interactor"
        }
    } elseif (-not $config.ContainsKey("checker")) {
        throw "普通题必须声明 checker"
    }

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
            Groups         = ConvertTo-Array $(if ($_.ContainsKey("groups")) { $_.groups } else { $null })
            Cases          = ConvertTo-Array $(if ($_.ContainsKey("cases")) { $_.cases } else { $null })
        }
    })

    $wrongSolutions = @()
    if ($config.ContainsKey("wrongSolutions")) {
        $wrongSolutions = @($config.wrongSolutions | ForEach-Object {
            [pscustomobject]@{
                Name           = [string]$_.name
                Path           = Resolve-ProblemPath -WorkspaceRoot $WorkspacePath -RelativePath ([string]$_.path) -Description "wrong solution $($_.name)"
                Language       = [string]$_.language
                Expected       = [string]$_.expected
                CompileCommand = ConvertTo-Array $(if ($_.ContainsKey("compileCommand")) { $_.compileCommand } else { $null })
                RunCommand     = ConvertTo-Array $(if ($_.ContainsKey("runCommand")) { $_.runCommand } else { $null })
                Groups         = ConvertTo-Array $(if ($_.ContainsKey("groups")) { $_.groups } else { $null })
                Cases          = ConvertTo-Array $(if ($_.ContainsKey("cases")) { $_.cases } else { $null })
            }
        })
    }

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
            Name      = [string]$_.name
            Type      = [string]$_.type
            Seed      = [string]$_.seed
            Group     = [string]$_.group
            CheckWith = ConvertTo-Array $(if ($_.ContainsKey("checkWith")) { $_.checkWith } else { $null })
        }
    })

    return [pscustomobject]@{
        WorkspacePath         = $WorkspacePath
        Slug                  = [string]$config.slug
        Interactive           = $interactive
        TimeLimitMs           = [int]$config.timeLimitMs
        MemoryLimitMb         = [int]$config.memoryLimitMb
        Standard              = [string]$config.standard
        IncludeDir            = $includeDir
        StatementPath         = Resolve-ProblemPath -WorkspaceRoot $WorkspacePath -RelativePath ([string]$config.statement) -Description "statement"
        TutorialPath          = Resolve-ProblemPath -WorkspaceRoot $WorkspacePath -RelativePath ([string]$config.tutorial) -Description "tutorial"
        ValidatorPath         = Resolve-ProblemPath -WorkspaceRoot $WorkspacePath -RelativePath ([string]$config.validator) -Description "validator"
        GeneratorPath         = Resolve-ProblemPath -WorkspaceRoot $WorkspacePath -RelativePath ([string]$config.generator.path) -Description "generator"
        CheckerPath           = if ($interactive) { $null } else { Resolve-ProblemPath -WorkspaceRoot $WorkspacePath -RelativePath ([string]$config.checker) -Description "checker" }
        InteractorPath        = if ($interactive) { Resolve-ProblemPath -WorkspaceRoot $WorkspacePath -RelativePath ([string]$config.interactor) -Description "interactor" } else { $null }
        InteractionAnswerPath = if ($config.ContainsKey("interactionAnswer")) { Resolve-ProblemPath -WorkspaceRoot $WorkspacePath -RelativePath ([string]$config.interactionAnswer) -Description "interactionAnswer" } else { $null }
        BuildConfig           = $buildConfig
        PythonCommand         = $pythonCommand
        Solutions             = $solutions
        WrongSolutions        = $wrongSolutions
        Cases                 = $cases
    }
}

function New-BuildLayout {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath,
        [Parameter(Mandatory = $true)]
        [string]$Slug
    )

    $buildRoot = Join-Path $artifactRoot (Join-Path "build" $Slug)
    if (Test-Path -LiteralPath $buildRoot) {
        Remove-Item -LiteralPath $buildRoot -Recurse -Force
    }
    $binRoot = Join-Path $buildRoot "bin"
    $generatedRoot = Join-Path $buildRoot "generated"
    foreach ($directory in @($buildRoot, $binRoot, $generatedRoot)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    return [pscustomobject]@{
        BuildRoot     = $buildRoot
        BinRoot       = $binRoot
        GeneratedRoot = $generatedRoot
    }
}

function Assert-CompiledProgram {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Problem,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    if (Test-Path -LiteralPath $OutputPath -PathType Leaf) {
        return $true
    }

    Write-Stage -Stage "compile" -Message "$($Problem.Slug) recompiling $($Entry.Name) because artifact is missing"
    $result = Invoke-CppCompilation -RepoRoot $repoRoot -Problem $Problem -SourcePath $Entry.Path -OutputPath $OutputPath -Override $Entry.CompileCommand -AddWindowsStackFlag:$script:IsWindowsHost
    if ($result.TimedOut -or $result.ExitCode -ne 0) {
        $message = "编译失败：$($Entry.Name)"
        if ($result.Stderr) {
            $message += "`n$($result.Stderr.Trim())"
        }
        Add-Failure -Workspace $Problem.Slug -Stage "compile" -Message $message -Command $result.Command
        return $false
    }

    if (Wait-ForFile -Path $OutputPath) {
        return $true
    }

    Add-Failure -Workspace $Problem.Slug -Stage "compile" -Message "编译命令返回成功，但在 120000ms 内未等到产物出现：$OutputPath" -Command $result.Command
    return $false
}

function Test-CaseMatchesEntry {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Case,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry
    )

    if ($Entry.Cases.Count -gt 0 -and $Case.Name -notin $Entry.Cases) {
        return $false
    }
    if ($Entry.Groups.Count -gt 0 -and $Case.Group -notin $Entry.Groups) {
        return $false
    }
    return $true
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

    Write-Stage -Stage "workspace" -Message "$($problem.Slug) ($WorkspacePath)"
    Write-Stage -Stage "info" -Message "memoryLimitMb=$($problem.MemoryLimitMb) 仅对主解/参考解/错解生效；generator 与 validator 使用更宽松的本地校验额度。"

    $layout = New-BuildLayout -WorkspacePath $WorkspacePath -Slug $problem.Slug
    $compiledPrograms = @{}
    $compileFailed = $false
    $extension = Get-ExecutableExtension -IsWindowsHost $script:IsWindowsHost

    $compileEntries = @(
        [pscustomobject]@{ Name = "input-tool"; OutputName = "validator"; Path = $problem.ValidatorPath; CompileCommand = @() },
        [pscustomobject]@{ Name = "gen-tool"; OutputName = "generator"; Path = $problem.GeneratorPath; CompileCommand = @() }
    )
    if ($problem.Interactive) {
        $compileEntries += [pscustomobject]@{ Name = "judge-tool"; OutputName = "interactor"; Path = $problem.InteractorPath; CompileCommand = @() }
    } else {
        $compileEntries += [pscustomobject]@{ Name = "judge-tool"; OutputName = "checker"; Path = $problem.CheckerPath; CompileCommand = @() }
    }
    $compileEntries += @($problem.Solutions + $problem.WrongSolutions)
    $compileEntryByName = @{}
    foreach ($entry in $compileEntries) {
        $compileEntryByName[$entry.Name] = $entry
    }

    Write-Stage -Stage "compile" -Message $problem.Slug
    foreach ($entry in $compileEntries) {
        if ($entry.PSObject.Properties.Name -contains "Language" -and $entry.Language -eq "python") {
            if (-not (Test-Path -LiteralPath $entry.Path -PathType Leaf)) {
                Add-Failure -Workspace $problem.Slug -Stage "compile" -Message "Python 文件不存在：$($entry.Path)"
                $compileFailed = $true
                continue
            }
            if (-not $problem.PythonCommand) {
                Add-Failure -Workspace $problem.Slug -Stage "compile" -Message "未找到 python 解释器：$($entry.Name)"
                $compileFailed = $true
                continue
            }
            $versionResult = Invoke-External -RepoRoot $repoRoot -FilePath $problem.PythonCommand -Arguments @("--version") -WorkingDirectory $problem.WorkspacePath -TimeoutMs 10000
            if ($versionResult.ExitCode -ne 0) {
                Add-Failure -Workspace $problem.Slug -Stage "compile" -Message "python 不可用：$($entry.Name)`n$($versionResult.Stderr)" -Command $versionResult.Command
                $compileFailed = $true
            }
            continue
        }

        $outputBaseName = if ($entry.PSObject.Properties.Name -contains "OutputName" -and -not [string]::IsNullOrWhiteSpace([string]$entry.OutputName)) {
            [string]$entry.OutputName
        } else {
            [string]$entry.Name
        }
        $outputPath = Join-Path $layout.BinRoot ($outputBaseName + $extension)
        $result = Invoke-CppCompilation -RepoRoot $repoRoot -Problem $problem -SourcePath $entry.Path -OutputPath $outputPath -Override $entry.CompileCommand -AddWindowsStackFlag:$script:IsWindowsHost
        if ($result.TimedOut -or $result.ExitCode -ne 0) {
            $message = "编译失败：$($entry.Name)"
            if ($result.Stderr) {
                $message += "`n$($result.Stderr.Trim())"
            }
            Add-Failure -Workspace $problem.Slug -Stage "compile" -Message $message -Command $result.Command
            $compileFailed = $true
            continue
        }
        if (-not (Wait-ForFile -Path $outputPath)) {
            Add-Failure -Workspace $problem.Slug -Stage "compile" -Message "编译命令返回成功，但在 120000ms 内未等到产物出现：$outputPath" -Command $result.Command
            $compileFailed = $true
            continue
        }
        $compiledPrograms[$entry.Name] = $outputPath
    }

    if ($compileFailed) {
        return
    }

    $validatorPath = [string]$compiledPrograms["input-tool"]
    $generatorPath = [string]$compiledPrograms["gen-tool"]
    $judgePath = [string]$compiledPrograms["judge-tool"]
    $timeoutMs = [Math]::Max($problem.TimeLimitMs * 3, $problem.TimeLimitMs + 1000)
    $toolTimeoutMs = [Math]::Max($problem.TimeLimitMs * 60, 60000)
    $runtimeMemoryLimitMb = [Math]::Max($problem.MemoryLimitMb, 1)
    $toolMemoryLimitMb = 0
    $generatedCases = [System.Collections.Generic.List[object]]::new()

    Write-Stage -Stage "generate" -Message $problem.Slug
    if (-not (Assert-CompiledProgram -Problem $problem -Entry $compileEntryByName["input-tool"] -OutputPath $validatorPath)) {
        return
    }
    if (-not (Assert-CompiledProgram -Problem $problem -Entry $compileEntryByName["gen-tool"] -OutputPath $generatorPath)) {
        return
    }
    foreach ($caseItem in $problem.Cases) {
        $groupDir = Join-Path $layout.GeneratedRoot $caseItem.Group
        New-Item -ItemType Directory -Path $groupDir -Force | Out-Null
        $inputPath = Join-Path $groupDir ($caseItem.Name + ".in")
        $generateResult = Invoke-External -RepoRoot $repoRoot -FilePath $generatorPath -Arguments @($caseItem.Type, [string]$caseItem.Seed) -WorkingDirectory $problem.WorkspacePath -TimeoutMs $toolTimeoutMs -MemoryLimitMb $toolMemoryLimitMb
        if ($generateResult.TimedOut -or $generateResult.ExitCode -ne 0) {
            $message = "generator 失败：case=$($caseItem.Name)"
            if ($generateResult.MemoryExceeded) {
                $message += " (MLE)"
            }
            if ($generateResult.Stderr) {
                $message += "`n$($generateResult.Stderr.Trim())"
            }
            Add-Failure -Workspace $problem.Slug -Stage "generate" -Message $message -Command $generateResult.Command
            continue
        }
        [System.IO.File]::WriteAllText($inputPath, $generateResult.Stdout, [System.Text.UTF8Encoding]::new($false))
        $generatedCases.Add([pscustomobject]@{
            Name        = $caseItem.Name
            Type        = $caseItem.Type
            Seed        = $caseItem.Seed
            Group       = $caseItem.Group
            InputPath   = $inputPath
            AnswerPath  = Join-Path $groupDir ($caseItem.Name + ".ans")
            MainOutPath = Join-Path $groupDir ($caseItem.Name + ".main.out")
            CheckWith   = $caseItem.CheckWith
        }) | Out-Null
    }

    if ($generatedCases.Count -eq 0) {
        Add-Failure -Workspace $problem.Slug -Stage "generate" -Message "没有任何成功生成的测试点。"
        return
    }

    $validGeneratedCases = [System.Collections.Generic.List[object]]::new()

    Write-Stage -Stage "validate" -Message $problem.Slug
    foreach ($caseInfo in $generatedCases) {
        if ($script:IsWindowsHost) {
            $cmdPath = Join-Path $layout.BinRoot ("validator-" + $caseInfo.Name + ".cmd")
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

        $validGeneratedCases.Add($caseInfo) | Out-Null
    }

    if ($validGeneratedCases.Count -eq 0) {
        Add-Failure -Workspace $problem.Slug -Stage "validate" -Message "没有任何通过 validator 的测试点。"
        return
    }

    $mainSolution = @($problem.Solutions | Where-Object { $_.Role -eq "main" })[0]
    $mainInvocation = Get-Invocation -Problem $problem -Entry $mainSolution -CompiledPrograms $compiledPrograms

    if (-not $problem.Interactive) {
        Write-Stage -Stage "run-main" -Message $problem.Slug
        foreach ($caseInfo in $validGeneratedCases) {
            $mainResult = Invoke-External -RepoRoot $repoRoot -FilePath $mainInvocation.FilePath -Arguments $mainInvocation.Arguments -WorkingDirectory $problem.WorkspacePath -InputFile $caseInfo.InputPath -TimeoutMs $timeoutMs -MemoryLimitMb $runtimeMemoryLimitMb
            if ($mainResult.TimedOut -or $mainResult.ExitCode -ne 0) {
                $message = "主解失败：case=$($caseInfo.Name)"
                if ($mainResult.TimedOut) { $message += " (TLE)" }
                if ($mainResult.MemoryExceeded) { $message += " (MLE)" }
                if ($mainResult.Stderr) { $message += "`n$($mainResult.Stderr.Trim())" }
                Add-Failure -Workspace $problem.Slug -Stage "run-main" -Message $message -Command $mainResult.Command
                continue
            }

            [System.IO.File]::WriteAllText($caseInfo.MainOutPath, $mainResult.Stdout, [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::WriteAllText($caseInfo.AnswerPath, $mainResult.Stdout, [System.Text.UTF8Encoding]::new($false))

            $judgeResult = Invoke-External -RepoRoot $repoRoot -FilePath $judgePath -Arguments @($caseInfo.InputPath, $caseInfo.MainOutPath, $caseInfo.AnswerPath) -WorkingDirectory $problem.WorkspacePath -TimeoutMs 10000
            if ($judgeResult.TimedOut -or $judgeResult.ExitCode -ne 0) {
                $message = "checker 未接受主解输出：case=$($caseInfo.Name)"
                if ($judgeResult.Stderr) { $message += "`n$($judgeResult.Stderr.Trim())" }
                Add-Failure -Workspace $problem.Slug -Stage "run-main" -Message $message -Command $judgeResult.Command
            }
        }

        $referenceSolutions = @($problem.Solutions | Where-Object { $_.Role -eq "reference" })
        Write-Stage -Stage "check-reference" -Message $problem.Slug
        foreach ($reference in $referenceSolutions) {
            $referenceInvocation = Get-Invocation -Problem $problem -Entry $reference -CompiledPrograms $compiledPrograms
            foreach ($caseInfo in $validGeneratedCases) {
                if ($caseInfo.CheckWith.Count -gt 0 -and $reference.Name -notin $caseInfo.CheckWith) { continue }
                if (-not (Test-CaseMatchesEntry -Case $caseInfo -Entry $reference)) { continue }

                $referenceOut = Join-Path (Split-Path -Parent $caseInfo.InputPath) ($caseInfo.Name + "." + $reference.Name + ".out")
                $referenceResult = Invoke-External -RepoRoot $repoRoot -FilePath $referenceInvocation.FilePath -Arguments $referenceInvocation.Arguments -WorkingDirectory $problem.WorkspacePath -InputFile $caseInfo.InputPath -TimeoutMs $timeoutMs -MemoryLimitMb $runtimeMemoryLimitMb
                if ($referenceResult.TimedOut -or $referenceResult.ExitCode -ne 0) {
                    $message = "参考解失败：solution=$($reference.Name), case=$($caseInfo.Name)"
                    if ($referenceResult.TimedOut) { $message += " (TLE)" }
                    if ($referenceResult.MemoryExceeded) { $message += " (MLE)" }
                    if ($referenceResult.Stderr) { $message += "`n$($referenceResult.Stderr.Trim())" }
                    Add-Failure -Workspace $problem.Slug -Stage "check-reference" -Message $message -Command $referenceResult.Command
                    continue
                }

                [System.IO.File]::WriteAllText($referenceOut, $referenceResult.Stdout, [System.Text.UTF8Encoding]::new($false))
                $judgeResult = Invoke-External -RepoRoot $repoRoot -FilePath $judgePath -Arguments @($caseInfo.InputPath, $referenceOut, $caseInfo.AnswerPath) -WorkingDirectory $problem.WorkspacePath -TimeoutMs 10000
                if ($judgeResult.TimedOut -or $judgeResult.ExitCode -ne 0) {
                    $message = "参考解未通过 checker：solution=$($reference.Name), case=$($caseInfo.Name)"
                    if ($judgeResult.Stderr) { $message += "`n$($judgeResult.Stderr.Trim())" }
                    Add-Failure -Workspace $problem.Slug -Stage "check-reference" -Message $message -Command $judgeResult.Command
                }
            }
        }

        Write-Stage -Stage "check-wrong" -Message $problem.Slug
        foreach ($wrong in $problem.WrongSolutions) {
            $wrongInvocation = Get-Invocation -Problem $problem -Entry $wrong -CompiledPrograms $compiledPrograms
            $testedCases = 0
            $failedCases = 0
            foreach ($caseInfo in $validGeneratedCases) {
                if (-not (Test-CaseMatchesEntry -Case $caseInfo -Entry $wrong)) { continue }
                $testedCases += 1
                $wrongOut = Join-Path (Split-Path -Parent $caseInfo.InputPath) ($caseInfo.Name + "." + $wrong.Name + ".out")
                $wrongResult = Invoke-External -RepoRoot $repoRoot -FilePath $wrongInvocation.FilePath -Arguments $wrongInvocation.Arguments -WorkingDirectory $problem.WorkspacePath -InputFile $caseInfo.InputPath -TimeoutMs $timeoutMs -MemoryLimitMb $runtimeMemoryLimitMb
                if ($wrongResult.TimedOut -or $wrongResult.ExitCode -ne 0) {
                    $failedCases += 1
                    if ($wrong.Expected -eq "fail") {
                        break
                    }
                    continue
                }
                [System.IO.File]::WriteAllText($wrongOut, $wrongResult.Stdout, [System.Text.UTF8Encoding]::new($false))
                $judgeResult = Invoke-External -RepoRoot $repoRoot -FilePath $judgePath -Arguments @($caseInfo.InputPath, $wrongOut, $caseInfo.AnswerPath) -WorkingDirectory $problem.WorkspacePath -TimeoutMs 10000
                if ($judgeResult.TimedOut -or $judgeResult.ExitCode -ne 0) {
                    $failedCases += 1
                }
                if ($wrong.Expected -eq "fail" -and $failedCases -gt 0) {
                    break
                }
            }

            if ($testedCases -eq 0) {
                if ($wrong.Expected -eq "observe") {
                    Write-Stage -Stage "info" -Message "observe $($wrong.Name): no matched cases"
                } else {
                    Add-Failure -Workspace $problem.Slug -Stage "check-wrong" -Message "错解未匹配到任何测试点：$($wrong.Name)"
                }
            } elseif ($wrong.Expected -eq "fail" -and $failedCases -eq 0) {
                Add-Failure -Workspace $problem.Slug -Stage "check-wrong" -Message "错解在所有测试点上都通过了：$($wrong.Name)"
            } elseif ($wrong.Expected -eq "pass" -and $failedCases -gt 0) {
                Add-Failure -Workspace $problem.Slug -Stage "check-wrong" -Message "方案本应通过，但被数据卡掉了：$($wrong.Name)"
            } elseif ($wrong.Expected -eq "observe") {
                $passedCases = $testedCases - $failedCases
                Write-Stage -Stage "info" -Message "observe $($wrong.Name): passed=$passedCases failed=$failedCases"
            }
        }
    } else {
        Write-Stage -Stage "run-main" -Message $problem.Slug
        foreach ($caseInfo in $validGeneratedCases) {
            $transcriptPath = Join-Path (Split-Path -Parent $caseInfo.InputPath) ($caseInfo.Name + ".interactor.out")
            $judgeArgs = @($caseInfo.InputPath, $transcriptPath)
            if ($problem.InteractionAnswerPath) {
                $judgeArgs += $problem.InteractionAnswerPath
            }
            $mainResult = Invoke-InteractivePair -ContestantFilePath $mainInvocation.FilePath -ContestantArguments $mainInvocation.Arguments -InteractorFilePath $judgePath -InteractorArguments $judgeArgs -WorkingDirectory $problem.WorkspacePath -TimeoutMs $timeoutMs
            if ($mainResult.Verdict -ne "AC") {
                $message = "主解未通过交互：case=$($caseInfo.Name), verdict=$($mainResult.Verdict)"
                if ($mainResult.ContestantStderr) { $message += "`ncontestant stderr:`n$($mainResult.ContestantStderr.Trim())" }
                if ($mainResult.InteractorStderr) { $message += "`ninteractor stderr:`n$($mainResult.InteractorStderr.Trim())" }
                Add-Failure -Workspace $problem.Slug -Stage "run-main" -Message $message -Command ($mainResult.ContestantCommand + " <-> " + $mainResult.InteractorCommand)
            }
        }

        $referenceSolutions = @($problem.Solutions | Where-Object { $_.Role -eq "reference" })
        Write-Stage -Stage "check-reference" -Message $problem.Slug
        foreach ($reference in $referenceSolutions) {
            $referenceInvocation = Get-Invocation -Problem $problem -Entry $reference -CompiledPrograms $compiledPrograms
            foreach ($caseInfo in $validGeneratedCases) {
                if ($caseInfo.CheckWith.Count -gt 0 -and $reference.Name -notin $caseInfo.CheckWith) { continue }
                if (-not (Test-CaseMatchesEntry -Case $caseInfo -Entry $reference)) { continue }

                $transcriptPath = Join-Path (Split-Path -Parent $caseInfo.InputPath) ($caseInfo.Name + "." + $reference.Name + ".interactor.out")
                $judgeArgs = @($caseInfo.InputPath, $transcriptPath)
                if ($problem.InteractionAnswerPath) {
                    $judgeArgs += $problem.InteractionAnswerPath
                }
                $referenceResult = Invoke-InteractivePair -ContestantFilePath $referenceInvocation.FilePath -ContestantArguments $referenceInvocation.Arguments -InteractorFilePath $judgePath -InteractorArguments $judgeArgs -WorkingDirectory $problem.WorkspacePath -TimeoutMs $timeoutMs
                if ($referenceResult.Verdict -ne "AC") {
                    $message = "参考解未通过交互：solution=$($reference.Name), case=$($caseInfo.Name), verdict=$($referenceResult.Verdict)"
                    if ($referenceResult.ContestantStderr) { $message += "`ncontestant stderr:`n$($referenceResult.ContestantStderr.Trim())" }
                    if ($referenceResult.InteractorStderr) { $message += "`ninteractor stderr:`n$($referenceResult.InteractorStderr.Trim())" }
                    Add-Failure -Workspace $problem.Slug -Stage "check-reference" -Message $message -Command ($referenceResult.ContestantCommand + " <-> " + $referenceResult.InteractorCommand)
                }
            }
        }

        Write-Stage -Stage "check-wrong" -Message $problem.Slug
        foreach ($wrong in $problem.WrongSolutions) {
            $wrongInvocation = Get-Invocation -Problem $problem -Entry $wrong -CompiledPrograms $compiledPrograms
            $testedCases = 0
            $failedCases = 0
            foreach ($caseInfo in $validGeneratedCases) {
                if (-not (Test-CaseMatchesEntry -Case $caseInfo -Entry $wrong)) { continue }
                $testedCases += 1
                $transcriptPath = Join-Path (Split-Path -Parent $caseInfo.InputPath) ($caseInfo.Name + "." + $wrong.Name + ".interactor.out")
                $judgeArgs = @($caseInfo.InputPath, $transcriptPath)
                if ($problem.InteractionAnswerPath) {
                    $judgeArgs += $problem.InteractionAnswerPath
                }
                $wrongResult = Invoke-InteractivePair -ContestantFilePath $wrongInvocation.FilePath -ContestantArguments $wrongInvocation.Arguments -InteractorFilePath $judgePath -InteractorArguments $judgeArgs -WorkingDirectory $problem.WorkspacePath -TimeoutMs $timeoutMs
                if ($wrongResult.Verdict -ne "AC") {
                    $failedCases += 1
                    if ($wrong.Expected -eq "fail") {
                        break
                    }
                }
                if ($wrong.Expected -eq "fail" -and $failedCases -gt 0) {
                    break
                }
            }

            if ($testedCases -eq 0) {
                if ($wrong.Expected -eq "observe") {
                    Write-Stage -Stage "info" -Message "observe $($wrong.Name): no matched cases"
                } else {
                    Add-Failure -Workspace $problem.Slug -Stage "check-wrong" -Message "错解未匹配到任何测试点：$($wrong.Name)"
                }
            } elseif ($wrong.Expected -eq "fail" -and $failedCases -eq 0) {
                Add-Failure -Workspace $problem.Slug -Stage "check-wrong" -Message "错解在所有测试点上都通过了：$($wrong.Name)"
            } elseif ($wrong.Expected -eq "pass" -and $failedCases -gt 0) {
                Add-Failure -Workspace $problem.Slug -Stage "check-wrong" -Message "方案本应通过，但被数据卡掉了：$($wrong.Name)"
            } elseif ($wrong.Expected -eq "observe") {
                $passedCases = $testedCases - $failedCases
                Write-Stage -Stage "info" -Message "observe $($wrong.Name): passed=$passedCases failed=$failedCases"
            }
        }
    }

    Write-Stage -Stage "success" -Message "$($problem.Slug) passed $($generatedCases.Count) cases."
}

if (-not $script:IsWindowsHost) {
    # 怎么 ulimit 这玩意这么复杂
    Write-Stage -Stage "info" -Message "检测到在非 Windows 平台，正在开大栈空间"
    $rLimitType = Get-Content (Join-Path $PSScriptRoot "lib/RLimit.cs") -Raw
    Add-Type $rLimitType
    $val = [RLimit+rlimit]::new()
    [RLimit]::getrlimit(3, [ref]$val)
    $val.rlim_cur = $val.rlim_max
    if ([RLimit]::setrlimit(3, [ref]$val) -ne 0) {
        Write-Warning "未能开大栈空间，可能导致爆栈。如果失败，可以尝试在 bash 中使用 ulimit -s unlimited && $(" " -join $args) 来重试。"
    }
}

$workspaceList = Resolve-WorkspaceList -RepoRoot $repoRoot -Requested $Workspace
foreach ($workspacePath in $workspaceList) {
    Test-OneWorkspace -WorkspacePath $workspacePath
}

if ($script:Failures.Count -gt 0) {
    Write-Host ""
    Write-Host "失败的测试用例：" -ForegroundColor Red
    foreach ($failure in $script:Failures) {
        Write-Host "- [$($failure.Workspace)] [$($failure.Stage)] $($failure.Message)"
        if ($failure.Command) {
            Write-Host "  repro: $($failure.Command)"
        }
    }
    exit 1
}

Write-Host "全部测试通过。" -ForegroundColor Green
