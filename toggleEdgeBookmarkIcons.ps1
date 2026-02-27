param(
    [ValidateSet("On", "Off", "Toggle")]
    [string]$Mode = "Toggle"
)

$bookmarksPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks"
$backupDir = "$env:LOCALAPPDATA\EdgeBookmarksBackup"
$stateFile = "$backupDir\current_state.txt"

# Ensure backup directory exists
if (!(Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

# 1. Make a backup of the current Bookmarks file with timestamp
$timestamp = Get-Date -Format "yyyy.MM.dd.HH.mm.ss"
$backupFileName = "Bookmarks_Backup_$timestamp"
Copy-Item -Path $bookmarksPath -Destination "$backupDir\$backupFileName" -Force

# Prompt user to confirm closing Edge
Write-Host "`nTo toggle the bookmark icon state, Microsoft Edge needs to be closed." -ForegroundColor Yellow
Write-Host "Any unsaved work or forms in Edge will be lost." -ForegroundColor Yellow
$confirmation = Read-Host "Do you want to proceed and close Edge now? (y/N - default N)"

if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "`nOperation cancelled by user. Edge will not be closed and no changes will be made." -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit 0
}

# 2. Close Edge
Get-Process -Name "msedge" -ErrorAction SilentlyContinue | Stop-Process -Force

# Determine current state from the JSON file content itself
if (Test-Path $bookmarksPath) {
    try {
        $content = Get-Content -Path $bookmarksPath -Raw -Encoding UTF8
        # Check for any occurrence of "show_icon": false
        if ($content -match '"show_icon"\s*:\s*false') {
            $currentMode = "Off"
        } else {
            # If no "show_icon": false is found, assume it's On (or the file is malformed for this script)
            # A more robust check would be if it contains "show_icon": true, but the initial state might not be standardized.
            # Checking for the presence of "show_icon" at all could also work.
            if ($content -match '"show_icon"\s*:\s*true') {
                $currentMode = "On"
            } else {
                # If neither is found, we cannot determine the state, default to Off?
                # This scenario might occur if the file is empty or corrupted.
                Write-Host "Warning: Could not determine 'show_icon' state from bookmarks file. Assuming Off."
                $currentMode = "Off"
            }
        }
    } catch {
        Write-Host "Error reading bookmarks file to determine state: $_"
        exit 1
    }
} else {
    Write-Host "Bookmarks file does not exist at path: $bookmarksPath"
    exit 1
}


# Decide target mode based on input and current state
if ($Mode -eq "Toggle") {
    $targetMode = if ($currentMode -eq "On") { "Off" } else { "On" }
} else {
    $targetMode = $Mode
}

# Check if action is needed
if ($currentMode -eq $targetMode) {
    $msg = if ($targetMode -eq "On") { "already ICONS-ONLY (show_icon: false)" } else { "already SHOWING LABELS (show_icon: true)" }
    Write-Host "INFO: Bookmarks bar is $msg. No changes needed."
    Start-Sleep -Seconds 2
    # Reopen Edge even if no change was made
    Start-Process msedge.exe -ArgumentList "--new-window" -ErrorAction SilentlyContinue
    exit 0
}

# Read the current bookmarks file content
try {
    $bookmarksContent = Get-Content -Path $bookmarksPath -Raw -Encoding UTF8
} catch {
    Write-Host "ERROR: Failed to read bookmarks. File may be locked. $_"
    Start-Sleep -Seconds 3
    # Reopen Edge before exiting
    Start-Process msedge.exe -ArgumentList "--new-window" -ErrorAction SilentlyContinue
    exit 1
}

# 3. If current state is Off -> set to On (show_icon: true becomes show_icon: false)
if ($targetMode -eq "On") {
    # Replace "show_icon": true with "show_icon": false
    $updatedContent = $bookmarksContent -replace '(?<="show_icon"\s*:\s*)true', 'false'
    $actionText = "ICONS-ONLY (show_icon: false)"
}
# 4. If current state is On -> set to Off (show_icon: false becomes show_icon: true)
else {
    # Replace "show_icon": false with "show_icon": true
    $updatedContent = $bookmarksContent -replace '(?<="show_icon"\s*:\s*)false', 'true'
    $actionText = "SHOWING LABELS (show_icon: true)"
}

# Write the updated content back to the file
try {
    Set-Content -Path $bookmarksPath -Value $updatedContent -Encoding UTF8 -Force
    Set-Content -Path $stateFile -Value $targetMode -Encoding UTF8 -Force
} catch {
    Write-Host "ERROR: Failed to write bookmarks file. $_"
    Start-Sleep -Seconds 3
    # Reopen Edge before exiting
    Start-Process msedge.exe -ArgumentList "--new-window" -ErrorAction SilentlyContinue
    exit 1
}

# 5. Restart Edge
Start-Process msedge.exe -ArgumentList "--new-window" -ErrorAction SilentlyContinue

# 6. Success message
Write-Host ""
Write-Host "SUCCESS! Bookmarks bar now set to: $actionText"
Write-Host "INFO: Edge has been restarted."
Start-Sleep -Seconds 3