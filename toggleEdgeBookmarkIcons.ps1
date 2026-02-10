# This script toggles Edge browser bookmarks bar between icons and icons+labels
# Script toggles bookmark's name field to "" to hide or show label
# On: Show icons only | Off: Show icons and labels
# ATTENTION: Closes Edge temporarily, and reopens it during toggle. 
# Backup of bookmarks/icons kept

param(
    [ValidateSet("On", "Off", "Toggle")]
    [string]$Mode = "Toggle"
)

$bookmarksPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks"
$backupDir = "$env:LOCALAPPDATA\EdgeBookmarksBackup"
$stateFile = "$backupDir\current_state.txt"

# Create backup directory
if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force | Out-Null }

# Check if bookmarks file exists
if (-not (Test-Path $bookmarksPath)) {
    Write-Host "❌ Edge bookmarks file not found. Is Edge set up?" -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit 1
}

# Backup original if missing
if (-not (Test-Path "$backupDir\original_backup.json")) {
    Copy-Item $bookmarksPath "$backupDir\original_backup.json" -Force
    Write-Host "✅ Created permanent backup at $backupDir\original_backup.json" -ForegroundColor Green
}

# Determine current state
$currentMode = if (Test-Path $stateFile) { Get-Content $stateFile -TotalCount 1 } else { "Off" }

# Decide target mode
if ($Mode -eq "Toggle") {
    $targetMode = if ($currentMode -eq "On") { "Off" } else { "On" }
} else {
    $targetMode = $Mode
}

if ($currentMode -eq $targetMode) {
    $msg = if ($targetMode -eq "On") { "already ICONS-ONLY" } else { "already SHOWING LABELS" }
    Write-Host "ℹ️  Bookmarks bar is $msg. No changes needed." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    exit 0
}

# --- SAFELY CLOSE EDGE ---
Write-Host "`n⚠️  PREPARING TO CLOSE MICROSOFT EDGE..." -ForegroundColor Yellow
Write-Host "   (Unsaved form data may be lost. Save your work first!)" -ForegroundColor DarkYellow
Write-Host "`nClosing in: " -NoNewline -ForegroundColor Cyan

# 5-second countdown with abort option
for ($i = 5; $i -gt 0; $i--) {
    Write-Host "$i " -NoNewline -ForegroundColor Magenta
    Start-Sleep -Seconds 1
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'C') {
            Write-Host "`n`n🛑 Operation cancelled by user. Exiting." -ForegroundColor Red
            exit 1
        }
    }
}
Write-Host "`n"

# Force-close Edge processes
$edgeProcs = Get-Process msedge -ErrorAction SilentlyContinue
if ($edgeProcs) {
    Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2  # Allow processes to terminate
    
    # Verify closure
    if (Get-Process msedge -ErrorAction SilentlyContinue) {
        Write-Host "❌ Could not fully close Edge. Please close manually and rerun." -ForegroundColor Red
        Start-Sleep -Seconds 3
        exit 1
    }
    Write-Host "✅ Edge closed successfully." -ForegroundColor Green
} else {
    Write-Host "ℹ️  Edge was not running." -ForegroundColor Cyan
}

# --- TOGGLE BOOKMARKS ---
try {
    $bookmarks = Get-Content $bookmarksPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "❌ Failed to read bookmarks. File may be locked." -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit 1
}

# Backup current state
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item $bookmarksPath "$backupDir\backup_$timestamp.json" -Force

if ($targetMode -eq "On") {
    # Icons Only: Blank names
    $originalNames = @()
    foreach ($child in $bookmarks.roots.bookmark_bar.children) {
        if ($child.name -and $child.type -eq "url") {
            $originalNames += [PSCustomObject]@{ id = $child.id; name = $child.name }
            $child.name = ""
        }
    }
    $originalNames | ConvertTo-Json | Set-Content "$backupDir\name_mapping.json" -Force
    $actionText = "ICONS ONLY (labels hidden)"
} else {
    # Restore labels
    if (Test-Path "$backupDir\name_mapping.json") {
        $mapping = Get-Content "$backupDir\name_mapping.json" | ConvertFrom-Json
        $nameMap = @{}
        foreach ($item in $mapping) { $nameMap[$item.id] = $item.name }
        
        foreach ($child in $bookmarks.roots.bookmark_bar.children) {
            if ($child.id -and $nameMap.ContainsKey($child.id)) {
                $child.name = $nameMap[$child.id]
            }
        }
    } else {
        # Fallback to original backup
        $bookmarks = Get-Content "$backupDir\original_backup.json" -Raw | ConvertFrom-Json
    }
    $actionText = "ICONS + LABELS"
}

# Save changes
try {
    $bookmarks | ConvertTo-Json -Depth 100 | Set-Content $bookmarksPath -Force
    Set-Content $stateFile $targetMode -Force
} catch {
    Write-Host "❌ Failed to write bookmarks file." -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit 1
}

# --- REOPEN EDGE (optional but user-friendly) ---
Start-Process msedge.exe -ArgumentList "--new-window" -ErrorAction SilentlyContinue

# Final feedback
Write-Host "`n✅ SUCCESS! Bookmarks bar now shows: $actionText" -ForegroundColor Green
Write-Host "`nℹ️  Edge has been reopened automatically." -ForegroundColor Cyan
Start-Sleep -Seconds 3