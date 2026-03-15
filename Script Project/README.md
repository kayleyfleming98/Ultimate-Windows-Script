# Kayley's Mega Tool

Comprehensive Windows safety, performance, and maintenance script. Implements all requested features with no corners cut.

## How to run

### GUI (recommended)

Run **`KayleysMegaTool.ps1 -GUI`** for a simple window with:
- **CMD-style log** — black panel with green text showing every step in real time
- **Run** — starts the tune (runs in background, log updates live)
- **Clear log** — clears the log panel
- **Skip restore point** / **Skip MAS activation** — check before clicking Run

Right-click `KayleysMegaTool.ps1` → **Run with PowerShell** (will prompt for elevation).

### CLI

Right-click `KayleysMegaTool.ps1` → **Run with PowerShell**. The script will prompt for elevation and re-launch as Administrator if needed.

Or from an elevated PowerShell:

```powershell
cd "C:\Users\test\Desktop\Script Project"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\KayleysMegaTool.ps1
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-GUI` | Launch the graphical user interface instead of running CLI mode. |
| `-SkipRestorePoint` | Do not create the "[Username]_Safety" restore point or purge VSS shadows. |
| `-SkipMAS` | Do not download or run the Massgrave activation script. |
| `-SkipUpdateAllPackages` | Skip winget, Chocolatey, Store, and official-server package updates. |
| `-WhatIf` | Skip SFC/DISM repair and other optional destructive steps (restore point still runs unless `-SkipRestorePoint`). |

### Logging

- Set `$Script:VerboseLog = $true` at the top of the script for internal logging (default: on).
- Log file: `%TEMP%\KayleysMegaTool_yyyyMMdd_HHmmss.log`.

## Summary of actions

- **Safety:** Restore point named `[User]_Safety`, VSS purge, restore-frequency bypass, auto-elevation, verbose logging.
- **Performance:** Ultimate Performance plan, HAGS, Win32PrioritySeparation 0x26, power throttling off, TSC/IRQ8 tweaks, hibernation off, zero sleep/timeout, best-performance overlay.
- **Memory/Storage:** Memory compression off, large system cache, NTFS last access off, SSD ReTrim.
- **Bloatware:** Appx/Provisioned removal (Xbox, Skype, Bing, Maps, etc.), service hardening, scheduled task and Store auto-update disabled.
- **Privacy:** Location, Advertising ID, Activity Feed, Find My Device, input personalization, feedback/SIUF, search highlights disabled.
- **Security:** Remote Assistance off, SMBv1 off, admin shares off, WSH off, NetBIOS off.
- **UI:** Classic context menu, visual FX stripped, menu delay 0, faster shutdown, PowerShell .ps1 context, taskbar End Task, GodMode on Desktop.
- **Maintenance:** Temp/thumbcache/Recycle Bin clean, DNS/IP/Winsock reset, SFC + DISM, optional MAS activation.
- **Updates:** winget (sources + upgrade all), Chocolatey (self + upgrade all), Microsoft Store (trigger update check), and **official-server updates** for programs not in winget/choco — installers are downloaded from each program’s official site (Firefox, 7-Zip, VLC, Notepad++, Git, Sumatra PDF, KeePassXC, PuTTY, WinSCP, Audacity, GIMP, qBittorrent, HandBrake, Python, Node.js, LibreOffice, Zoom, etc.) and run silently. **Git (free) integration:** optional remote app list URL (e.g. GitHub raw JSON) keeps links up to date; GitHub API is used to resolve “latest” download URLs for apps that ship on GitHub Releases, so old/missing links are fixed automatically for those apps.
- **Advanced Omega Tweaks:** Network optimizations (TCP autotuning, RSS, NetDMA, task offloading, network throttling), gaming tweaks (mouse acceleration, Game DVR, FSO, HPET), privacy cleanup (OneDrive uninstall, Bing search, widgets, Meet Now, lock screen ads), service purges (Maps Manager, Remote Registry, Touch services), update controls (Delivery Optimization, maintenance wake-up, background apps), and high-impact settings (Spectre/Meltdown disable, VBS off, UAC lower, DMA remapping off, Edge optimizations, Cortana cloud kill).

**Reboot recommended** after running so all changes (especially BCD, drivers, and services) take effect.

### Keeping official-server download links up to date (Git integration)

- **GitHub “latest” links:** Apps that use **GitHub Releases** (Notepad++, KeePassXC, Audacity, etc.) are configured with `GitHubRepo` (+ optional `AssetPattern`) instead of a fixed URL. The script calls the **GitHub API** at runtime to get the latest release asset URL, so links never go stale.
- **Remote app list (optional):** Set `$Script:OfficialAppListUrl` in `KayleysMegaTool.ps1` to a URL that returns **JSON** (e.g. GitHub raw: `https://raw.githubusercontent.com/youruser/yourrepo/main/app-list.json`). The script will fetch that list each run and use it instead of (or as) the built-in list. Host the JSON in a Git repo; when you fix or add links, everyone gets the update. See `app-list.sample.json` for the JSON format (each item: `Name`, `Pattern`, and either `Url` or `GitHubRepo` + optional `AssetPattern`, plus `SilentArgs`, optional `FileName`).
