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
Set-PSReadLineOption -Colors @{
    Command   = 'Yellow'
    Parameter = 'Green'
    String    = 'DarkCyan'
}

# ********************* #
# ** Custom Commands ** #
# ********************* #

# Credit: https://github.com/ChrisTitusTech/powershell-profile/blob/main/Microsoft.PowerShell_profile.ps1

function touch($file) { "" | Out-File $file -Encoding ASCII }

function ff($name) {
    if ($null -eq $name) {
        Write-Host "Please provide a file name to search for" -ForegroundColor Red
        return
    }

    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.directory)\$($_)"
    }
}

# Credit: https://stackoverflow.com/a/54297192/11003804
function Get-DirectorySize
{
  param(
    [Parameter(ValueFromPipeline)] [Alias('PSPath')]
    [string] $LiteralPath = '.',
    [switch] $Recurse,
    [switch] $ExcludeSelf,
    [int] $Depth = -1,
    [int] $__ThisDepth = 0 # internal use only
  )

  process {
    # Resolve to a full filesystem path, if necessary
    $fullName = if ($__ThisDepth) { $LiteralPath } else { Convert-Path -ErrorAction Stop -LiteralPath $LiteralPath }

    if ($ExcludeSelf) { # Exclude the input dir. itself; implies -Recurse
      $Recurse = $True
      $ExcludeSelf = $False
    } else { # Process this dir.
      # Calculate this dir's total logical size.
      # Note: [System.IO.DirectoryInfo].EnumerateFiles() would be faster, 
      # but cannot handle inaccessible directories.
      $size = [Linq.Enumerable]::Sum(
        [long[]] (Get-ChildItem -Force -Recurse -File -LiteralPath $fullName).ForEach('Length')
      )

      # Create a friendly representation of the size.
      $decimalPlaces = 2
      $padWidth = 8
      $scaledSize = switch ([double] $size) {
        {$_ -ge 1tb } { $_ / 1tb; $suffix='tb'; break }
        {$_ -ge 1gb } { $_ / 1gb; $suffix='gb'; break }
        {$_ -ge 1mb } { $_ / 1mb; $suffix='mb'; break }
        {$_ -ge 1kb } { $_ / 1kb; $suffix='kb'; break }
        default       { $_; $suffix='b'; $decimalPlaces = 0; break }
      }
  
      # Construct and output an object representing the dir. at hand.
      [pscustomobject] @{
        FullName = $fullName
        FriendlySize = ("{0:N${decimalPlaces}}${suffix}" -f $scaledSize).PadLeft($padWidth, ' ')
        Size = $size
      }
    }

    # Recurse, if requested.
    if ($Recurse -or $Depth -ge 1) {
      if ($Depth -lt 0 -or (++$__ThisDepth) -le $Depth) {
        # Note: This top-down recursion is inefficient, because any given directory's
        #       subtree is processed in full.
        Get-ChildItem -Force -Directory -LiteralPath $fullName |
          ForEach-Object { Get-DirectorySize -LiteralPath $_.FullName -Recurse -Depth $Depth -__ThisDepth $__ThisDepth }
      }
    }
  }
}
