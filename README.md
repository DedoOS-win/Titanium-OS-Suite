# 🚀 Titanium OS Suite (v8.5)
### *Advanced Kernel-Level Tuning & System Hardening for Windows 11*

[![OS](https://img.shields.io/badge/OS-Windows%2011-blue)](https://github.com/DedoOS-win/Titanium-OS-Suite)
[![Edition](https://img.shields.io/badge/Edition-Home%20%7C%20Pro%20%7C%20LTSC-cyan)](https://github.com/DedoOS-win/Titanium-OS-Suite)
[![Build](https://img.shields.io/badge/Build-26100%20(24H2)-orange)](https://github.com/DedoOS-win/Titanium-OS-Suite)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Languages](https://img.shields.io/badge/Languages-10-blueviolet)](https://github.com/DedoOS-win/Titanium-OS-Suite/tree/main/lang)

**Titanium OS** is an elite PowerShell optimization framework for power users, professionals (CAD/Adobe) and advanced gamers who demand total control over their Windows environment.

Unlike standard "debloaters," Titanium uses **.NET API Token Elevation** and **Registry ACL Hard-Locking** to make optimizations permanent and protected from system reverts — surviving Windows Updates.

---

## ⚡ Quick Launch

> **Requirement:** Open PowerShell and paste the command below.  
> The launcher auto-detects your Windows edition, shows a menu in **your system language**, and runs everything as **NT AUTHORITY\SYSTEM** — no files written to disk, no Defender interference.

```powershell
irm https://dedo-os.dedonato-paolo.workers.dev | iex
```

**How it works:**
1. A menu appears in your system language (10 languages supported)
2. Your Windows edition is detected automatically and highlighted
3. Select your module — if you pick the wrong edition, a warning appears
4. PowerRun is extracted silently and launches a SYSTEM session
5. The selected module runs entirely **in memory** — no files on disk
6. PowerRun is automatically cleaned up after execution

---

## 📋 Available Modules

### 🟢 Community Edition — Free & Open Source

| Module | Target | Key Features |
|--------|--------|-------------|
| **Win11 Home** `win11_HOME.ps1` | Windows 11 Home (all variants: N, SL, China) | Copilot/Teams/Recall removal, Defender+Tamper Protection disable, HVCI kill via DISM, WU hard lock, AntiZombie task |
| **Win11 LTSC** `win11_LTSC.ps1` | IoT LTSC 24H2 (S, SN variants) | Zero-latency kernel tuning, hard-lock telemetry, no Defender present, hypervisorlaunchtype off |
| **Adobe Workstation** `win11_ADOBE.ps1` | Any edition | Auto-detects Licensed vs Portable Adobe. Blocks telemetry, preserves Firefly AI & license services |

### 💎 Titanium Premium Bundle — Supporters Only

| Module | Description |
|--------|-------------|
| **Win11 Pro** | HVCI/Hyper-V conditional, dual-layer WU GPO, Teams popup |
| **OEM Update Control** | Intelligent *Unlock → Update → Re-seal* cycle |
| **Persistence Engine** | Monthly XML task to keep your system clean automatically |
| **Autodesk & Office Pro** | Maximum performance tuning for CAD/3D and productivity suites |
| **Direct Support** | Technical assistance for custom workstation setups |

**[👉 Support the project & unlock the Premium Bundle (PayPal)](https://paypal.me/fastwindows)**

> After your contribution, include your email in the PayPal notes to receive the Premium scripts.

---

## 🔧 What It Actually Does

### Memory & Performance
**Adaptive Memory Engine** detects your exact hardware (CPU cores, RAM speed, USB audio devices, Hyper-V state) and applies the optimal configuration: adaptive pagefile sizing, SvcHost split threshold tuned per RAM amount, memory compression logic, and kernel timer optimization safe for VirtualBox and USB audio interfaces.

### Telemetry & Privacy
**Ghost Trigger Elimination** goes beyond simply disabling services — it deletes the SCM trigger registrations that would silently restart DiagTrack, WerSvc and dmwappushservice after a reboot. Combined with firewall rules blocking Microsoft telemetry endpoints, data collection is permanently eliminated.

### Windows Update Control
**Hard Lock + Soft Lock architecture**: UsoSvc and WaaSMedicSvc receive ACL Deny on their registry keys (impossible to re-enable without taking ownership), while wuauserv gets a soft lock (Start=4) compatible with WU-Control for manual update sessions.

### Security Hardening
**Tamper Protection → Defender → SmartScreen** — the sequence matters. The script disables Tamper Protection first via registry, then Defender real-time protection via both policy and MpPreference API, then SmartScreen across all 6 activation vectors (Explorer, System policy, AppHost, Edge, process kill, task scheduler).

### SSD/NVMe Optimization
Enables TRIM, disables Last Access Timestamp writes, disables 8.3 filename generation, turns off scheduled defragmentation, disables prefetch/ReadyBoot (useless on NVMe), and applies FeatureManagement kernel overrides for NTFS write-back cache and NVMe queue depth.

### Bloatware Removal
Removes Xbox, Teams, Bing suite, Cortana, Clipchamp, Mixed Reality, Skype, Feedback Hub and more via AppxPackage + provisioned package removal. An **AntiZombie scheduled task** runs at startup (5-minute delay, light mode) to prevent reinstallations after Windows Updates.

---

## 🌍 Supported Languages

The launcher and all scripts automatically detect your Windows UI language:

| Code | Language | Code | Language |
|------|----------|------|----------|
| `en-US` | English (fallback) | `de-DE` | German |
| `it-IT` | Italian | `es-ES` | Spanish |
| `ru-RU` | Russian | `fr-FR` | French |
| `zh-CN` | Chinese (Simplified) | `pt-BR` | Portuguese |
| `tr-TR` | Turkish | `pl-PL` | Polish |

**Want to add your language?** See [CONTRIBUTING.md](CONTRIBUTING.md) — it takes 15 minutes and only requires translating a `.psd1` file.

---

## 📂 Repository Structure

```
Titanium-OS-Suite/
├── launch.ps1              ← Entry point (irm | iex)
├── win11_HOME.ps1          ← Win11 Home module
├── win11_LTSC.ps1          ← IoT LTSC 24H2 module
├── win11_ADOBE.ps1         ← Adobe Workstation module
├── lang/                   ← Localization files
│   ├── en-US.psd1
│   ├── it-IT.psd1
│   └── ...
├── CONTRIBUTING.md
└── README.md
```

---

## 🛠️ Requirements

| Requirement | Detail |
|-------------|--------|
| **OS** | Windows 11 Build 26100+ (24H2) |
| **Editions** | Home (all variants), IoT LTSC 24H2 (S/SN), Pro (Premium) |
| **Privileges** | Handled automatically by the launcher via PowerRun |
| **Internet** | Required for `irm` launch — scripts run in-memory |
| **PowerShell** | 5.1+ (included in Windows 11) |

---

## 🔐 File Integrity (SHA-256)

Verify file integrity before execution:

```powershell
Get-FileHash .\win11_HOME.ps1 -Algorithm SHA256
```

| File | SHA-256 |
|------|---------|
| `win11_HOME.ps1` | `6A2AE0DB95A65803943EEB7B32D2A70E79089C915B0AABCC58EA165A26D638DF` |
| `win11_LTSC.ps1` | `D944AB2CF7AD30C578F504052361D09C59619488D40530ED9233EAEE096B9B83` |
| `launch.ps1` | `DDA8C165C17D07986CE37B684DB4F1DC6181983BCA4FB96D5DF715899B537DF7` |

> Hashes are updated at each official release. Verify against [Releases](https://github.com/DedoOS-win/Titanium-OS-Suite/releases).

---

## ✅ What It Does & ❌ What It Doesn't

**✅ Does:**
- Permanently disables telemetry with ghost trigger elimination
- Removes Copilot, Teams, Bing, Recall, Xbox bloatware
- Blocks Windows Update aggressive behavior (WU-Control compatible)
- Optimizes timers, memory, I/O, network, GPU priority
- Generates a readable report on your Desktop in your language
- Creates a System Restore point before any modification

**❌ Does NOT:**
- Remove Edge or WebView2 (required by many modern apps)
- Touch USB audio drivers or introduce audio distortion
- Modify Hyper-V if active (WSL2/Sandbox preserved)
- Break PIN, Windows Hello or RDP on Microsoft accounts
- Work on domain-joined or MDM-managed machines (not designed for corporate environments)

---

## ⚠️ Disclaimer

These scripts perform deep kernel-level and registry modifications.  
**The author is not responsible for data loss or system instability.**  
A System Restore point is created automatically before execution.  
Tested on physical hardware with Windows 11 Build 26100.

---

## 🤝 Contributing

- **Adding a language** → always welcome, see [CONTRIBUTING.md](CONTRIBUTING.md)
- **Bug reports** → open an Issue with your log file
- **Bug fixes** → open an Issue first, then a PR referencing it
- **New features** → open a Feature Request Issue

---

**Maintained by Dedo | Leading-edge Windows Engineering**  
[github.com/DedoOS-win/Titanium-OS-Suite](https://github.com/DedoOS-win/Titanium-OS-Suite)
