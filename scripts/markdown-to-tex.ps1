#!/usr/bin/env pwsh

<#
.SYNOPSIS
Convert a problem statement Markdown file to Polygon-style TeX.
.EXAMPLE
./scripts/markdown-to-tex.ps1 -InputPath examples/magic-and-crab/docs/statement.md
.EXAMPLE
./scripts/markdown-to-tex.ps1 -InputPath examples/a-plus-b/docs/statement.md -OutputPath examples/a-plus-b/docs/statement.tex
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-PlainText {
    param([string]$Value)

    # Markdown statements may already contain TeX commands and math. Callers
    # keep those spans out of this function.
    $Value = $Value.Replace('&', '\&').Replace('%', '\%').Replace('#', '\#')
    $Value = $Value.Replace('_', '\_').Replace('{', '\{').Replace('}', '\}')
    return $Value
}

function Convert-Inline {
    param([string]$Value)

    $result = [System.Text.StringBuilder]::new()
    $i = 0
    while ($i -lt $Value.Length) {
        $tail = $Value.Substring($i)
        $special = [regex]::Match($tail, '^(\$\$[\s\S]*?\$\$|\$(?:\\.|[^$])*\$|\\[A-Za-z]+(?:\{[^{}]*\})?|`[^`]*`|\*\*[^*]+\*\*|\*[^*]+\*|\[[^\]]+\]\([^)]*\))')
        if ($special.Success) {
            $token = $special.Value
            if ($token.StartsWith('`')) {
                $inner = $token.Substring(1, $token.Length - 2)
                [void]$result.Append('\tt{' + (Convert-PlainText $inner) + '}')
            }
            elseif ($token.StartsWith('**')) {
                [void]$result.Append('\textbf{' + (Convert-Inline $token.Substring(2, $token.Length - 4)) + '}')
            }
            elseif ($token.StartsWith('*')) {
                [void]$result.Append('\emph{' + (Convert-Inline $token.Substring(1, $token.Length - 2)) + '}')
            }
            elseif ($token.StartsWith('[')) {
                $link = [regex]::Match($token, '^\[([^\]]+)\]\(([^)]*)\)$')
                [void]$result.Append('\href{' + $link.Groups[2].Value + '}{' + (Convert-Inline $link.Groups[1].Value) + '}')
            }
            else {
                [void]$result.Append($token)
            }
            $i += $token.Length
            continue
        }

        $next = [regex]::Match($tail, '[\$\\`*\[]')
        $length = if ($next.Success -and $next.Index -gt 0) { $next.Index } else { 1 }
        [void]$result.Append((Convert-PlainText $tail.Substring(0, $length)))
        $i += $length
    }
    return $result.ToString()
}

function Add-Line {
    param([string]$Value = '')
    [void]$script:output.Add($Value)
}

function Close-List {
    if ($script:listKind) {
        Add-Line ('\end{' + $script:listKind + '}')
        $script:listKind = ''
    }
}

function Add-Example {
    param([string]$InputText, [string]$OutputText)
    Add-Line '\begin{example}'
    Add-Line ('\exmp{' + $InputText + '}{' + $OutputText + '}')
    Add-Line '\end{example}'
    Add-Line
}

function Add-Image {
    param([string]$Path)
    Close-List
    Add-Line '\begin{center}'
    Add-Line ('\includegraphics{' + $Path + '}')
    Add-Line '\end{center}'
    Add-Line
}

$sourcePath = (Resolve-Path -LiteralPath $InputPath).Path
if (-not $OutputPath) {
    $OutputPath = [System.IO.Path]::ChangeExtension($sourcePath, '.tex')
}
$targetPath = [System.IO.Path]::GetFullPath($OutputPath)
if ($sourcePath -eq $targetPath) {
    throw 'InputPath and OutputPath must differ.'
}
$sourceDir = [System.IO.Path]::GetDirectoryName($sourcePath)
$targetDir = [System.IO.Path]::GetDirectoryName($targetPath)

$content = [System.IO.File]::ReadAllText($sourcePath, [System.Text.Encoding]::UTF8)
$lines = [regex]::Split(($content -replace "`r`n?", "`n"), "`n")
$script:output = [System.Collections.Generic.List[string]]::new()
$script:listKind = ''
$inFence = $false
$fenceMarker = ''
$fenceLanguage = ''
$fenceLines = [System.Collections.Generic.List[string]]::new()
$inDisplayMath = $false
$section = ''
$sampleInput = $null
$sampleOutput = $null
$examplesSeen = $false

