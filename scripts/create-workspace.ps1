#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [switch]$Interactive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

if ($Name.IndexOfAny([char[]]@('/', '\')) -ge 0) {
    throw "Name 不能包含路径分隔符。"
}

if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    throw "Name 仅支持字母、数字、点、下划线和短横线，且必须以字母或数字开头。"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspacePath = Join-Path $repoRoot (Join-Path "examples" $Name)
if (Test-Path -LiteralPath $workspacePath) {
    throw "目标工作区已存在：$workspacePath"
}

$problemTitle = ($Name -split '[-_.]') | Where-Object { $_ } | ForEach-Object {
    if ($_.Length -eq 1) {
        $_.ToUpperInvariant()
    } else {
        $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1)
    }
}
$problemTitle = ($problemTitle -join ' ')

$replacements = @{
    "{{PROBLEM_NAME}}"  = $Name
    "{{PROBLEM_TITLE}}" = $problemTitle
}

$templateRoot = Join-Path $PSScriptRoot "templates"
$templateFlavorRoot = if ($Interactive) {
    Join-Path $templateRoot "interactive"
} else {
    Join-Path $templateRoot "standard"
}
$sharedTemplateRoot = Join-Path $templateRoot "shared"

$templateMap = @{
    Testlib         = Join-Path $sharedTemplateRoot "testlib.h"
    InteractLib     = Join-Path $sharedTemplateRoot "interactlib.py"
    Config          = Join-Path $templateFlavorRoot "config.json"
    Statement       = Join-Path $templateFlavorRoot "statement.md"
    Tutorial        = Join-Path $templateFlavorRoot "tutorial.md"
    WorkspaceReadme = Join-Path $templateFlavorRoot "readme.md"
    Generator       = Join-Path $templateFlavorRoot "generator.cpp"
    Validator       = Join-Path $templateFlavorRoot "validator.cpp"
    Judge           = Join-Path $templateFlavorRoot $(if ($Interactive) { "interactor.cpp" } else { "checker.cpp" })
    Solution        = Join-Path $templateFlavorRoot "solution.cpp"
    Solution2       = Join-Path $templateFlavorRoot "solution2.cpp"
    PythonSolution  = Join-Path $templateFlavorRoot "solution.py"
    WrongA          = Join-Path $templateFlavorRoot "wrong-a.cpp"
    WrongB          = Join-Path $templateFlavorRoot "wrong-b.cpp"
}

foreach ($templatePath in $templateMap.Values) {
    if (-not (Test-Path -LiteralPath $templatePath)) {
        throw "缺少模板文件：$templatePath"
    }
}

$directories = @(
    $workspacePath,
    (Join-Path $workspacePath "include"),
    (Join-Path $workspacePath "docs"),
    (Join-Path $workspacePath "src"),
    (Join-Path $workspacePath "src/generator"),
    (Join-Path $workspacePath "src/validator"),
    (Join-Path $workspacePath "src/checker"),
    (Join-Path $workspacePath "src/wrong")
)
foreach ($directory in $directories) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

Copy-Item -LiteralPath $templateMap.Testlib -Destination (Join-Path $workspacePath "include/testlib.h")
if ($Interactive) {
    Copy-Item -LiteralPath $templateMap.InteractLib -Destination (Join-Path $workspacePath "interactlib.py")
}
Write-Utf8File -Path (Join-Path $workspacePath "config.json") -Content (Expand-Template -Content (Get-TemplateContent $templateMap.Config) -Replacements $replacements)
Write-Utf8File -Path (Join-Path $workspacePath "docs/statement.md") -Content (Expand-Template -Content (Get-TemplateContent $templateMap.Statement) -Replacements $replacements)
Write-Utf8File -Path (Join-Path $workspacePath "docs/tutorial.md") -Content (Expand-Template -Content (Get-TemplateContent $templateMap.Tutorial) -Replacements $replacements)
Write-Utf8File -Path (Join-Path $workspacePath "readme.md") -Content (Expand-Template -Content (Get-TemplateContent $templateMap.WorkspaceReadme) -Replacements $replacements)
Write-Utf8File -Path (Join-Path $workspacePath "src/generator/generator.cpp") -Content (Expand-Template -Content (Get-TemplateContent $templateMap.Generator) -Replacements $replacements)
Write-Utf8File -Path (Join-Path $workspacePath "src/validator/validator.cpp") -Content (Expand-Template -Content (Get-TemplateContent $templateMap.Validator) -Replacements $replacements)
Write-Utf8File -Path (Join-Path $workspacePath ("src/checker/" + $(if ($Interactive) { "interactor.cpp" } else { "checker.cpp" }))) -Content (Expand-Template -Content (Get-TemplateContent $templateMap.Judge) -Replacements $replacements)
Write-Utf8File -Path (Join-Path $workspacePath "src/solution.cpp") -Content (Expand-Template -Content (Get-TemplateContent $templateMap.Solution) -Replacements $replacements)
Write-Utf8File -Path (Join-Path $workspacePath "src/solution2.cpp") -Content (Expand-Template -Content (Get-TemplateContent $templateMap.Solution2) -Replacements $replacements)
Write-Utf8File -Path (Join-Path $workspacePath "src/solution.py") -Content (Expand-Template -Content (Get-TemplateContent $templateMap.PythonSolution) -Replacements $replacements)
Write-Utf8File -Path (Join-Path $workspacePath "src/wrong/wrong-a.cpp") -Content (Expand-Template -Content (Get-TemplateContent $templateMap.WrongA) -Replacements $replacements)
Write-Utf8File -Path (Join-Path $workspacePath "src/wrong/wrong-b.cpp") -Content (Expand-Template -Content (Get-TemplateContent $templateMap.WrongB) -Replacements $replacements)

Write-Host "Workspace created at $workspacePath"
