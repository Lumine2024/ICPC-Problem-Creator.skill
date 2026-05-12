function Get-TemplateContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplatePath
    )

    return [System.IO.File]::ReadAllText($TemplatePath, [System.Text.Encoding]::UTF8)
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Expand-Template {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [hashtable]$Replacements
    )

    $expanded = $Content
    foreach ($pair in $Replacements.GetEnumerator()) {
        $expanded = $expanded.Replace($pair.Key, $pair.Value)
    }
    return $expanded
}

function Format-Command {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    $parts = @($FilePath) + $Arguments
    return ($parts | ForEach-Object {
        if ($_ -match '\s') {
            '"' + ($_ -replace '"', '\"') + '"'
        } else {
            $_
        }
    }) -join ' '
}

function Assert-FileExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description 不存在：$Path"
    }
}

function ConvertTo-Array {
    param(
        [object]$Value
    )

    if ($null -eq $Value) {
        return ,@()
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return ,@($Value | ForEach-Object { [string]$_ })
    }
    return ,@([string]$Value)
}

function ConvertTo-LfText {
    param(
        [AllowNull()]
        [string]$Content
    )

    if ($null -eq $Content) {
        return ""
    }
    return ($Content -replace "`r`n", "`n" -replace "`r", "`n")
}

function Resolve-WorkspaceList {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [string[]]$Requested
    )

    if ($Requested -and $Requested.Count -gt 0) {
        return $Requested | ForEach-Object {
            if ([System.IO.Path]::IsPathRooted($_)) {
                [System.IO.Path]::GetFullPath($_)
            } else {
                [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $_))
            }
        }
    }

    return Get-ChildItem -LiteralPath $RepoRoot -Recurse -Filter "config.json" -File |
        Where-Object {
            $_.FullName -notmatch '[\\/]\.git[\\/]' -and
            $_.FullName -notmatch '[\\/]build[\\/]' -and
            $_.FullName -notmatch '[\\/]\.codex-test-artifacts[\\/]' -and
            $_.FullName -notmatch '[\\/]scripts[\\/]templates[\\/]'
        } |
        ForEach-Object { $_.Directory.FullName } |
        Sort-Object -Unique
}

function Resolve-ProblemPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $resolved = [System.IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $RelativePath))
    Assert-FileExists -Path $resolved -Description $Description
    return $resolved
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = $RepoRoot,
        [string]$InputFile,
        [int]$TimeoutMs = 0,
        [int]$MemoryLimitMb = 0,
        [int]$StartRetryCount = 5,
        [int]$StartRetryDelayMs = 300
    )

    $command = Format-Command -FilePath $FilePath -Arguments $Arguments
    Write-Host $command -ForegroundColor DarkGray

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $true
    foreach ($argument in $Arguments) {
        [void]$psi.ArgumentList.Add([string]$argument)
    }

    $started = $false
    $lastStartError = $null
    $process = $null
    foreach ($attempt in 1..([Math]::Max($StartRetryCount, 1))) {
        try {
            $process = [System.Diagnostics.Process]::new()
            $process.StartInfo = $psi
            [void]$process.Start()
            $started = $true
            break
        } catch {
            $lastStartError = $_
            if ($null -ne $process) {
                $process.Dispose()
            }
            $process = $null
            if ($attempt -lt $StartRetryCount) {
                Start-Sleep -Milliseconds $StartRetryDelayMs
            }
        }
    }
    if (-not $started) {
        throw $lastStartError
    }

    if ($InputFile) {
        $content = [System.IO.File]::ReadAllText($InputFile)
        $process.StandardInput.Write($content)
    }
    $process.StandardInput.Close()

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $timedOut = $false
    $memoryExceeded = $false
    $memoryLimitBytes = if ($MemoryLimitMb -gt 0) { [int64]$MemoryLimitMb * 1MB } else { 0L }
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $process.HasExited) {
        $shouldKill = $false
        if ($TimeoutMs -gt 0 -and $watch.ElapsedMilliseconds -gt $TimeoutMs) {
            $timedOut = $true
            $shouldKill = $true
        }
        if (-not $shouldKill -and $memoryLimitBytes -gt 0) {
            try {
                $process.Refresh()
                if ($process.WorkingSet64 -gt $memoryLimitBytes -or $process.PrivateMemorySize64 -gt $memoryLimitBytes) {
                    $memoryExceeded = $true
                    $shouldKill = $true
                }
            } catch {
            }
        }
        if ($shouldKill) {
            try {
                $process.Kill($true)
            } catch {
            }
            break
        }
        Start-Sleep -Milliseconds 50
    }

    $process.WaitForExit()
    $stdoutTask.Wait()
    $stderrTask.Wait()

    return [pscustomobject]@{
        Command        = $command
        ExitCode       = $process.ExitCode
        TimedOut       = $timedOut
        MemoryExceeded = $memoryExceeded
        Stdout         = $stdoutTask.Result
        Stderr         = $stderrTask.Result
    }
}

