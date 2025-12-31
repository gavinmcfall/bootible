# SSH Module - SSH Server Setup
# =============================
# Configures SSH server for remote access to this device.
#
# Features:
# - Set network profile to Private (required for SSH)
# - Enable OpenSSH Server for remote access to this device
# - Import authorized keys from private repo (allow other machines to SSH in)
# - Enable ICMPv4 (ping) responses
#
# Security notes:
# - Use Tailscale or similar for secure access over internet
# - Don't expose SSH directly to internet without proper hardening

if (-not (Get-ConfigValue "install_ssh" $false)) {
    Write-Status "SSH module disabled in config" "Info"
    return
}

# =============================================================================
# NETWORK PROFILE (Set to Private for SSH access)
# =============================================================================
# Public profile blocks more connections. Set to Private for SSH to work.

$enableSshServer = Get-ConfigValue "ssh_server_enable" $false

if ($enableSshServer) {
    $networkAdapter = Get-ConfigValue "static_ip.adapter" "Wi-Fi"

    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would set $networkAdapter network profile to Private" "Info"
    } else {
        try {
            $profile = Get-NetConnectionProfile -InterfaceAlias $networkAdapter -ErrorAction SilentlyContinue
            if ($profile) {
                if ($profile.NetworkCategory -ne 'Private') {
                    Set-NetConnectionProfile -InterfaceAlias $networkAdapter -NetworkCategory Private
                    Write-Status "Network profile set to Private for $networkAdapter" "Success"
                } else {
                    Write-Status "Network profile already Private for $networkAdapter" "Info"
                }
            } else {
                Write-Status "Could not find network adapter: $networkAdapter" "Warning"
            }
        } catch {
            Write-Status "Failed to set network profile: $_" "Warning"
        }
    }
}

# =============================================================================
# SSH SERVER (OpenSSH Server)
# =============================================================================
# Enable SSH server so other machines can SSH into this device.

