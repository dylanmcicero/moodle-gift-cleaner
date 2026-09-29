$ErrorActionPreference = 'Stop'

$cleaner = Join-Path (Split-Path -Parent $PSScriptRoot) 'Clean-Gift.ps1'
$shell = if (Test-Path (Join-Path $PSHOME 'pwsh')) {
    Join-Path $PSHOME 'pwsh'
} else {
    Join-Path $PSHOME 'powershell.exe'
}
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('gift-cleaner-' + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($temp)
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Invoke-Cleaner {
    param([string]$InputPath)
    $messages = & $shell -NoProfile -File $cleaner $InputPath 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Messages = $messages }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ($Expected -cne $Actual) {
        throw "$Label`: expected '$Expected', got '$Actual'"
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if (-not $Condition) { throw $Label }
}

try {
    # A UTF-8 BOM and CRLF input produces a clean copy, retaining the question delimiter.
    $inputPath = Join-Path $temp 'questions with spaces.txt'
    $source = "::Q1:: Choose one {`r`n=A`r`n`r`n~B`r`n}`r`n`r`n::Q2:: True? {T}`r`n"
    [System.IO.File]::WriteAllText($inputPath, $source, (New-Object System.Text.UTF8Encoding($true)))
    $run = Invoke-Cleaner $inputPath
    Assert-Equal 0 $run.ExitCode 'BOM and CRLF exit code'
    $outputPath = Join-Path $temp 'questions with spaces_clean.gift'
    $bytes = [System.IO.File]::ReadAllBytes($outputPath)
    Assert-True (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191)) 'Output must have no BOM'
    Assert-Equal "::Q1:: Choose one {`n=A`n~B`n}`n`n::Q2:: True? {T}`n" ([System.IO.File]::ReadAllText($outputPath, $utf8)) 'Cleaned content'

    # An escaped closing brace in an answer is text, so the following blank line is still inside the answer block.
    $inputPath = Join-Path $temp 'escaped.txt'
    [System.IO.File]::WriteAllText($inputPath, "::Q1:: Pick {`n=literal \} brace`n`n~other`n}`n`n::Q2:: Next {F}`n", $utf8)
    $run = Invoke-Cleaner $inputPath
    Assert-Equal 0 $run.ExitCode 'Escaped brace exit code'
    Assert-Equal "::Q1:: Pick {`n=literal \} brace`n~other`n}`n`n::Q2:: Next {F}`n" ([System.IO.File]::ReadAllText((Join-Path $temp 'escaped_clean.gift'), $utf8)) 'Escaped brace cleanup'

    # Existing output is never overwritten by a repeated drag-and-drop.
    $run = Invoke-Cleaner $inputPath
    Assert-True ($run.ExitCode -ne 0) 'Existing output must cause an error'
    Assert-Equal "::Q1:: Pick {`n=literal \} brace`n~other`n}`n`n::Q2:: Next {F}`n" ([System.IO.File]::ReadAllText((Join-Path $temp 'escaped_clean.gift'), $utf8)) 'Existing output remains intact'

    # Invalid UTF-8 must not silently become replacement characters in a new file.
    $inputPath = Join-Path $temp 'invalid.txt'
    [System.IO.File]::WriteAllBytes($inputPath, [byte[]](0x3A, 0x3A, 0xFF, 0x0A))
    $run = Invoke-Cleaner $inputPath
    Assert-True ($run.ExitCode -ne 0) 'Invalid UTF-8 must cause an error'
    Assert-True (-not (Test-Path (Join-Path $temp 'invalid_clean.gift'))) 'Invalid UTF-8 must not produce output'

    Write-Host 'PASS: GIFT cleaner behavior'
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force
}
