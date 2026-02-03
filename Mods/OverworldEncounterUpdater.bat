@echo off
setlocal enabledelayedexpansion

:: Change to game root directory (script is in Mods folder)
cd /d "%~dp0\.."
if not exist "Mods\OverWorldEncounters" (
    echo ERROR: Could not find game root directory.
    echo Please run this script from the game folder.
    pause
    exit /b 1
)

echo ========================================
echo  VOE - Kuray's Overworld Encounters
echo  Updater Script
echo ========================================
echo.

:: Configuration
set "REPO=jov4n/KurayOverworldEncounters"
set "BRANCH=main"
set "VERSION_URL=https://raw.githubusercontent.com/%REPO%/refs/heads/%BRANCH%/version.txt"
set "FILES_URL=https://raw.githubusercontent.com/%REPO%/refs/heads/%BRANCH%/files.txt"
set "RAW_BASE=https://raw.githubusercontent.com/%REPO%/refs/heads/%BRANCH%"

:: Get current version from local file
set "LOCAL_VERSION=Unknown"
if exist "Mods\OverWorldEncounters\005_VOE_VersionManager.rb" (
    for /f "tokens=2 delims==" %%a in ('findstr /i /c:"VERSION = " "Mods\OverWorldEncounters\005_VOE_VersionManager.rb" ^| findstr /v /c:"VERSION_DATE"') do (
        set "LOCAL_VERSION=%%a"
        set "LOCAL_VERSION=!LOCAL_VERSION:"=!"
        set "LOCAL_VERSION=!LOCAL_VERSION: =!"
        goto :version_found
    )
)
:version_found
echo Current version: %LOCAL_VERSION%
echo.

:: Check for curl
where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: curl is required but not found.
    echo Please install curl or use Windows 10/11 which includes it.
    pause
    exit /b 1
)

:: Fetch remote version
echo Checking for updates...
curl -s -o "%TEMP%\voe_version.txt" "%VERSION_URL%" 2>nul

if not exist "%TEMP%\voe_version.txt" (
    echo ERROR: Could not fetch version info from GitHub.
    echo Check your internet connection.
    pause
    exit /b 1
)

:: Parse remote version
set "REMOTE_VERSION=Unknown"
for /f "tokens=2 delims==" %%a in ('findstr /i "version" "%TEMP%\voe_version.txt"') do (
    set "REMOTE_VERSION=%%a"
    set "REMOTE_VERSION=!REMOTE_VERSION:"=!"
    set "REMOTE_VERSION=!REMOTE_VERSION: =!"
)

echo Remote version: %REMOTE_VERSION%
echo.

:: Compare versions (simple string compare)
if "%LOCAL_VERSION%"=="%REMOTE_VERSION%" (
    echo You are already up to date!
    del "%TEMP%\voe_version.txt" 2>nul
    pause
    exit /b 0
)

echo Update available: %LOCAL_VERSION% -^> %REMOTE_VERSION%
echo.
set /p CONFIRM="Download and install update? (y/n): "
if /i not "%CONFIRM%"=="y" (
    echo Update cancelled.
    del "%TEMP%\voe_version.txt" 2>nul
    pause
    exit /b 0
)

echo.
echo ========================================
echo  Downloading update...
echo ========================================

:: Try to fetch file list, fall back to default
curl -s -o "%TEMP%\voe_files.txt" "%FILES_URL%" 2>nul

if not exist "%TEMP%\voe_files.txt" (
    echo Using default file list...
    (
        echo Mods/02_OverworldEncounters.rb
        echo Mods/OverWorldEncounters/000_VOE_Utils.rb
        echo Mods/OverWorldEncounters/001_VOE_Config.rb
        echo Mods/OverWorldEncounters/002_VOE_Pokemon Behavior.rb
        echo Mods/OverWorldEncounters/003_VOE_Event Handlers.rb
        echo Mods/OverWorldEncounters/004_VOE_Movement.rb
        echo Mods/OverWorldEncounters/005_VOE_VersionManager.rb
    ) > "%TEMP%\voe_files.txt"
)

:: Create backup folder
set "BACKUP_DIR=Mods\OverWorldEncounters\backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "BACKUP_DIR=%BACKUP_DIR: =0%"
mkdir "%BACKUP_DIR%" 2>nul

:: Download each file
set "SUCCESS=1"
for /f "usebackq tokens=*" %%f in ("%TEMP%\voe_files.txt") do (
    set "FILE=%%f"
    :: Skip comments and empty lines
    if not "!FILE!"=="" if not "!FILE:~0,1!"=="#" (
        :: Convert forward slashes to backslashes for local path
        set "LOCAL_PATH=!FILE:/=\!"
        
        :: URL-encode the filename for GitHub raw URL (spaces -> %20)
        set "URL_FILE=!FILE!"
        set "URL_FILE=!URL_FILE: =%%20!"
        set "DOWNLOAD_URL=%RAW_BASE%/!URL_FILE!"
        
        echo Downloading: !FILE!
        
        :: Backup existing file
        if exist "!LOCAL_PATH!" (
            copy "!LOCAL_PATH!" "%BACKUP_DIR%\" >nul 2>&1
        )
        
        :: Ensure directory exists
        for %%i in ("!LOCAL_PATH!") do (
            if not exist "%%~dpi" mkdir "%%~dpi" 2>nul
        )
        
        :: Download file
        curl -s -o "!LOCAL_PATH!" "!DOWNLOAD_URL!" 2>nul
        
        if not exist "!LOCAL_PATH!" (
            echo   FAILED: !FILE!
            set "SUCCESS=0"
        ) else (
            echo   OK: !FILE!
        )
    )
)

:: Cleanup
del "%TEMP%\voe_version.txt" 2>nul
del "%TEMP%\voe_files.txt" 2>nul

echo.
if "%SUCCESS%"=="1" (
    echo ========================================
    echo  UPDATE COMPLETE!
    echo ========================================
    echo.
    echo Updated from %LOCAL_VERSION% to %REMOTE_VERSION%
    echo Backup saved to: %BACKUP_DIR%
    echo.
    echo Please restart the game to use the new version.
) else (
    echo ========================================
    echo  UPDATE FAILED
    echo ========================================
    echo.
    echo Some files could not be downloaded.
    echo Your backup is in: %BACKUP_DIR%
    echo.
    echo To restore, copy files from the backup folder.
)

echo.
pause
