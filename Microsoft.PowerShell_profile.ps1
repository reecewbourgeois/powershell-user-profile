# ************************* #
# ** Prerequisite Checks ** #
# ************************* #

# If not powershell 7, then exit
if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Host "ERROR: PowerShell 7 or higher is required to run this script." -ForegroundColor Red
  Pause
  Exit
}

#region Update Profile (uncomment to enable)
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
# Update-Profile
#endregion Update Profile


$userFolder = "C:\Users\$env:username"
$downloadsFolder = "$userFolder\Downloads"
$appDataLocal = "$userFolder\AppData\Local"

#region Caskaydia Cove Nerd Font
# See if Caskaydia Cove Nerd Font is installed
if (-not(Test-Path "$appDataLocal\Microsoft\Windows\Fonts\CaskaydiaCoveNerdFont-Regular.ttf")) {
  $caskaydiaCoveNerdFontLink = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CascadiaCode.zip"
  # Download the font
  Invoke-WebRequest -Uri $caskaydiaCoveNerdFontLink -OutFile "$downloadsFolder\CaskaydiaCoveNerdFont.zip"

  # Unzip the font
  Expand-Archive -Path "$downloadsFolder\CaskaydiaCoveNerdFont.zip" -DestinationPath "$downloadsFolder\CaskaydiaCoveNerdFont"

  # Install the font
  Write-Host "Install the font and then press any key to continue..." -ForegroundColor Yellow
  Start-Process "$downloadsFolder\CaskaydiaCoveNerdFont\CaskaydiaCoveNerdFont-Regular.ttf"
  Pause

  # Clean up
  Remove-Item -Path "$downloadsFolder\CaskaydiaCoveNerdFont.zip"
  Remove-Item -Path "$downloadsFolder\CaskaydiaCoveNerdFont" -Recurse
}
#endregion Caskaydia Cove Nerd Font

$Global:__LastHistoryId = -1

# Reference: https://learn.microsoft.com/en-us/windows/terminal/tutorials/shell-integration
function Global:__Terminal-Get-LastExitCode {
  if ($? -eq $True) {
    return 0
  }
  $LastHistoryEntry = $(Get-History -Count 1)
  $IsPowerShellError = $Error[0].InvocationInfo.HistoryId -eq $LastHistoryEntry.Id
  if ($IsPowerShellError) {
    return -1
  }
  return $LastExitCode
}

function prompt {
  $out = ""

  # First, emit a mark for the _end_ of the previous command.
  $gle = $(__Terminal-Get-LastExitCode);
  $LastHistoryEntry = $(Get-History -Count 1)
  
  # Skip finishing the command if the first command has not yet started
  if ($Global:__LastHistoryId -ne -1) {
    if ($LastHistoryEntry.Id -eq $Global:__LastHistoryId) {
      # No history entry (e.g., Ctrl+C or Enter on empty command)
      $out += "`e]133;D`a"
    }
    else {
      $out += "`e]133;D;$gle`a"
    }
  }

  # Get current directory
  $loc = $($executionContext.SessionState.Path.CurrentLocation)

  # Emit mark for prompt start
  $out += "`e]133;A$([char]07)"

  # Emit CWD information
  $out += "`e]9;9;`"$loc`"$([char]07)"

  # Helper function to get Git branch info
  function Get-GitBranch {
    $branch = $null
    try {
      $branch = & git rev-parse --abbrev-ref HEAD 2>$null
    }
    catch {}
    return $branch
  }

  # Colors (ANSI Escape Codes)
  $colorGreen = "`e[92m"   # Light Green
  $colorBlue = "`e[38;2;61;172;196m"   # Light Cyan/Blue
  $colorPurple = "`e[38;2;167;55;219m"  # Purple
  $colorGray = "`e[38;5;235m"   # Dark Gray
  
  # Background Colors
  $bgDarkGray = "`e[48;5;235m" # Dark gray background
  
  # Resets
  $colorReset = "`e[0m"    # Reset color
  $bgReset = "`e[49m"       # Reset background
  $fullColorReset = "$colorReset$bgReset"  # Reset both color and background

  # Powerline Separators (for rounded edges)
  $leftRounded = "$fullColorReset$colorGray$fullColorReset"  # Left separator with dark gray background
  $rightRounded = "$fullColorReset$colorGray$fullColorReset"   # Right separator in gray, no background

  $cwd = $PWD.Path
  $homePath = [System.Environment]::GetFolderPath("UserProfile")

  # Replace home directory with ~
  if ($cwd -like "$homePath*") {
    $cwd = $cwd -replace [regex]::Escape($homePath), "~"
  }

  # Get current time
  $time = Get-Date -Format "HH:mm:ss"

  # Get Git branch info
  $gitBranch = Get-GitBranch
  $gitSegment = if ($gitBranch) { "$leftRounded$bgDarkGray$colorPurple $gitBranch$rightRounded" } else { "" }

  # Constructing the prompt
  $promptText = @"
$colorGreen┌ [$time] $leftRounded$bgDarkGray$colorBlue $cwd$rightRounded $gitSegment
$colorGreen└ ❯$fullColorReset
"@

  # Append the prompt text to the output
  $out += $promptText

  # Emit mark for prompt end (Command started)
  $out += "`e]133;B$([char]07)"

  $Global:__LastHistoryId = $LastHistoryEntry.Id

  # Display the final output
  Write-Host $out -NoNewline
  return " "
}


#region Custom Commands
# ********************* #
# ** Custom Commands ** #
# ********************* #

# Credit: https://github.com/ChrisTitusTech/powershell-profile/blob/main/Microsoft.PowerShell_profile.ps1

function touch($file) { "" | Out-File $file -Encoding ASCII }

# Find File
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
function Get-DirectorySize {
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

    if ($ExcludeSelf) {
      # Exclude the input dir. itself; implies -Recurse
      $Recurse = $True
      $ExcludeSelf = $False
    }
    else {
      # Process this dir.
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
        { $_ -ge 1tb } { $_ / 1tb; $suffix = 'tb'; break }
        { $_ -ge 1gb } { $_ / 1gb; $suffix = 'gb'; break }
        { $_ -ge 1mb } { $_ / 1mb; $suffix = 'mb'; break }
        { $_ -ge 1kb } { $_ / 1kb; $suffix = 'kb'; break }
        default { $_; $suffix = 'b'; $decimalPlaces = 0; break }
      }
  
      # Construct and output an object representing the dir. at hand.
      [pscustomobject] @{
        FullName     = $fullName
        FriendlySize = ("{0:N${decimalPlaces}}${suffix}" -f $scaledSize).PadLeft($padWidth, ' ')
        Size         = $size
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
#endregion Custom Commands