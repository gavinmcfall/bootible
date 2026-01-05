# Troubleshooting Guide

Common issues and solutions for ROG Ally and Steam Deck.

---

## Quick Reference

| Issue | Platform | Solution |
|-------|----------|----------|
| "Package not found" | ROG Ally | [Reset winget sources](#winget-source-issues) |
| Package install timeout | ROG Ally | [Check network/retry](#package-installation-failures) |
| GitHub push fails | ROG Ally | [Authenticate Git](#github-authentication-issues) |
| "Read-only filesystem" | Steam Deck | [Disable steamos-readonly](#read-only-filesystem) |
| Decky plugins fail silently | Steam Deck | [Add GitHub token](#decky-rate-limits) |
| SD card not detected | Steam Deck | [Check mount point](#sd-card-issues) |

---

## Debug Mode

Always run in dry-run mode first to preview changes without applying them.

### ROG Ally

```powershell
# From bootible directory
cd $env:USERPROFILE\bootible\config\rog-ally
.\Run.ps1 -DryRun
```

Dry run will:
- Validate all package IDs exist in winget/msstore
- Show which packages would be installed
- Check configuration syntax
- Create no changes to your system

### Steam Deck

```bash
cd ~/bootible/config/steamdeck
ansible-playbook playbook.yml --check --ask-become-pass
```

The `--check` flag runs in dry-run mode.

---

## Log Locations

### ROG Ally

Logs are saved automatically after each run:

| Location | When |
|----------|------|
| `private/logs/rog-ally/` | If using a private repo |
| `%TEMP%\bootible_*.log` | If no private repo |

**Log filenames:**
- `2025-01-05_143052_ally_dryrun.log` - Dry run
- `2025-01-05_143052_ally_run.log` - Actual run

**View recent logs:**
```powershell
# List logs
Get-ChildItem "$env:USERPROFILE\bootible\private\logs\rog-ally" | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# View latest log
Get-Content (Get-ChildItem "$env:USERPROFILE\bootible\private\logs\rog-ally\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
```

### Steam Deck

Ansible doesn't save logs by default. Enable logging:

```bash
# Add to your shell before running
export ANSIBLE_LOG_PATH=~/bootible-$(date +%Y%m%d-%H%M%S).log

# Then run playbook
ansible-playbook playbook.yml --ask-become-pass
```

---

## ROG Ally Issues

### Winget Source Issues

**Symptom:** Packages not found, or "no package found matching input criteria"

**Solution:** Reset and reinitialize winget sources:

```powershell
# Run as Administrator
winget source reset --force
winget source update

# Verify sources
winget source list
```

You should see both `winget` and `msstore` sources listed.

**If winget source is missing:**
```powershell
winget source add --name winget --arg "https://cdn.winget.microsoft.com/cache" --type "Microsoft.PreIndexed.Package"
```

### Package Installation Failures

**Symptom:** Package installs fail or timeout

**Common causes and solutions:**

| Cause | Solution |
|-------|----------|
| Network issues | Check internet connection, retry |
| Package ID changed | Run `winget search <name>` to find new ID |
| Installer hung | Wait or kill `winget.exe` process and retry |
| Already installed | Run `winget list` to check existing installs |

**Force reinstall a package:**
```powershell
winget uninstall --id "Package.Id"
winget install --id "Package.Id" --force
```

**VLC/Spotify specific:** These apps try Microsoft Store first, then fall back to winget. If both fail:
- VLC: Download from https://videolan.org
- Spotify: Install from Microsoft Store app manually

**VC++ Redistributable:** Winget often fails with `NO_APPLICABLE_INSTALLER`. Bootible uses Chocolatey as fallback. If Chocolatey isn't installed:
```powershell
# Install VC++ manually
winget install Microsoft.VCRedist.2015+.x64
winget install Microsoft.VCRedist.2015+.x86
```

### GitHub Authentication Issues

**Symptom:** Private repo logs fail to push, or "authentication failed"

**For HTTPS repos:**

1. Install Git Credential Manager (included with Git for Windows)
2. Push manually once to cache credentials:
   ```powershell
   cd $env:USERPROFILE\bootible\private
   git push
   ```
3. Enter your GitHub username and a [Personal Access Token](https://github.com/settings/tokens) (not your password)

**For SSH repos:**

1. Generate SSH key if you don't have one:
   ```powershell
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```
2. Add public key to GitHub: https://github.com/settings/keys
3. Test connection:
   ```powershell
   ssh -T git@github.com
   ```

**If SSH fails but HTTPS works:**
Bootible automatically falls back to HTTPS if SSH push fails.

### PowerShell YAML Module Issues

**Symptom:** "Cannot parse YAML configs" or module installation fails

**Offline installation:**
```powershell
# On a machine with internet
Save-Module -Name powershell-yaml -Path C:\Modules

# Copy C:\Modules folder to offline machine, then:
Import-Module C:\Modules\powershell-yaml
```

**Permission issues:**
```powershell
# Install for current user only
Install-Module -Name powershell-yaml -Scope CurrentUser -Force
```

### Not Running as Administrator

**Symptom:** Script exits immediately with "Please run as Administrator"

**Solution:**
1. Right-click PowerShell
2. Select "Run as Administrator"
3. Navigate to bootible and run again

Or from an existing PowerShell window:
```powershell
Start-Process powershell -Verb RunAs -ArgumentList "-NoExit -Command cd $env:USERPROFILE\bootible\config\rog-ally; .\Run.ps1"
```

---

## Steam Deck Issues

### Read-Only Filesystem

**Symptom:** `Read-only file system` errors when installing via pacman

**Solution:** SteamOS uses a read-only root by default. Disable temporarily:

```bash
sudo steamos-readonly disable
# Do your work (install packages, etc.)
sudo steamos-readonly enable
```

**Note:** Changes via pacman may be lost after SteamOS updates. For persistent installs, prefer:
- **Flatpak** for apps (survives updates)
- **pip --user** for Python packages (installs to home directory)

### Ansible Installation

**Best approach (survives updates):**
```bash
pip3 install --user ansible
export PATH="$HOME/.local/bin:$PATH"

# Make permanent
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

**Pacman approach (may need reinstall after updates):**
```bash
sudo steamos-readonly disable
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -Sy archlinux-keyring
sudo pacman -S ansible
sudo steamos-readonly enable
```

### Decky Rate Limits

**Symptom:** Some Decky plugins fail to install silently, or you see "API rate limit exceeded"

**Cause:** GitHub API limits unauthenticated requests to 60/hour. Each plugin installation makes multiple API calls.

**Solution:** Add a GitHub token to your config:

```yaml
# In your config.yml (private or default)
github_token: "ghp_your_token_here"
```

**Create a token:**
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Name it "Bootible" or similar
4. **No scopes needed** - leave all checkboxes unchecked
5. Generate and copy the token
6. Add to your config.yml

**How many plugins can I install without a token?**
- 3 or fewer: Usually fine
- 4-10: May hit limits
- 10+: Will almost certainly fail without token

### Decky Not Appearing

**Symptom:** Decky tab doesn't show in Quick Access Menu after install

**Solutions:**

1. **Restart Steam:**
   - Hold power button > Restart Steam

2. **Reinstall Decky:**
   ```bash
   # Remove and reinstall
   rm -rf ~/homebrew
   cd ~/bootible
   ansible-playbook config/steamdeck/playbook.yml --tags decky --ask-become-pass
   ```

3. **Check Decky service:**
   ```bash
   systemctl --user status plugin_loader
   ```

### SD Card Issues

**Symptom:** Games/ROMs path not detected, or emulation points to wrong location

**Check SD card mount:**
```bash
# See all mounted drives
lsblk

# Check if SD card is mounted
ls /run/media/deck/
```

**Common mount points:**
| Location | What it is |
|----------|------------|
| `/run/media/deck/<UUID>` | SD card (auto-mounted) |
| `/home/deck` | Internal storage |

**Configure paths in your config:**
```yaml
# For SD card storage
games_path: "/run/media/deck/<your-sd-card-uuid>/Games"
roms_path: "/run/media/deck/<your-sd-card-uuid>/Emulation/roms"
```

**Finding your SD card UUID:**
```bash
ls /run/media/deck/
# Output like: 12AB-34CD
```

### Sudo Password Not Set

**Symptom:** "No sudo password set" or sudo doesn't work

**Solution:** Set a password first:
```bash
passwd
# Enter and confirm your new password
```

Then re-run the bootstrap script.

### PGP Signature Errors

**Symptom:** Pacman fails with "signature from ... is unknown trust"

**Solution:**
```bash
sudo steamos-readonly disable
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -Sy archlinux-keyring
sudo steamos-readonly enable
```

---

## Re-running Bootible

### After Initial Setup

The bootstrap script creates a `bootible` command you can run from anywhere:

```bash
# Steam Deck
bootible

# ROG Ally (PowerShell as Admin)
bootible
```

### Pull Latest and Re-run

```bash
# Steam Deck
cd ~/bootible && git pull && ./targets/deck.sh

# ROG Ally (PowerShell as Admin)
cd $env:USERPROFILE\bootible
git pull
.\targets\ally.ps1
```

### Run Specific Modules Only

**ROG Ally:**
```powershell
.\Run.ps1 -Tags apps,gaming
```

**Steam Deck:**
```bash
ansible-playbook playbook.yml --tags apps,decky --ask-become-pass
```

---

## Getting Help

If you're still stuck:

1. **Check logs** (see [Log Locations](#log-locations))
2. **Run in dry-run mode** to see what's failing
3. **Search existing issues:** https://github.com/gavinmcfall/bootible/issues
4. **Open a new issue** with:
   - Device (ROG Ally / Steam Deck)
   - Error message (copy from logs)
   - Config settings (redact any tokens/secrets)
   - Steps to reproduce