if ($enableSshServer) {
    Write-Status "Configuring OpenSSH Server..." "Info"

    # Check if sshd service exists FIRST (before dry run check)
    $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue

    if ($sshd -and $sshd.Status -eq 'Running') {
        Write-Status "OpenSSH Server already installed and running" "Success"
    } elseif ($sshd) {
        # Service exists but not running - just start it
        if ($Script:DryRun) {
            Write-Status "[DRY RUN] Would start OpenSSH Server service" "Info"
        } else {
            try {
                Set-Service -Name sshd -StartupType Automatic
                Start-Service sshd
                Write-Status "OpenSSH Server started" "Success"
            } catch {
                Write-Status "Failed to start SSH Server: $_" "Error"
            }
        }
    } elseif ($Script:DryRun) {
        Write-Status "[DRY RUN] Would install/enable OpenSSH Server" "Info"
    } else {
        # Need to install OpenSSH Server
        try {
            Write-Status "Installing OpenSSH Server..." "Info"

            # Check if OpenSSH capability is already present (just not enabled)
            $capability = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }

            if ($capability.State -eq 'NotPresent') {
                # Need to install - use DISM which is faster than Add-WindowsCapability
                Write-Host "    Using DISM for faster install..." -ForegroundColor Gray
                $dismResult = dism /Online /Add-Capability /CapabilityName:OpenSSH.Server~~~~0.0.1.0 /NoRestart 2>&1
                if ($LASTEXITCODE -ne 0) {
                    # DISM failed, try Add-WindowsCapability as fallback
                    Write-Host "    DISM failed, trying Add-WindowsCapability..." -ForegroundColor Yellow
                    Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop | Out-Null
                }
                Write-Status "OpenSSH Server installed" "Success"
            } elseif ($capability.State -eq 'Staged') {
                # Already staged, just enable it
                Write-Host "    OpenSSH Server staged, enabling..." -ForegroundColor Gray
                Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' | Out-Null
                Write-Status "OpenSSH Server enabled" "Success"
            } else {
                Write-Status "OpenSSH Server capability present" "Info"
            }

            # Refresh service reference and configure
            Start-Sleep -Seconds 2
            $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue

            if ($sshd) {
                Set-Service -Name sshd -StartupType Automatic
                if ($sshd.Status -ne 'Running') {
                    Start-Service sshd
                    Write-Status "SSH Server started" "Success"
                }

                # Also configure ssh-agent for key management
                $agent = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
                if ($agent) {
                    Set-Service -Name ssh-agent -StartupType Automatic
                    if ($agent.Status -ne 'Running') {
                        Start-Service ssh-agent -ErrorAction SilentlyContinue
                    }
                }
            } else {
                Write-Status "SSH Server service not found after install - restart may be required" "Warning"
            }

        } catch {
            Write-Status "Failed to configure SSH Server: $_" "Error"
        }
    }

    # Configure SSH firewall rule (check for existing first)
    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would ensure SSH firewall rule exists" "Info"
    } else {
        try {
            # Check for existing SSH rules
            $existingSshRule = Get-NetFirewallRule -DisplayName "*SSH*" -ErrorAction SilentlyContinue |
                Where-Object { $_.Direction -eq "Inbound" -and $_.Enabled -eq 'True' }

            if (-not $existingSshRule) {
                # Also check by port
                $sshByPort = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {
                    $_.Direction -eq "Inbound" -and $_.Enabled -eq 'True'
                } | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue | Where-Object {
                    $_.LocalPort -eq 22 -and $_.Protocol -eq "TCP"
                }

                if (-not $sshByPort) {
                    New-NetFirewallRule -DisplayName "Allow SSH" -Direction Inbound `
                        -Protocol TCP -LocalPort 22 -Action Allow | Out-Null
                    Write-Status "SSH firewall rule created (port 22)" "Success"
                } else {
                    Write-Status "SSH firewall rule already exists (port 22)" "Info"
                }
            } else {
                Write-Status "SSH firewall rule already exists" "Info"
            }
        } catch {
            Write-Status "Failed to configure SSH firewall rule: $_" "Warning"
        }
    }
}

# =============================================================================
# AUTHORIZED KEYS (Allow other machines to SSH in)
# =============================================================================
# Import public keys from private repo to allow SSH access from those machines.
# Windows OpenSSH uses different locations for admin vs non-admin users:
# - Admin: C:\ProgramData\ssh\administrators_authorized_keys
# - Non-admin: %USERPROFILE%\.ssh\authorized_keys
# We copy to BOTH locations to ensure SSH works regardless of how user connects.

$importAuthorizedKeys = Get-ConfigValue "ssh_import_authorized_keys" $false
$authorizedKeysList = Get-ConfigValue "ssh_authorized_keys" @()

if ($importAuthorizedKeys -and $authorizedKeysList.Count -gt 0) {
    Write-Status "Importing authorized SSH keys..." "Info"

    # Define both locations
    $adminKeysPath = Join-Path $env:ProgramData "ssh\administrators_authorized_keys"
    $adminSshDir = Join-Path $env:ProgramData "ssh"
    $userKeysPath = Join-Path $env:USERPROFILE ".ssh\authorized_keys"
    $userSshDir = Join-Path $env:USERPROFILE ".ssh"

    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would import authorized keys to:" "Info"
        Write-Status "[DRY RUN]   - $adminKeysPath (admin)" "Info"
        Write-Status "[DRY RUN]   - $userKeysPath (user)" "Info"
        foreach ($keyFile in $authorizedKeysList) {
            Write-Status "[DRY RUN]   Key: $keyFile" "Info"
        }
    } else {
        try {
            # Build authorized_keys content from private repo
            # Check both possible locations: ssh-keys/ and files/ssh-keys/
            $keysContent = @()
            $privateRepoPath = $Script:PrivateRoot
            $keysDirs = @(
                (Join-Path $privateRepoPath "ssh-keys"),
                (Join-Path $privateRepoPath "files\ssh-keys")
            )

            foreach ($keyFile in $authorizedKeysList) {
                $keyFound = $false
                foreach ($keysDir in $keysDirs) {
                    $keyFilePath = Join-Path $keysDir $keyFile
                    if (Test-Path $keyFilePath) {
                        $keyContent = Get-Content $keyFilePath -Raw
                        $keysContent += $keyContent.Trim()
                        Write-Status "Added key: $keyFile" "Info"
                        $keyFound = $true
                        break
                    }
                }
                if (-not $keyFound) {
                    Write-Status "Key file not found: $keyFile (checked ssh-keys/ and files/ssh-keys/)" "Warning"
                }
            }

            if ($keysContent.Count -gt 0) {
                $keysData = $keysContent -join "`n"

                # === ADMIN LOCATION ===
                # Ensure ProgramData\ssh directory exists
                if (-not (Test-Path $adminSshDir)) {
                    New-Item -ItemType Directory -Path $adminSshDir -Force | Out-Null
                }
                # Write administrators_authorized_keys
                $keysData | Set-Content -Path $adminKeysPath -Force -NoNewline
                # Set correct permissions - only SYSTEM and Administrators
                Write-Host "    Setting permissions on administrators_authorized_keys..." -ForegroundColor Gray
                icacls $adminKeysPath /inheritance:r /grant "SYSTEM:F" /grant "Administrators:F" 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Status "Warning: Could not set admin permissions with icacls" "Warning"
                }
                Write-Status "Admin authorized_keys updated: $adminKeysPath" "Success"

                # === USER LOCATION ===
                # Ensure ~/.ssh directory exists
                if (-not (Test-Path $userSshDir)) {
                    New-Item -ItemType Directory -Path $userSshDir -Force | Out-Null
                }
                # Write user authorized_keys
                $keysData | Set-Content -Path $userKeysPath -Force -NoNewline
                # Set correct permissions - only the current user
                Write-Host "    Setting permissions on user authorized_keys..." -ForegroundColor Gray
                icacls $userKeysPath /inheritance:r /grant "$($env:USERNAME):F" 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Status "Warning: Could not set user permissions with icacls" "Warning"
                }
                Write-Status "User authorized_keys updated: $userKeysPath" "Success"

                Write-Status "Authorized keys imported to both locations ($($keysContent.Count) keys)" "Success"
            }
        } catch {
            Write-Status "Failed to import authorized keys: $_" "Error"
        }
    }
}

