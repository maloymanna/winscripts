@echo off
setlocal

REM === Windows Theme ===
echo "Checking current Windows theme..."

REM Detect LIGHT(0x1)
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme | find "0x1" >nul
if %errorlevel%==0 (
	echo "Windows: LIGHT -> DARK"
	reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f >nul
	reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f >nul
	goto done
) 

reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme | find "0x0" >nul

if %errorlevel%==0 (
	echo "Windows: DARK -> LIGHT"
	reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 1 /f >nul
	reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 1 /f >nul
	goto done
)
echo "Windows theme: UNKNOWN (no change)"

:done
REM Restart explorer to repaint
taskkill /IM explorer.exe /F >nul
start explorer.exe

echo "Done."

REM Call the PowerShell script to update the icon
REM powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0toggleThemeIcon.ps1"

REM Check if Notepad++ is running
tasklist /FI "IMAGENAME eq notepad++.exe" /NH | find /I "notepad++.exe" >nul
set "notepadRunning=%ERRORLEVEL%"

REM If it was running, restart it after theme change
if "%notepadRunning%"=="0" (
    echo Notepad++ is running. Restarting it after theme change.
    taskkill /IM notepad++.exe /F
    timeout /t 2 /nobreak >nul
    start "" "C:\Program Files\Notepad++\notepad++.exe"
) else (
    echo Notepad++ is not running. No restart needed.
)

endlocal 
