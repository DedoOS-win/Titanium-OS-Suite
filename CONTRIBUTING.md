# Contributing to Titanium OS Suite

Thank you for your interest in contributing!

## Adding a new language (always welcome)

Language files live in the `lang/` folder as `.psd1` files.

1. **Fork** this repository
2. **Copy** `lang/en-US.psd1` to `lang/YOUR-CULTURE.psd1`
   - Example: `lang/ja-JP.psd1` for Japanese, `lang/ar-SA.psd1` for Arabic
   - Use the standard Windows culture code (language-REGION)
3. **Translate** all values — keys must remain in English
4. **Open a Pull Request** with title: `[Lang] Add ja-JP translation`

The launcher (`launch.ps1`) and all scripts auto-detect the system language via `(Get-UICulture).Name`.
If your culture code is not in the supported list, add it to the `$_supported` array in each script.

### Template

Use `lang/en-US.psd1` as your translation template. Every key must be present.

---

## Reporting a bug

Open an **Issue** with:
- Your Windows edition and build number
- Which script you ran (`win11_HOME`, `win11_LTSC`, etc.)
- What happened vs what you expected
- Attach the log file from your Desktop (`win11_HOME_YYYY-MM-DD_HH-mm.txt`)

---

## Fixing a bug

1. Open an **Issue** first describing the bug
2. Fork and apply your fix
3. Pull Request must reference the Issue: `Fixes #123`
4. Include the Windows edition and build you tested on

---

## Suggesting a new feature

Open an Issue with tag `[Feature Request]`.  
New features are implemented by the maintainer — suggestions are welcome and will be evaluated.

---

## Code style guidelines

- PowerShell scripts must run as **SYSTEM** via PowerRun
- All user-facing strings must use `$Lang.KeyName` from `.psd1` files
- Technical log messages (while script runs) stay in **English**
- Test on real hardware before submitting

---

## What is NOT accepted

- Direct pushes to `main` — all changes go through Pull Requests
- Changes to `.ps1` logic without an associated Issue
- New features without prior discussion

---

**Maintainer:** Dedo  
**Project:** [github.com/DedoOS-win/Titanium-OS-Suite](https://github.com/DedoOS-win/Titanium-OS-Suite)
