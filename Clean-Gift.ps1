<#
.SYNOPSIS
    Clean common formatting problems in GIFT text files before Moodle import.

.DESCRIPTION
    Removes a UTF-8 BOM, writes UTF-8 without a BOM and LF line endings,
    and removes blank lines inside GIFT answer blocks. Original files are
    never modified. This is a normalizer, not a GIFT validator.

.EXAMPLE
    .\Clean-Gift.ps1 .\questions.txt

.EXAMPLE
    .\Clean-Gift.ps1 *.txt

.EXAMPLE
    Drag one or more files onto Clean-Gift.bat.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path
)

$ErrorActionPreference = 'Stop'

function Clean-GiftFile {
    param([string]$InputFile)

    if (-not (Test-Path -LiteralPath $InputFile -PathType Leaf)) {
        throw "Input file not found: $InputFile"
    }

    $item = Get-Item -LiteralPath $InputFile
    $outFile = Join-Path $item.DirectoryName ($item.BaseName + '_clean.gift')

    # Throw on invalid UTF-8 instead of silently replacing damaged characters.
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $text = [System.IO.File]::ReadAllText($item.FullName, $strictUtf8)
    $text = $text -replace '^\uFEFF', ''
    $lines = $text -split "`r`n|`r|`n"

    $out = New-Object System.Collections.Generic.List[string]
    $inAnswers = $false
    $removed = 0

    foreach ($line in $lines) {
        # In GIFT, a backslash escapes the following control character.
        # Ignore whole-line comments; braces in comments are not answer blocks.
        if (-not $line.TrimStart().StartsWith('//')) {
            $escaped = $false
            foreach ($char in $line.ToCharArray()) {
                if ($escaped) {
                    $escaped = $false
                    continue
                }
                if ($char -eq '\') {
                    $escaped = $true
                    continue
                }
                if ($char -eq '{') { $inAnswers = $true }
                if ($char -eq '}') { $inAnswers = $false }
            }
        }

        if ($inAnswers -and $line.Trim().Length -eq 0) {
            $removed++
            continue
        }
        $out.Add($line)
    }

    # Blank lines separate GIFT questions. Keep one, including after a
    # single-line answer block; leave other question and answer text alone.
    $result = ($out -join "`n") -replace "`n{3,}", "`n`n"
    $result = $result.TrimEnd([char[]]@("`r", "`n")) + "`n"

    # CreateNew refuses to overwrite an existing cleaned file, even if
    # another process created it after the input was read.
    $stream = New-Object System.IO.FileStream($outFile, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
    try {
        $writer = New-Object System.IO.StreamWriter($stream, (New-Object System.Text.UTF8Encoding($false)))
        try { $writer.Write($result) }
        finally { $writer.Dispose() }
    } finally {
        $stream.Dispose()
    }

    Write-Host "  $($item.Name): removed $removed blank line(s); wrote $($item.BaseName)_clean.gift" -ForegroundColor Green
}

Write-Host 'GIFT cleaner'
$failed = $false
foreach ($p in $Path) {
    # Try the supplied name literally before treating wildcard characters
    # as a glob pattern.
    $resolved = Resolve-Path -LiteralPath $p -ErrorAction SilentlyContinue
    if (-not $resolved) { $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue }
    $files = if ($resolved) { @($resolved | ForEach-Object { $_.ProviderPath }) } else { @($p) }

    foreach ($file in $files) {
        try { Clean-GiftFile -InputFile $file }
        catch {
            $failed = $true
            Write-Host "  ERROR $file`: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

if ($failed) { exit 1 }
Write-Host 'Done. Import the *_clean.gift files into Moodle as GIFT.'
