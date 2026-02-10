@echo off
chcp 65001 >nul
title Toggle Edge Bookmarks

:: Get script path relative to batch file
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%toggleEdgeBookmarks.ps1"

:: Fallback: Try common locations if script not found next to batch
if not exist "%PS_SCRIPT%" (
    set "PS_SCRIPT=%LOCALAPPDATA%\EdgeBookmarksBackup\toggleEdgeBookmarks.ps1"
)
if not exist "%PS_SCRIPT%" (
    echo ERROR: PowerShell script not found!
    echo Please place 'toggleEdgeBookmarks.ps1' in the same folder as this batch file.
    pause
    exit /b 1
)

:: Run PowerShell with execution policy bypass
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Mode Toggle

:: Keep window open briefly for feedback
timeout /t 2 /nobreak >nul