# =============================================================================
# ICMP (Ping) - Enable ping responses
# =============================================================================
# Enable ICMPv4 Echo Request so the device responds to ping.

$enableIcmp = Get-ConfigValue "ssh_enable_icmp" $true

if ($enableSshServer -and $enableIcmp) {
    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would enable ICMPv4 Echo Request (ping)" "Info"
    } else {
        try {
            # Check for existing ICMPv4 inbound rule
            $existingIcmpRule = Get-NetFirewallRule -DisplayName "*ICMP*" -ErrorAction SilentlyContinue |
                Where-Object { $_.Direction -eq "Inbound" -and $_.Enabled -eq 'True' }

            if (-not $existingIcmpRule) {
                # Also check vm-monitoring rule
                $vmIcmpRule = Get-NetFirewallRule -Name "vm-monitoring-icmpv4" -ErrorAction SilentlyContinue
                if ($vmIcmpRule -and $vmIcmpRule.Enabled -eq 'False') {
                    Enable-NetFirewallRule -Name "vm-monitoring-icmpv4"
                    Write-Status "ICMPv4 Echo Request enabled (vm-monitoring)" "Success"
                } elseif ($vmIcmpRule) {
                    Write-Status "ICMPv4 already enabled (vm-monitoring)" "Info"
                } else {
                    # Create new ICMPv4 rule
                    New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 `
                        -IcmpType 8 -Direction Inbound -Action Allow | Out-Null
                    Write-Status "ICMPv4 Echo Request rule created" "Success"
                }
            } else {
                Write-Status "ICMPv4 firewall rule already enabled" "Info"
            }
        } catch {
            Write-Status "Failed to enable ICMPv4: $_" "Warning"
        }
    }
}

Write-Status "SSH setup complete" "Success"