function Find-PythonCommand {
    param(
        [hashtable]$BuildConfig
    )

    if ($BuildConfig.ContainsKey("pythonCommand")) {
        return [string]$BuildConfig.pythonCommand
    }

    foreach ($candidate in @("python3", "python")) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }

    return $null
}

function Expand-TemplateTokens {
    param(
        [string[]]$Template,
        [hashtable]$Tokens
    )

    return ,@($Template | ForEach-Object {
        $value = [string]$_
        foreach ($key in $Tokens.Keys) {
            $value = $value.Replace("{{${key}}}", [string]$Tokens[$key])
        }
        $value
    })
}

function Wait-ForFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$TimeoutMs = 120000,
        [int]$PollIntervalMs = 250
    )

    $deadline = [System.Diagnostics.Stopwatch]::StartNew()
    while ($deadline.ElapsedMilliseconds -lt $TimeoutMs) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return $true
        }
        Start-Sleep -Milliseconds $PollIntervalMs
    }

    return (Test-Path -LiteralPath $Path -PathType Leaf)
}

function Get-ExecutableExtension {
    param(
        [bool]$IsWindowsHost
    )

    if ($IsWindowsHost) {
        return ".exe"
    }
    return ""
}

function Invoke-CppCompilation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Problem,
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [string[]]$Override = @(),
        [switch]$AddWindowsStackFlag
    )

    $tokens = @{
        source   = $SourcePath
        output   = $OutputPath
        include  = $Problem.IncludeDir
        standard = $Problem.Standard
    }

    $overrideArgs = ConvertTo-Array $Override
    if ($overrideArgs.Count -gt 0) {
        $expanded = Expand-TemplateTokens -Template $overrideArgs -Tokens $tokens
        $filePath = $expanded[0]
        $arguments = if ($expanded.Count -gt 1) { @($expanded[1..($expanded.Count - 1)]) } else { @() }
        return Invoke-External -RepoRoot $RepoRoot -FilePath $filePath -Arguments $arguments -WorkingDirectory $Problem.WorkspacePath
    }

    $cppCompileArgs = Expand-TemplateTokens -Template (ConvertTo-Array $Problem.BuildConfig.cppFlags) -Tokens $tokens
    $cppCompileArgs += @("-I", $Problem.IncludeDir, $SourcePath, "-o", $OutputPath)
    if ($AddWindowsStackFlag) {
        $cppCompileArgs += @("-Wl,--stack,268435456")
    }
    return Invoke-External -RepoRoot $RepoRoot -FilePath ([string]$Problem.BuildConfig.cppCompiler) -Arguments $cppCompileArgs -WorkingDirectory $Problem.WorkspacePath
}

function Get-Invocation {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Problem,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry,
        [Parameter(Mandatory = $true)]
        [hashtable]$CompiledPrograms
    )

    if ($Entry.Language -eq "cpp") {
        return [pscustomobject]@{
            FilePath  = [string]$CompiledPrograms[$Entry.Name]
            Arguments = @()
        }
    }

    if ($Entry.Language -eq "python") {
        if (-not $Problem.PythonCommand) {
            throw "存在 Python 方案，但未找到可用 python 解释器"
        }
        if ($Entry.RunCommand.Count -gt 0) {
            $expanded = Expand-TemplateTokens -Template $Entry.RunCommand -Tokens @{ path = $Entry.Path }
            return [pscustomobject]@{
                FilePath  = $expanded[0]
                Arguments = if ($expanded.Count -gt 1) { @($expanded[1..($expanded.Count - 1)]) } else { @() }
            }
        }
        return [pscustomobject]@{
            FilePath  = $Problem.PythonCommand
            Arguments = @($Entry.Path)
        }
    }

    throw "不支持的语言：$($Entry.Language)"
}
