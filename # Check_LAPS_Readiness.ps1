# ==============================================================
#  Check_LAPS_Readiness.ps1
#  Purpose: Pre-policy readiness check for Windows LAPS
#  Author : Hakim Abeoub
#  Run as: Administrator
# ==============================================================

Clear-Host
Write-Host "=== LAPS Readiness Check (Pre-Policy) ===" -ForegroundColor Cyan

# --------------------------------------------------------------
# 1️⃣ Azure AD Join status
# --------------------------------------------------------------
Write-Host "`n[1] Checking Azure AD Join status..."
$ds = & dsregcmd /status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host " - dsregcmd failed or not available." -ForegroundColor Yellow
    $azureJoined = $false
} else {
    if ($ds -match 'AzureAdJoined\s*:\s*YES') {
        Write-Host " - AzureAdJoined : YES" -ForegroundColor Green
        $azureJoined = $true
    } else {
        Write-Host " - AzureAdJoined : NO" -ForegroundColor Red
        $azureJoined = $false
    }
}

# --------------------------------------------------------------
# 2️⃣ Check for LAPS cmdlet/module
# --------------------------------------------------------------
Write-Host "`n[2] Checking for LAPS PowerShell module or cmdlet..."
$cmd = Get-Command -Name Invoke-LapsPolicyProcessing -ErrorAction SilentlyContinue
$mod = Get-Module -ListAvailable | Where-Object { $_.Name -match 'LAPS' -or $_.Name -match 'Microsoft.Windows.LAPS' }

if ($cmd) {
    Write-Host " - Found cmdlet: Invoke-LapsPolicyProcessing" -ForegroundColor Green
    $hasCmdlet = $true
} elseif ($mod) {
    Write-Host " - Found module: $($mod.Name)" -ForegroundColor Green
    $hasCmdlet = $true
} else {
    Write-Host " - No LAPS cmdlet or module found." -ForegroundColor Yellow
    $hasCmdlet = $false
}

# --------------------------------------------------------------
# 3️⃣ Check for LAPS DLL files
# --------------------------------------------------------------
Write-Host "`n[3] Checking for LAPS files in System32..."
$possiblePaths = @(
    "$env:windir\System32\laps.dll",
    "$env:windir\System32\LAPS.Management.dll",
    "$env:windir\System32\LAPS.dll",
    "$env:windir\System32\WindowsPowerShell\v1.0\Modules\LAPS"
)
$foundFiles = @()
foreach ($p in $possiblePaths) {
    if (Test-Path $p) { $foundFiles += $p }
}

if ($foundFiles.Count -gt 0) {
    Write-Host " - Found LAPS-related files:" -ForegroundColor Green
    $foundFiles | ForEach-Object { Write-Host "    $_" }
    $hasFiles = $true
} else {
    Write-Host " - No LAPS files found in common paths." -ForegroundColor Yellow
    $hasFiles = $false
}

# --------------------------------------------------------------
# 4️⃣ Local Administrator account
# --------------------------------------------------------------
Write-Host "`n[4] Checking local Administrator account..."
try {
    $localAdmin = Get-LocalUser -Name "Administrator" -ErrorAction Stop
    if ($localAdmin.Enabled) {
        Write-Host " - Local 'Administrator' exists and is ENABLED." -ForegroundColor Green
        $adminOk = $true
    } else {
        Write-Host " - Local 'Administrator' exists but is DISABLED." -ForegroundColor Yellow
        $adminOk = $false
    }
} catch {
    $nu = & net user Administrator 2>$null
    if ($nu -and $nu -match "The command completed successfully") {
        Write-Host " - Local 'Administrator' exists (detected via net user)." -ForegroundColor Green
        $adminOk = $true
    } else {
        Write-Host " - Local 'Administrator' account NOT FOUND." -ForegroundColor Red
        $adminOk = $false
    }
}

# --------------------------------------------------------------
# 5️⃣ Summary
# --------------------------------------------------------------
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host ("Azure AD Joined             : {0}" -f ($(if ($azureJoined) {"YES"} else {"NO"})))
Write-Host ("LAPS cmdlet/module present  : {0}" -f ($(if ($hasCmdlet) {"YES"} else {"NO"})))
Write-Host ("LAPS files present          : {0}" -f ($(if ($hasFiles) {"YES"} else {"NO"})))
Write-Host ("Local Administrator OK      : {0}" -f ($(if ($adminOk) {"YES"} else {"NO"})))

# --------------------------------------------------------------
# 6️⃣ Recommendations
# --------------------------------------------------------------
Write-Host "`n=== RECOMMENDATIONS ===" -ForegroundColor Cyan
if (-not $azureJoined) {
    Write-Host " - Device is NOT Azure AD joined. Cloud LAPS requires Azure AD join." -ForegroundColor Yellow
    Write-Host "   Run: dsregcmd /join OR enroll device in Intune." -ForegroundColor Yellow
}

if ($hasCmdlet -or $hasFiles) {
    Write-Host " - LAPS code is present. Ready to process policies." -ForegroundColor Green
    Write-Host "   You can test it using: Invoke-LapsPolicyProcessing" -ForegroundColor Green
} else {
    Write-Host " - LAPS component not found. Install it using:" -ForegroundColor Yellow
    Write-Host "   dism /online /add-capability /capabilityname:Microsoft.Windows.LAPS~~~~0.0.1.0" -ForegroundColor Yellow
}

if (-not $adminOk) {
    Write-Host " - Local Administrator disabled or missing. Enable with:" -ForegroundColor Yellow
    Write-Host "   net user Administrator /active:yes" -ForegroundColor Yellow
}

Write-Host "`nCheck completed successfully." -ForegroundColor Cyan

# --------------------------------------------------------------
# Keep window open
# --------------------------------------------------------------
Write-Host "`nPress any key to close..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
