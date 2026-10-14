# Normalizes shell scripts to LF line endings.
#
# The dev Docker stack bind-mounts this working tree into Linux containers and
# runs scripts/*.sh with /bin/sh. If a shell script has CRLF endings (Windows
# checkout with core.autocrlf=true), sh fails immediately:
#
#   docker-dotnet-run.sh: 2: : not found
#   docker-dotnet-run.sh: 3: set: Illegal option -
#
# and every .NET service exits. .gitattributes pins "*.sh text eol=lf", but that
# only applies on the next checkout, so this repairs an existing tree in place.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File Normalize-ShLineEndings.ps1 [-Root <repo>]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$count = 0

# Walk the tree manually so node_modules and .git are pruned instead of scanned.
$pending = New-Object System.Collections.Stack
$pending.Push($Root)
while ($pending.Count -gt 0) {
    $dir = $pending.Pop()

    Get-ChildItem -LiteralPath $dir -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'node_modules' -and $_.Name -ne '.git' } |
        ForEach-Object { $pending.Push($_.FullName) }

    Get-ChildItem -LiteralPath $dir -Filter *.sh -File -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
            if ($bytes -contains 13) {
                $text = $utf8NoBom.GetString($bytes)
                $text = $text -replace "`r`n", "`n"
                $text = $text -replace "`r", "`n"
                [System.IO.File]::WriteAllText($_.FullName, $text, $utf8NoBom)
                Write-Host "[fix] CRLF -> LF: $($_.FullName.Substring($Root.Length + 1))"
                $count++
            }
        }
}

if ($count -gt 0) {
    Write-Host "[ok] Normalized $count shell script(s) to LF."
}
