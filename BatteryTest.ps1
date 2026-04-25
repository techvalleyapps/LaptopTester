#Requires -Version 3.0
<#
.SYNOPSIS
    LaptopTester — Battery Diagnostic Tool
.DESCRIPTION
    Reads battery health from WMI, shows a colour-coded health bar,
    generates a Windows powercfg battery report, and offers to open it.
    Run as Administrator for full capacity data.
#>

# ── Console setup ──────────────────────────────────────────────────────────────
$Host.UI.RawUI.WindowTitle = "LaptopTester — Battery Test"
try { $Host.UI.RawUI.BackgroundColor = 'Black'; Clear-Host } catch {}

# ── Helpers ────────────────────────────────────────────────────────────────────
function Write-Divider { Write-Host ("  " + ("─" * 52)) -ForegroundColor DarkGray }

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Divider
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Divider
}

function Write-Stat {
    param([string]$Label, [string]$Value, [string]$Color = 'White')
    Write-Host ("  {0,-30}" -f "${Label}:") -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor $Color
}

function Format-Bar {
    param([double]$Pct, [int]$Width = 24)
    $filled = [math]::Round($Pct / 100 * $Width)
    $filled = [math]::Max(0, [math]::Min($filled, $Width))
    return ("█" * $filled) + ("░" * ($Width - $filled))
}

function Format-Minutes {
    param([int]$Minutes)
    if ($Minutes -le 0 -or $Minutes -ge 71582788) { return "—" }
    $h = [math]::Floor($Minutes / 60)
    $m = $Minutes % 60
    if ($h -gt 0) { return "${h}h ${m}m" } else { return "${m}m" }
}

# ── Check admin ────────────────────────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

# ── Banner ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
Write-Host "  ║         LaptopTester  —  Battery Diagnostic         ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
Write-Host ""

if (-not $isAdmin) {
    Write-Host "  ⚠  Not running as Administrator." -ForegroundColor Yellow
    Write-Host "     Capacity data may be unavailable." -ForegroundColor DarkYellow
    Write-Host "     Right-click the script → Run as Administrator for full results." -ForegroundColor DarkYellow
}

# ══════════════════════════════════════
# 1. LIVE STATUS  (Win32_Battery)
# ══════════════════════════════════════
Write-Section "1 / 3  —  LIVE STATUS"

$bat = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue

if ($bat) {
    $level = [int]$bat.EstimatedChargeRemaining
    $bar   = Format-Bar $level
    $lvlColor = if ($level -gt 50) {'Green'} elseif ($level -gt 20) {'Yellow'} else {'Red'}

    $statusMap = @{
        1='Other'; 2='Unknown'; 3='Fully Charged'; 4='Low'; 5='Critical';
        6='Charging'; 7='Charging / High'; 8='Charging / Low';
        9='Charging / Critical'; 10='Undefined'; 11='Partially Charged'
    }
    $statusStr = $statusMap[[int]$bat.BatteryStatus]
    $statusColor = if ($bat.BatteryStatus -in 3,6,7) {'Green'} elseif ($bat.BatteryStatus -in 4,8) {'Yellow'} else {'White'}

    Write-Stat "Charge Level"   "$level%   [$bar]"  $lvlColor
    Write-Stat "Battery Status" $statusStr           $statusColor
    Write-Stat "Device ID"      $bat.DeviceID
    if ($bat.Name)     { Write-Stat "Name"     $bat.Name }
    if ($bat.Chemistry -and $bat.Chemistry -ne '') {
        $chemMap = @{1='Other';2='Unknown';3='Lead Acid';4='Nickel Cadmium';5='Nickel Metal Hydride';6='Lithium-Ion';7='Zinc Air';8='Lithium Polymer'}
        $chem = if ($chemMap.ContainsKey([int]$bat.Chemistry)) { $chemMap[[int]$bat.Chemistry] } else { $bat.Chemistry }
        Write-Stat "Chemistry" $chem
    }
    if ($bat.EstimatedRunTime) {
        Write-Stat "Est. Run Time" (Format-Minutes ([int]$bat.EstimatedRunTime)) 'Cyan'
    }
} else {
    Write-Host "  Could not retrieve Win32_Battery data." -ForegroundColor Red
    Write-Host "  This can happen on desktops or if WMI is restricted." -ForegroundColor DarkRed
}

