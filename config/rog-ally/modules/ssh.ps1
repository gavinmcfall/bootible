# SSH Module - SSH Key Setup & GitHub Authentication
# ==================================================
# Generates SSH keys and configures GitHub for SSH authentication.
# This enables git operations via SSH instead of HTTPS.
#
# Why SSH keys?
# - More secure than password auth
# - No need to re-authenticate constantly
# - Works well with private repos
# - Keys are device-specific for easy revocation

if (-not (Get-ConfigValue "install_ssh" $false)) {
    Write-Status "SSH module disabled in config" "Info"
    return
}

# =============================================================================
# SSH KEY GENERATION
# =============================================================================

$sshDir = Join-Path $env:USERPROFILE ".ssh"
$keyName = Get-ConfigValue "ssh_key_name" $env:COMPUTERNAME
$keyPath = Join-Path $sshDir "id_ed25519"
$keyComment = "$keyName@bootible"

# Ensure .ssh directory exists with correct permissions
if (-not (Test-Path $sshDir)) {
    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would create ~/.ssh directory" "Info"
    } else {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        # Set permissions - only current user should have access
        $acl = Get-Acl $sshDir
        $acl.SetAccessRuleProtection($true, $false)
        $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $acl.AddAccessRule($userRule)
        Set-Acl $sshDir $acl
        Write-Status "Created ~/.ssh directory" "Success"
    }
}

# Generate SSH key if it doesn't exist
$generateKey = Get-ConfigValue "ssh_generate_key" $true

if ($generateKey) {
    if (Test-Path $keyPath) {
        Write-Status "SSH key already exists: $keyPath" "Info"
    } else {
        if ($Script:DryRun) {
            Write-Status "[DRY RUN] Would generate SSH key: $keyPath" "Info"
            Write-Status "[DRY RUN] Key comment: $keyComment" "Info"
        } else {
            Write-Status "Generating SSH key (ed25519)..." "Info"
            try {
                # Generate ed25519 key (modern, secure, fast)
                # -N "" means no passphrase (for automated use)
                $sshKeygenPath = "ssh-keygen"

                # Check if ssh-keygen exists
                $sshKeygen = Get-Command $sshKeygenPath -ErrorAction SilentlyContinue
                if (-not $sshKeygen) {
                    # Try Windows OpenSSH location
                    $sshKeygenPath = Join-Path $env:SystemRoot "System32\OpenSSH\ssh-keygen.exe"
                    if (-not (Test-Path $sshKeygenPath)) {
                        throw "ssh-keygen not found. Install OpenSSH Client feature."
                    }
                }

                # Generate the key
                & $sshKeygenPath -t ed25519 -C $keyComment -f $keyPath -N '""' 2>&1 | Out-Null

                if (Test-Path $keyPath) {
                    Write-Status "SSH key generated: $keyPath" "Success"
                    Write-Status "Key comment: $keyComment" "Info"
                } else {
                    throw "Key file not created"
                }
            } catch {
                Write-Status "Failed to generate SSH key: $_" "Error"
            }
        }
    }
}

# =============================================================================
# GITHUB SSH KEY SETUP
# =============================================================================

$addToGithub = Get-ConfigValue "ssh_add_to_github" $true

if ($addToGithub -and (Test-Path "$keyPath.pub")) {
    # Check if gh CLI is available and authenticated
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        Write-Status "GitHub CLI (gh) not found - cannot add key to GitHub" "Warning"
        Write-Status "Run bootible again after gh is installed to add key" "Info"
    } else {
        # Check if already authenticated
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Status "GitHub CLI not authenticated - cannot add key" "Warning"
            Write-Status "Run 'gh auth login' first, then run bootible again" "Info"
        } else {
            if ($Script:DryRun) {
                Write-Status "[DRY RUN] Would add SSH key to GitHub: $keyComment" "Info"
            } else {
                Write-Status "Adding SSH key to GitHub..." "Info"
                try {
                    # Check if key already exists on GitHub
                    $existingKeys = gh ssh-key list 2>&1
                    $pubKeyContent = Get-Content "$keyPath.pub" -Raw
                    $keyFingerprint = $pubKeyContent.Split(" ")[1]

                    if ($existingKeys -match [regex]::Escape($keyComment)) {
                        Write-Status "SSH key '$keyComment' already exists on GitHub" "Info"
                    } else {
                        # Add the key
                        $result = gh ssh-key add "$keyPath.pub" --title $keyComment 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Status "SSH key added to GitHub: $keyComment" "Success"
                        } else {
                            # Key might already exist with different title
                            if ($result -match "already in use") {
                                Write-Status "SSH key already registered on GitHub (different title)" "Info"
                            } else {
                                throw $result
                            }
                        }
                    }
                } catch {
                    Write-Status "Failed to add SSH key to GitHub: $_" "Error"
                }
            }
        }
    }
}

