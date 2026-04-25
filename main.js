const { app, BrowserWindow, ipcMain, shell } = require('electron');
const { exec } = require('child_process');
const path = require('path');
const fs   = require('fs');
const os   = require('os');

// ── Window ────────────────────────────────────────────────────────────────────
function createWindow() {
  const win = new BrowserWindow({
    width:  1200,
    height: 820,
    minWidth:  900,
    minHeight: 600,
    autoHideMenuBar: true,
    title: 'LaptopTester',
    webPreferences: {
      preload:          path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration:  false,
    },
  });
  win.loadFile('index.html');
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

// ── Helper: run a PS1 script from a temp file ─────────────────────────────────
function runPowerShell(script) {
  return new Promise((resolve) => {
    const tmp = path.join(os.tmpdir(), `lpt_${Date.now()}.ps1`);
    fs.writeFileSync(tmp, script, 'utf8');
    exec(
      `powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "${tmp}"`,
      { timeout: 20000, windowsHide: true },
      (err, stdout, stderr) => {
        try { fs.unlinkSync(tmp); } catch (_) {}
        if (err) { resolve({ __error: err.message }); return; }
        try   { resolve(JSON.parse(stdout.trim())); }
        catch { resolve({ __error: 'Parse error', __raw: stdout.trim() }); }
      }
    );
  });
}

// ── IPC: Get battery data ─────────────────────────────────────────────────────
ipcMain.handle('get-battery', () => runPowerShell(`
$out = @{}

# ── Win32_Battery (level, status, run time, name, chemistry) ──
try {
  $b = Get-WmiObject Win32_Battery -ErrorAction Stop
  $out.level   = [int]$b.EstimatedChargeRemaining
  $out.status  = [int]$b.BatteryStatus
  $out.runTime = if ($b.EstimatedRunTime -lt 71582788) { [int]$b.EstimatedRunTime } else { -1 }
  $out.name    = [string]$b.Name
  $out.chem    = [int]$b.Chemistry
  $out.mfg     = [string]$b.Manufacturer
} catch {
  $out.batErr  = $_.Exception.Message
}

# ── Design Capacity (mWh) ──
try {
  $s = Get-WmiObject -Class BatteryStaticData -Namespace root\\wmi -ErrorAction Stop
  $out.designCap = [long]$s.DesignedCapacity
} catch {
  $out.designErr = $_.Exception.Message
}

# ── Full Charge Capacity (mWh) ──
try {
  $f = Get-WmiObject -Class BatteryFullChargedCapacity -Namespace root\\wmi -ErrorAction Stop
  $out.fullCap = [long]$f.FullChargedCapacity
} catch {
  $out.fullErr = $_.Exception.Message
}

$out | ConvertTo-Json -Compress
`));

// ── IPC: Generate powercfg battery report + open it ──────────────────────────
ipcMain.handle('battery-report', () => runPowerShell(`
$out  = @{}
$path = Join-Path $env:USERPROFILE 'battery-report-laptoptester.html'
try {
  $null = & powercfg /batteryreport /output "$path" 2>&1
  if (Test-Path $path) {
    $out.success = $true
    $out.path    = $path
  } else {
    $out.success = $false
    $out.error   = 'Report file not created'
  }
} catch {
  $out.success = $false
  $out.error   = $_.Exception.Message
}
$out | ConvertTo-Json -Compress
`).then(async (result) => {
  if (result.success && result.path) {
    await shell.openPath(result.path);
  }
  return result;
}));
