# Requires icpc-common.ps1. Local emulation of Polygon's interactive first invocation.
function Read-CommunicationConfig {
    param([hashtable]$Config)
    if (-not $Config.ContainsKey('communication')) { return $null }
    if (-not [bool]$Config.interactive -or -not $Config.ContainsKey('runTwice') -or
        $Config.runTwice -ne $true -or -not $Config.ContainsKey('interactiveSecondInvocation') -or
        $Config.interactiveSecondInvocation -ne $false -or -not $Config.ContainsKey('interactor') -or
        -not $Config.ContainsKey('checker')) {
        throw 'Polygon-style 通信题要求 interactive=true、runTwice=true、interactiveSecondInvocation=false，并同时声明 interactor 与 checker。'
    }
    $spec = $Config.communication
    if ($spec -isnot [hashtable]) { throw 'communication 必须是配置对象。' }
    foreach ($key in @('sourceLength', 'messageLength', 'maxChanges', 'maxCases')) {
        if (-not $spec.ContainsKey($key) -or $spec[$key] -isnot [ValueType] -or
            [double]$spec[$key] -ne [int]$spec[$key] -or [int]$spec[$key] -lt 1) {
            throw "communication.$key 必须是正整数。"
        }
    }
    if ($spec.maxChanges -gt $spec.sourceLength) { throw 'maxChanges 不得超过 sourceLength。' }
    if (-not $spec.ContainsKey('alphabet') -or $spec.alphabet -isnot [string] -or
        $spec.alphabet -notmatch '^[a-z]+$' -or
        @($spec.alphabet.ToCharArray() | Select-Object -Unique).Count -ne $spec.alphabet.Length) {
        throw 'communication.alphabet 必须由互异的小写英文字母构成。'
    }
    return $spec
}

function Invoke-Communication {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][hashtable]$Spec,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][int]$TimeoutMs,
        [Parameter(Mandatory = $true)][int]$MemoryLimitMb,
        [Parameter(Mandatory = $true)][string]$InteractorFilePath,
        [Parameter(Mandatory = $true)][string]$PythonCommand
    )
    $runRoot = Join-Path $RepoRoot ('.codex-test-artifacts/communication/' + [guid]::NewGuid().ToString('N'))
    $aliceDir = Join-Path $runRoot 'alice'
    $bobDir = Join-Path $runRoot 'bob'
    $judgeDir = Join-Path $runRoot 'interactor'
    foreach ($dir in @($runRoot, $aliceDir, $bobDir, $judgeDir)) { [IO.Directory]::CreateDirectory($dir) | Out-Null }
    $encoding = [Text.UTF8Encoding]::new($false)
    $summary = [pscustomobject]@{
        Command = (Format-Command -FilePath $FilePath -Arguments $Arguments) + " [Polygon run-twice logs: $runRoot]"
        ExitCode = 0; TimedOut = $false; MemoryExceeded = $false
        Stdout = ''; Stderr = ''; ArtifactPath = $runRoot; Verdict = 'AC'
    }
    $toutPath = Join-Path $runRoot 'bob.in'
    $manifest = @{
        contestantCommand = @($FilePath) + $Arguments
        interactorCommand = @($InteractorFilePath, $InputFile, $toutPath)
        contestantDirectory = $aliceDir; interactorDirectory = $judgeDir; artifactPath = $runRoot
        timeoutMs = $TimeoutMs; memoryLimitMb = $MemoryLimitMb
        judgeGraceMs = 5000; protocol = $Spec
    }
    $manifestPath = Join-Path $runRoot 'commands.json'
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 12), $encoding)
    $brokerPath = Join-Path $RepoRoot 'scripts/lib/run-twice-runner.py'
    $broker = Invoke-External -RepoRoot $RepoRoot -FilePath $PythonCommand -Arguments @($brokerPath, $manifestPath) -TimeoutMs ($TimeoutMs + 15000)
    if ($broker.TimedOut -or $broker.ExitCode -ne 0) { throw "Polygon run-twice broker 失败：$($broker.Stderr)；日志=$runRoot" }
    $alice = $broker.Stdout | ConvertFrom-Json
    [IO.File]::WriteAllText((Join-Path $runRoot 'alice.result.json'), $broker.Stdout, $encoding)
    if ($alice.verdict -eq 'FAIL') { throw "interactor FAIL，不可作为错解被卡的证据：$($alice.interactorStderr) $($alice.diagnostic)；日志=$runRoot" }
    if ($alice.verdict -ne 'AC') {
        $summary.ExitCode = 1; $summary.Verdict = $alice.verdict
        $summary.TimedOut = $alice.verdict -eq 'TLE'; $summary.MemoryExceeded = $alice.verdict -eq 'MLE'
        $summary.Stderr = "Alice/interactor 执行失败：$($alice.verdict)`n$($alice.interactorStderr)`n$($alice.contestantStderr)`n$($alice.diagnostic)"
        return $summary
    }
    if (-not (Test-Path -LiteralPath $toutPath -PathType Leaf)) { throw 'interactor _ok 后没有产生 tout。' }
    # Forward exactly the interactor's tout; do not reconstruct or append any data here.
    $bob = Invoke-External -RepoRoot $RepoRoot -FilePath $FilePath -Arguments $Arguments -WorkingDirectory $bobDir -InputFile $toutPath -TimeoutMs $TimeoutMs -MemoryLimitMb $MemoryLimitMb -Environment @{ TEMP = $bobDir; TMP = $bobDir; TMPDIR = $bobDir }
    [IO.File]::WriteAllText((Join-Path $runRoot 'bob.out'), $bob.Stdout, $encoding)
    [IO.File]::WriteAllText((Join-Path $runRoot 'bob.stderr'), $bob.Stderr, $encoding)
    [IO.File]::WriteAllText((Join-Path $runRoot 'bob.result.json'), ($bob | Select-Object Command, ExitCode, TimedOut, MemoryExceeded | ConvertTo-Json), $encoding)
    if ($bob.TimedOut -or $bob.MemoryExceeded -or $bob.ExitCode -ne 0) {
        $summary.ExitCode = 1; $summary.TimedOut = $bob.TimedOut; $summary.MemoryExceeded = $bob.MemoryExceeded
        $summary.Verdict = if ($bob.MemoryExceeded) { 'MLE' } elseif ($bob.TimedOut) { 'TLE' } else { 'RE' }
        $summary.Stderr = "Bob 执行失败：exit=$($bob.ExitCode)`n$($bob.Stderr)"
        return $summary
    }
    # Polygon's checker sees the second invocation output only.
    $summary.Stdout = $bob.Stdout
    return $summary
}
