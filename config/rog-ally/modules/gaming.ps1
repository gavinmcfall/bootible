# Gaming Module - Game Platforms & Utilities
# ===========================================
# Installs gaming platforms, launchers, and utilities.
# Configure which to install in config.yml
#
# ROG Ally X Gaming Notes:
# - Steam is highly recommended - good controller support
# - GOG Galaxy 2.0 can unify all your libraries
# - Playnite is great for a unified gaming mode experience
# - Most launchers have handheld/controller-friendly modes

if (-not (Get-ConfigValue "install_gaming" $true)) {
    Write-Status "Gaming module disabled in config" "Info"
    return
}

# Gaming Platforms
# ----------------
$platforms = @(
    @{ Id = "Valve.Steam"; Name = "Steam"; Config = "install_steam" },
    @{ Id = "GOG.Galaxy"; Name = "GOG Galaxy"; Config = "install_gog_galaxy" },
    @{ Id = "EpicGames.EpicGamesLauncher"; Name = "Epic Games Launcher"; Config = "install_epic_launcher" },
    @{ Id = "ElectronicArts.EADesktop"; Name = "EA App"; Config = "install_ea_app" },
    @{ Id = "Ubisoft.Connect"; Name = "Ubisoft Connect"; Config = "install_ubisoft_connect" },
    @{ Id = "Amazon.Games"; Name = "Amazon Games"; Config = "install_amazon_games" }
)

foreach ($platform in $platforms) {
    if (Get-ConfigValue $platform.Config $false) {
        Install-WingetPackage -PackageId $platform.Id -Name $platform.Name
    }
}

# Battle.net requires install location (winget prompts otherwise)
if (Get-ConfigValue "install_battle_net" $false) {
    $battleNetLocation = Get-ConfigValue "battle_net_location" "$env:ProgramFiles\Battle.net"
    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would install Battle.net to: $battleNetLocation" "Info"
    } else {
        Write-Status "Installing Battle.net..." "Info"
        try {
            winget install --id "Blizzard.BattleNet" --location "$battleNetLocation" --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Status "Battle.net installed" "Success"
            } else {
                Write-Status "Battle.net may need manual installation" "Warning"
            }
        } catch {
            Write-Status "Battle.net installation failed: $_" "Warning"
        }
    }
}

# Game Launchers & Managers
# -------------------------
# These provide unified library management and better handheld UX

if (Get-ConfigValue "install_playnite" $false) {
    Install-WingetPackage -PackageId "Playnite.Playnite" -Name "Playnite"
    Write-Status "Playnite tip: Enable Fullscreen mode for controller-friendly UI" "Info"
}

if (Get-ConfigValue "install_launchbox" $false) {
    # LaunchBox needs manual download - not in winget
    Write-Status "LaunchBox: Download from https://www.launchbox-app.com/" "Warning"
}

# Controller Utilities
# --------------------

if (Get-ConfigValue "install_ds4windows" $false) {
    Install-WingetPackage -PackageId "Ryochan7.DS4Windows" -Name "DS4Windows"
    Write-Status "DS4Windows: Configure DualShock/DualSense controllers" "Info"
}

# Mod Managers
# ------------

if (Get-ConfigValue "install_nexus_mods" $false) {
    Install-WingetPackage -PackageId "NexusMods.Vortex" -Name "Vortex Mod Manager"
}

Write-Status "Gaming setup complete" "Success"
