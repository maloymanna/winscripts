# This script toggles Edge browser bookmarks bar between icons and icons+labels
# Script toggles bookmark's name field to "" to hide or show label
# Requires closing Edge temporarily during toggle. 
# Backup of bookmarks/icons kept

param(
    [ValidateSet("On", "Off", "Toggle")]
    [string]$Mode = "Toggle"
)

# JSON path where Edge stores bookmarks
$bookmarksPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks"
$backupDir = "$env:LOCALAPPDATA\EdgeBookmarksBackup"
$stateFile = "$backupDir\current_state.txt"

# Create backup directory if missing
if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force | Out-Null }

# Check if Edge is running
if (Get-Process msedge -ErrorAction SilentlyContinue) {
    Write-Host "⚠️  Microsoft Edge is running. Please close all Edge windows first." -ForegroundColor Yellow
    Write-Host "   Press Enter after closing Edge to continue..." -ForegroundColor Yellow
    Pause
    if (Get-Process msedge -ErrorAction SilentlyContinue) {
        Write-Host "❌ Edge still running. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Backup original bookmarks (if no backup exists)
if (-not (Test-Path "$backupDir\original_backup.json")) {
    if (Test-Path $bookmarksPath) {
        Copy-Item $bookmarksPath "$backupDir\original_backup.json" -Force
        Write-Host "✅ Created original backup at $backupDir\original_backup.json" -ForegroundColor Green
    } else {
        Write-Host "❌ Bookmarks file not found. Is Edge set up?" -ForegroundColor Red
        exit 1
    }
}

# Determine current state
$currentMode = "Off"  # Default = labels visible
if (Test-Path $stateFile) {
    $currentMode = Get-Content $stateFile -TotalCount 1
}

# Decide target mode
if ($Mode -eq "Toggle") {
    $targetMode = if ($currentMode -eq "On") { "Off" } else { "On" }
} else {
    $targetMode = $Mode
}

if ($currentMode -eq $targetMode) {
    Write-Host "ℹ️  Already in '$targetMode' mode (labels hidden = On). No changes needed." -ForegroundColor Cyan
    exit 0
}

# Load bookmarks JSON
try {
    $bookmarks = Get-Content $bookmarksPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "❌ Failed to read bookmarks file. Ensure Edge is closed." -ForegroundColor Red
    exit 1
}

# Backup current state before modifying
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item $bookmarksPath "$backupDir\backup_$timestamp.json" -Force

if ($targetMode -eq "On") {
    # Icons Only Mode: Save original names, then blank them
    $originalNames = @()
    foreach ($child in $bookmarks.roots.bookmark_bar.children) {
        if ($child.name -and $child.type -eq "url") {
            $originalNames += [PSCustomObject]@{ id = $child.id; name = $child.name }
            $child.name = ""
        }
    }
    # Save mapping for restore later
    $originalNames | ConvertTo-Json | Set-Content "$backupDir\name_mapping.json" -Force
    Write-Host "🎨 Switching to ICONS ONLY mode (labels hidden)..." -ForegroundColor Magenta
} else {
    # Labels On Mode: Restore names from mapping
    if (Test-Path "$backupDir\name_mapping.json") {
        $mapping = Get-Content "$backupDir\name_mapping.json" | ConvertFrom-Json
        $nameMap = @{}
        foreach ($item in $mapping) { $nameMap[$item.id] = $item.name }
        
        foreach ($child in $bookmarks.roots.bookmark_bar.children) {
            if ($child.id -and $nameMap.ContainsKey($child.id)) {
                $child.name = $nameMap[$child.id]
            }
        }
        Write-Host "🔤 Switching to ICONS + LABELS mode..." -ForegroundColor Magenta
    } else {
        # Fallback: Restore from original backup
        Write-Host "⚠️  No name mapping found. Restoring from original backup..." -ForegroundColor Yellow
        $bookmarks = Get-Content "$backupDir\original_backup.json" -Raw | ConvertFrom-Json
    }
}

# Save modified bookmarks
try {
    $bookmarks | ConvertTo-Json -Depth 100 | Set-Content $bookmarksPath -Force
    Set-Content $stateFile $targetMode -Force
    Write-Host "✅ Successfully switched to '$targetMode' mode!" -ForegroundColor Green
    Write-Host "   → Reopen Microsoft Edge to see changes." -ForegroundColor Cyan
    
    if ($targetMode -eq "On") {
        Write-Host "`n💡 Tip: To show labels again, run this script with '-Mode Off' or double-click to toggle." -ForegroundColor DarkGray
    }
} catch {
    Write-Host "❌ Failed to write bookmarks file. Permissions issue?" -ForegroundColor Red
    exit 1
}