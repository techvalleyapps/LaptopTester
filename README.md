# 🔧 LaptopTester

A lightweight, single-file browser tool for testing laptop hardware — no installs, no dependencies, works completely offline.

**Live demo:** `https://<your-username>.github.io/LaptopTester`

---

## Features

| Tab | What it tests |
|-----|--------------|
| ⌨️ **Keyboard** | Visual QWERTY layout — press every key to light it green; shows key name, code, and keyCode |
| 📷 **Camera** | Live webcam preview + device name, resolution, frame rate, aspect ratio, facing mode |
| 🔊 **Sound** | Tone generator for Bass / Low Mids / Mids / High Mids / Treble / White Noise; Left · Right · Both channel selector; custom frequency + wave type |
| 🔋 **Battery** | Live Battery API data (level, charging, time estimates) + health calculator using `powercfg` values + one-click copy for useful Windows commands |

---

## How to publish on GitHub Pages

### 1 — Create the repository

1. Go to [github.com/new](https://github.com/new)
2. Name it **LaptopTester** (or anything you like)
3. Set it to **Public**
4. Click **Create repository**

### 2 — Push the files

```bash
cd path\to\LaptopTester
git init
git add .
git commit -m "Initial commit — LaptopTester"
git branch -M main
git remote add origin https://github.com/<your-username>/LaptopTester.git
git push -u origin main
```

### 3 — Enable GitHub Pages

1. Open your repository on GitHub
2. Go to **Settings → Pages**
3. Under **Source**, choose **Deploy from a branch**
4. Select **main** branch and **/ (root)** folder
5. Click **Save**

Your site will be live at `https://<your-username>.github.io/LaptopTester` within about 30 seconds.

---

## Running locally (offline)

Just open `index.html` directly in any modern browser — no server needed.

> **Camera & microphone** require a secure context (HTTPS or localhost). Camera will work normally on the published GitHub Pages URL, but may be blocked when opening the file directly via `file://`. To test camera locally, use VS Code Live Server or `npx serve .`

---

## Battery health (Windows)

Run in PowerShell or CMD as Administrator:

```
powercfg /batteryreport /output "%USERPROFILE%\battery-report.html"
```

Open the generated HTML file, find **DESIGN CAPACITY** and **FULL CHARGE CAPACITY**, then paste those numbers into the Battery tab's health calculator.

---

## Tech stack

- Pure HTML + CSS + JavaScript — zero dependencies
- **Web Audio API** for all sound generation (no audio files)
- **MediaDevices API** (`getUserMedia`) for camera access
- **Battery Status API** for live battery data
- **KeyboardEvent.code** for reliable key detection across layouts

---

## License

MIT — free to use, fork, and modify.