# =============================================================================
# SAVE PUBLIC KEY TO PRIVATE REPO
# =============================================================================

$saveToPrivate = Get-ConfigValue "ssh_save_to_private" $true
$privateRepoPath = Get-ConfigValue "ssh_private_repo_path" ""

# Auto-detect private repo path if not specified
if (-not $privateRepoPath -and $Script:PrivateRoot) {
    $privateRepoPath = $Script:PrivateRoot
}

if ($saveToPrivate -and $privateRepoPath -and (Test-Path "$keyPath.pub")) {
    $keysDir = Join-Path $privateRepoPath "ssh-keys"
    $keyBackupPath = Join-Path $keysDir "$keyName.pub"

    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would save public key to: $keyBackupPath" "Info"
    } else {
        try {
            # Create ssh-keys directory if needed
            if (-not (Test-Path $keysDir)) {
                New-Item -ItemType Directory -Path $keysDir -Force | Out-Null
            }

            # Copy public key
            Copy-Item "$keyPath.pub" $keyBackupPath -Force
            Write-Status "Public key saved to private repo: ssh-keys/$keyName.pub" "Success"

            # Git add (will be committed with log push)
            Push-Location $privateRepoPath
            git add "ssh-keys/$keyName.pub" 2>&1 | Out-Null
            Pop-Location
        } catch {
            Write-Status "Failed to save public key to private repo: $_" "Warning"
        }
    }
}

# =============================================================================
# CONFIGURE GIT TO USE SSH
# =============================================================================

$configureGitSsh = Get-ConfigValue "ssh_configure_git" $true

if ($configureGitSsh) {
    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would configure Git to use SSH for GitHub" "Info"
    } else {
        Write-Status "Configuring Git to use SSH for GitHub..." "Info"
        try {
            # Set Git to use SSH for GitHub URLs
            # This rewrites https://github.com/ to git@github.com:
            git config --global url."git@github.com:".insteadOf "https://github.com/"
            Write-Status "Git configured to use SSH for GitHub" "Success"

            # Ensure SSH key is in ssh-agent (for this session)
            $sshAgent = Get-Service ssh-agent -ErrorAction SilentlyContinue
            if ($sshAgent -and $sshAgent.Status -ne 'Running') {
                Start-Service ssh-agent -ErrorAction SilentlyContinue
            }

            # Add key to agent
            if (Test-Path $keyPath) {
                ssh-add $keyPath 2>&1 | Out-Null
            }
        } catch {
            Write-Status "Git SSH configuration failed: $_" "Warning"
        }
    }
}

# =============================================================================
# DISPLAY KEY INFO
# =============================================================================

if (Test-Path "$keyPath.pub") {
    $pubKey = Get-Content "$keyPath.pub" -Raw
    Write-Status "Public key fingerprint:" "Info"
    # Get fingerprint using ssh-keygen if available
    $fingerprint = ssh-keygen -lf "$keyPath.pub" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  $fingerprint" -ForegroundColor Cyan
    } else {
        # Fallback: show truncated key
        $keyParts = $pubKey.Split(" ")
        if ($keyParts.Count -ge 2) {
            $truncated = $keyParts[1].Substring(0, [Math]::Min(20, $keyParts[1].Length)) + "..."
            Write-Host "  $($keyParts[0]) $truncated" -ForegroundColor Cyan
        }
    }
}

Write-Status "SSH setup complete" "Success"
