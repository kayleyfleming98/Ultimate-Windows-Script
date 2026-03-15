# Quick load test - parse and dot-source scripts (no execution of main logic)
$ErrorActionPreference = 'Stop'
$parseErrors = $null
$tokens = $null

Write-Host "Checking KayleysMegaTool.ps1..."
$errs1 = $null
$tok1 = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path '.\KayleysMegaTool.ps1').Path,
    [ref]$tok1,
    [ref]$errs1
)
if ($errs1 -and $errs1.Count -gt 0) {
    Write-Host "Parse errors in KayleysMegaTool.ps1:" -ForegroundColor Red
    $errs1 | ForEach-Object { Write-Host "  $($_.Message) (Line $($_.Extent.StartLineNumber))" }
    exit 1
}
Write-Host "  Parse OK" -ForegroundColor Green

Write-Host "Dot-sourcing KayleysMegaTool.ps1 (load functions only)..."
try {
    . .\KayleysMegaTool.ps1
    Write-Host "  Load OK" -ForegroundColor Green
} catch {
    Write-Host "  Load error: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Checking key functions exist..."
$funcs = @('Invoke-KayleysMegaToolMain', 'Set-SafetyRestore', 'Set-PerformanceOmega', 'Invoke-UpdateAllPackages', 'Invoke-MASActivation', 'Get-ResolvedOfficialAppUpdateList')
foreach ($f in $funcs) {
    if (-not (Get-Command $f -ErrorAction SilentlyContinue)) {
        Write-Host "  Missing: $f" -ForegroundColor Red
        exit 1
    }
}
Write-Host "  All key functions present" -ForegroundColor Green

Write-Host "All checks passed." -ForegroundColor Green
