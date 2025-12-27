# Bootible Code Review Report

## Overview
This report covers a full code review of the `bootible` repository, including PowerShell scripts for Windows (ROG Ally) and Ansible playbooks for Steam Deck.

**Review Date:** December 28, 2025
**Reviewer:** GitHub Copilot
**Status:** Re-review after changes.

## Summary
The repository is well-structured and implements a clever dual-bootstrapping mechanism for Windows and Linux handhelds. The separation of public code and private configuration is excellent.

**Update:** Critical bugs in the SSH role and network configuration have been resolved. The Ansible `nmcli` module is now correctly used. A few improvements remain outstanding.

---

## Resolved Issues ✅

### 1. Broken Handler in SSH Role (Steam Deck)
**File:** `steamdeck/roles/ssh/tasks/main.yml`
**Status:** **Fixed**
The task now correctly uses `register` and a conditional task instead of a missing handler. This ensures the SSH service is only restarted when the port configuration actually changes.

### 2. Destructive Network Configuration (Windows)
**File:** `rogally/modules/base.ps1`
**Status:** **Fixed**
The script now checks if the static IP is already set before applying changes. Crucially, it includes a `try...catch` block that attempts to restore DHCP if the static IP configuration fails, preventing network lockouts.

### 3. Ansible `nmcli` Module
**File:** `steamdeck/roles/base/tasks/main.yml`
**Status:** **Fixed**
The role now uses the `community.general.nmcli` module instead of raw shell commands, ensuring idempotency and cleaner execution.

---

## Outstanding Issues ⚠️

### 1. Fragile YAML Parser (ROG Ally)
**File:** `rogally/Run.ps1` -> `Import-YamlConfig` function
**Severity:** Medium

**Issue:**
The custom regex-based YAML parser relies on strict 2-space indentation (`^  (\w+):`) and does not handle lists (lines starting with `-`).

**Impact:**
- If a user uses 4 spaces or tabs in their `private/rogally/config.yml`, the parser will fail to read nested keys.
- List values (like `dns:` in `config.yml`) are completely ignored or parsed incorrectly.

**Recommendation:**
Consider using a more robust parsing logic or documenting the strict formatting requirements clearly. Alternatively, check if `powershell-yaml` can be installed via `Install-Module` if the user approves external dependencies.

### 2. GitHub API Rate Limits
**File:** `steamdeck/roles/decky/tasks/install_plugin.yml`
**Severity:** Low

**Issue:**
The role queries the GitHub API anonymously to find release assets.

**Risk:**
Unauthenticated requests are limited to 60 per hour. If a user installs many plugins or runs the playbook frequently, they will hit this limit.

**Recommendation:**
Add a `github_token` variable to `config.yml` (optional) and use it in the `ansible.builtin.uri` task if present.

### 3. Ansible PATH in Bootstrap
**File:** `bootstrap.sh`
**Severity:** Low

**Issue:**
The script installs Ansible via `pip install --user ansible` and exports PATH for the current session, but doesn't persist it.

**Recommendation:**
Add a check to see if `~/.local/bin` is in the user's `.bashrc` or `.profile`, and add it if missing. This ensures `ansible-playbook` works in future terminal sessions.

```bash
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi
```

---

## Conclusion
The critical stability and safety issues have been addressed. The remaining issues are primarily around robustness (YAML parsing) and edge cases (API limits, PATH persistence). The codebase is in a much better state.
