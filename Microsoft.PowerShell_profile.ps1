# *************** #
# ** Constants ** #
# *************** #

$caskaydiaCoveNerdFontLink = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/CascadiaCode.zip"

$userFolder = "C:\Users\$env:username"
$downloadsFolder = "$userFolder\Downloads"
$appDataLocal = "$userFolder\AppData\Local"

# ******************* #
# ** Initial Setup ** #
# ******************* #

# Check for Profile Updates
function Update-Profile {
    try {
        $url = "https://raw.githubusercontent.com/reecewbourgeois/powershell-user-profile/main/Microsoft.PowerShell_profile.ps1"
        $oldhash = Get-FileHash $PROFILE
        Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShell_profile.ps1"
        $newhash = Get-FileHash "$env:temp/Microsoft.PowerShell_profile.ps1"
        if ($newhash.Hash -ne $oldhash.Hash) {
            Copy-Item -Path "$env:temp/Microsoft.PowerShell_profile.ps1" -Destination $PROFILE -Force
            Write-Host "Profile has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        }
    }
    catch {
        Write-Error "Unable to check for `$profile updates"
    }
    finally {
        Remove-Item "$env:temp/Microsoft.PowerShell_profile.ps1" -ErrorAction SilentlyContinue
    }
}
Update-Profile

# See if Caskaydia Cove Nerd Font is installed
if (-not(Test-Path "$appDataLocal\Microsoft\Windows\Fonts\CaskaydiaCoveNerdFont-Regular.ttf")) {
    # Download the font
    Invoke-WebRequest -Uri $caskaydiaCoveNerdFontLink -OutFile "$downloadsFolder\CaskaydiaCoveNerdFont.zip"

    # Unzip the font
    Expand-Archive -Path "$downloadsFolder\CaskaydiaCoveNerdFont.zip" -DestinationPath "$downloadsFolder\CaskaydiaCoveNerdFont"

    # Install the font
    Copy-Item -Path "$downloadsFolder\CaskaydiaCoveNerdFont\CaskaydiaCoveNerdFont-Regular.ttf" -Destination "$appDataLocal\Microsoft\Windows\Fonts\"

    # Clean up
    Remove-Item -Path "$downloadsFolder\CaskaydiaCoveNerdFont.zip"
    Remove-Item -Path "$downloadsFolder\CaskaydiaCoveNerdFont" -Recurse
}

# See if oh-my-posh is installed
if (-not(Test-Path "$appDataLocal\Programs\oh-my-posh")) {
    # Install oh-my-posh
    Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))

    # Add to path so it can be run from within the same session
    $env:Path += ";$appDataLocal\Programs\oh-my-posh\bin"
}

# **************** #
# ** oh-my-posh ** #
# **************** #

# Grab the theme if it is not present
if (-not(Test-Path "$appDataLocal\Programs\oh-my-posh\themes\reecewbourgeois-theme.json")) {
    # Download the theme to the themes folder
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/reecewbourgeois/powershell-user-profile/main/reecewbourgeois-theme.json" -OutFile "$appDataLocal\Programs\oh-my-posh\themes\reecewbourgeois-theme.json"
}

oh-my-posh init pwsh --config "$appDataLocal\Programs\oh-my-posh\themes\reecewbourgeois-theme.json" | Invoke-Expression

# ******************** #
# ** Terminal Icons ** #
# ******************** #

# See if Terminal Icons is installed
if (-not(Test-Path "$userFolder\Documents\WindowsPowerShell\Modules\Terminal-Icons")) {
    # Install Terminal Icons
    Install-Module -Name Terminal-Icons -Scope CurrentUser
}

Import-Module -Name Terminal-Icons

# **************** #
# ** PSReadLine ** #
# **************** #

# PSReadLine won't work if PowerShellGet is the simplified version
if (Get-Module PowerShellGet | Select-Object -ExpandProperty Version | Where-Object { $_ -eq 1.0.0 }) {
    Write-Host "ERROR: Outdated PowerShellGet module detected. Please update it by running ""Install-Module -Name PowerShellGet -Force"" in an admin terminal and then restarting powershell." -ForegroundColor Red
    Pause
    Exit
}

# TODO: Need to test this
# Update PSReadLine so we have the extra options
if (Get-Module PSReadLine | Select-Object -ExpandProperty Version | Where-Object { $_ -lt 2.4.0 }) {
    Install-Module PSReadLine -AllowPrerelease -Force
}

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