# ══════════════════════════════════════
# 2. CAPACITY & HEALTH
# ══════════════════════════════════════
Write-Section "2 / 3  —  CAPACITY & HEALTH"

$designCap = $null
$fullCap   = $null

try {
    $wmiStatic = Get-WmiObject -Class BatteryStaticData -Namespace root\wmi -ErrorAction Stop
    $designCap = [long]$wmiStatic.DesignedCapacity
} catch {
    # silent — will show unavailable below
}

try {
    $wmiFull = Get-WmiObject -Class BatteryFullChargedCapacity -Namespace root\wmi -ErrorAction Stop
    $fullCap = [long]$wmiFull.FullChargedCapacity
} catch {}

# Fallback via ACPI WMI
if (-not $designCap -or -not $fullCap) {
    try {
        $acpi = Get-WmiObject -Namespace root\wmi -Class MSBatteryClass -ErrorAction Stop
        if (-not $designCap -and $acpi.DesignedCapacity)     { $designCap = $acpi.DesignedCapacity }
        if (-not $fullCap   -and $acpi.FullChargedCapacity)  { $fullCap   = $acpi.FullChargedCapacity }
    } catch {}
}

if ($designCap -gt 0) {
    Write-Stat "Design Capacity"       "$designCap mWh"  'DarkGray'
} else {
    Write-Stat "Design Capacity"       "Unavailable — run as Admin"  'DarkYellow'
}

if ($fullCap -gt 0) {
    Write-Stat "Full Charge Capacity"  "$fullCap mWh"  'White'
} else {
    Write-Stat "Full Charge Capacity"  "Unavailable — run as Admin"  'DarkYellow'
}

if ($designCap -gt 0 -and $fullCap -gt 0) {
    $health     = [math]::Round(($fullCap / $designCap) * 100, 1)
    $healthBar  = Format-Bar $health
    $healthColor = if ($health -ge 80) {'Green'} elseif ($health -ge 60) {'Yellow'} else {'Red'}
    $healthMsg   = if ($health -ge 80) {'Good — battery is healthy'} `
                   elseif ($health -ge 60) {'Fair — consider replacing soon'} `
                   else {'Poor — replacement recommended'}

    Write-Host ""
    Write-Host ("  {0,-30}" -f "Battery Health:") -NoNewline -ForegroundColor DarkGray
    Write-Host "$health%   [$healthBar]" -ForegroundColor $healthColor
    Write-Host ("  {0,-30}" -f "") -NoNewline
    Write-Host $healthMsg -ForegroundColor $healthColor
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "  Cannot calculate health without capacity data." -ForegroundColor DarkYellow
    Write-Host "  Re-run as Administrator to get these values." -ForegroundColor DarkYellow
    Write-Host ""
}

# ══════════════════════════════════════
# 3. GENERATE BATTERY REPORT
# ══════════════════════════════════════
Write-Section "3 / 3  —  WINDOWS BATTERY REPORT"

$reportPath = Join-Path $env:USERPROFILE "battery-report-laptoptester.html"

if ($isAdmin) {
    Write-Host "  Generating report (this takes a few seconds)..." -ForegroundColor Gray
    try {
        $null = & powercfg /batteryreport /output "$reportPath" 2>&1
        if (Test-Path $reportPath) {
            Write-Host "  ✓ Report saved: $reportPath" -ForegroundColor Green
            Write-Host ""
            $open = Read-Host "  Open report in your browser? (Y / N)"
            if ($open -match '^[Yy]') {
                Start-Process $reportPath
                Write-Host "  Opening report..." -ForegroundColor Cyan
            }
        } else {
            Write-Host "  ✗ Report file not found after running powercfg." -ForegroundColor Red
        }
    } catch {
        Write-Host "  ✗ Error running powercfg: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  Skipped — Administrator rights required for powercfg." -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "  To generate manually, open PowerShell as Admin and run:" -ForegroundColor Gray
    Write-Host "  powercfg /batteryreport /output `"$reportPath`"" -ForegroundColor DarkCyan
}

# ── Done ───────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Divider
Write-Host "  Done. Press any key to close..." -ForegroundColor DarkGray
Write-Divider
Write-Host ""
try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { Read-Host "Press Enter" | Out-Null }
