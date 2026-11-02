#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Workspace,
    [Parameter(Mandatory = $true)][string]$Program,
    [string]$InteractorProgram = '',
    [string[]]$ProgramArguments = @(),
    [Parameter(Mandatory = $true)][string]$InputFile,
    [Parameter(Mandatory = $true)][string]$OutputFile
)
. (Join-Path $PSScriptRoot 'lib/icpc-common.ps1')
. (Join-Path $PSScriptRoot 'lib/communication.ps1')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$communicationRepoRoot = Split-Path -Parent $PSScriptRoot
$workspacePath = (Resolve-Path -LiteralPath $Workspace).Path
$inputPath = (Resolve-Path -LiteralPath $InputFile).Path
$outputPath = [IO.Path]::GetFullPath($OutputFile)
if ([IO.Path]::IsPathRooted($Program) -or (Test-Path -LiteralPath $Program)) {
    $programPath = (Resolve-Path -LiteralPath $Program).Path
} else {
    $programPath = (Get-Command $Program -ErrorAction Stop).Source
}
$config = Get-Content -LiteralPath (Join-Path $workspacePath 'config.json') -Raw | ConvertFrom-Json -AsHashtable
$spec = Read-CommunicationConfig -Config $config
if ($null -eq $spec) { throw '工作区未声明 communication。' }
$python = Find-PythonCommand -BuildConfig $config.build
if (-not $python) { throw 'Polygon run-twice 本地管道调度需要 Python 3。' }
if (-not $InteractorProgram) {
    $extension = Get-ExecutableExtension -IsWindowsHost ([Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows))
    $InteractorProgram = Join-Path $communicationRepoRoot ('.codex-test-artifacts/build/' + $config.slug + '/bin/interactor' + $extension)
}
$interactorPath = (Resolve-Path -LiteralPath $InteractorProgram).Path
# Python/script arguments should use absolute paths: both phases run in empty directories.
$result = Invoke-Communication -RepoRoot $communicationRepoRoot -Spec $spec -FilePath $programPath -Arguments $ProgramArguments -InputFile $inputPath -TimeoutMs $config.timeLimitMs -MemoryLimitMb $config.memoryLimitMb -InteractorFilePath $interactorPath -PythonCommand $python
if ($result.ExitCode -ne 0) {
    throw "通信调度失败：$($result.Stderr) TLE=$($result.TimedOut) MLE=$($result.MemoryExceeded)；日志：$($result.ArtifactPath)"
}
[IO.File]::WriteAllText($outputPath, $result.Stdout, [Text.UTF8Encoding]::new($false))
Write-Host "Polygon 双次运行完成（Bob 输出需另交 checker 校验）：$outputPath；日志：$($result.ArtifactPath)"