foreach ($line in $lines) {
    $fence = [regex]::Match($line, '^\s*(`{3,}|~{3,})([^`]*)$')
    if ($inFence) {
        if ($line -match ('^\s*' + [regex]::Escape($fenceMarker) + '\s*$')) {
            $body = ($fenceLines -join "`n").Trim([char]10)
            if ($section -eq 'Examples' -and $fenceLanguage -match '^(input|output)\d*$') {
                if ($fenceLanguage -match '^input') { $sampleInput = $body }
                else { $sampleOutput = $body }
                if ($null -ne $sampleInput -and $null -ne $sampleOutput) {
                    Add-Example -InputText $sampleInput -OutputText $sampleOutput
                    $sampleInput = $null
                    $sampleOutput = $null
                }
            }
            else {
                Add-Line '\begin{lstlisting}'
                foreach ($codeLine in $fenceLines) { Add-Line $codeLine }
                Add-Line '\end{lstlisting}'
                Add-Line
            }
            $inFence = $false
            $fenceLines.Clear()
        }
        else { [void]$fenceLines.Add($line) }
        continue
    }
    if ($inDisplayMath) {
        Add-Line $line
        if ($line.Contains('$$')) { $inDisplayMath = $false }
        continue
    }
    if ($line.TrimStart().StartsWith('$$')) {
        Close-List
        Add-Line $line
        if ([regex]::Matches($line, '\$\$').Count -lt 2) { $inDisplayMath = $true }
        continue
    }
    if ($fence.Success) {
        Close-List
        $inFence = $true
        $fenceMarker = $fence.Groups[1].Value
        $fenceLanguage = $fence.Groups[2].Value.Trim().ToLowerInvariant()
        continue
    }

    $heading = [regex]::Match($line, '^\s*(#{1,6})\s+(.+?)\s*#*\s*$')
    if ($heading.Success) {
        Close-List
        $name = $heading.Groups[2].Value.Trim()
        if ($heading.Groups[1].Value.Length -eq 1) { continue }
        if ($section -eq 'Examples' -and ($null -ne $sampleInput -or $null -ne $sampleOutput)) {
            throw "Unpaired input/output sample before heading '$name'."
        }
        switch -Regex ($name) {
            '^(题目内容|题目描述|题目背景|描述|题意|Problem Statement|Statement)$' { $section = 'Legend'; Add-Line '\Legend'; break }
            '^(输入格式|输入|Input|Input Format)$' { $section = 'Input'; Add-Line '\Input'; break }
            '^(输出格式|输出|Output|Output Format)$' { $section = 'Output'; Add-Line '\Output'; break }
            '^(交互协议|交互格式|交互|Interaction)$' { $section = 'Interaction'; Add-Line '\Interaction'; break }
            '^(样例(?:\s*\d+)?|样例输入输出|示例(?:\s*\d+)?|Examples?(?:\s*\d+)?|Samples?(?:\s*\d+)?)$' {
                $section = 'Examples'
                if (-not $examplesSeen) { Add-Line '\Examples'; $examplesSeen = $true }
                break
            }
            '^(样例说明|样例解释|说明|提示|Notes?|Explanation)$' { $section = 'Notes'; Add-Line '\Notes'; break }
            default {
                if (-not $section) { $section = 'Legend'; Add-Line '\Legend' }
                Add-Line ('\textbf{' + (Convert-Inline $name) + '}')
            }
        }
        continue
    }

    if (-not $section -and -not [string]::IsNullOrWhiteSpace($line)) {
        $section = 'Legend'
        Add-Line '\Legend'
    }
    if ([string]::IsNullOrWhiteSpace($line)) {
        if ($script:listKind) { Close-List }
        elseif ($script:output.Count -gt 0 -and $script:output[$script:output.Count - 1] -ne '') { Add-Line }
        continue
    }

    $image = [regex]::Match($line, '^\s*!\[[^\]]*\]\(([^)]+)\)\s*$')
    if ($image.Success) {
        $imagePath = [System.IO.Path]::GetFullPath((Join-Path $sourceDir $image.Groups[1].Value))
        if (-not [System.IO.File]::Exists($imagePath)) {
            throw "Image not found: $imagePath"
        }
        $relativeImagePath = [System.IO.Path]::GetRelativePath($targetDir, $imagePath).Replace('\', '/')
        Add-Image -Path $relativeImagePath
        continue
    }

    $bullet = [regex]::Match($line, '^\s*[-+*]\s+(.+)$')
    $numbered = [regex]::Match($line, '^\s*\d+[.)]\s+(.+)$')
    if ($bullet.Success -or $numbered.Success) {
        $kind = if ($bullet.Success) { 'itemize' } else { 'enumerate' }
        if ($script:listKind -ne $kind) {
            Close-List
            Add-Line ('\begin{' + $kind + '}')
            $script:listKind = $kind
        }
        $item = if ($bullet.Success) { $bullet.Groups[1].Value } else { $numbered.Groups[1].Value }
        Add-Line ('\item ' + (Convert-Inline $item))
        continue
    }

    Close-List
    Add-Line (Convert-Inline $line)
}

if ($inFence) { throw 'Unclosed Markdown code fence.' }
if ($inDisplayMath) { throw 'Unclosed display math block.' }
if ($null -ne $sampleInput -or $null -ne $sampleOutput) { throw 'Unpaired input/output sample.' }
Close-List
$result = (($script:output -join "`n").TrimEnd() + "`n")
[System.IO.Directory]::CreateDirectory($targetDir) | Out-Null
[System.IO.File]::WriteAllText($targetPath, $result, [System.Text.UTF8Encoding]::new($false))
Write-Output $targetPath
