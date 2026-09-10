@echo off
setlocal

REM speedtest-cdn - Windows one-click runner
REM Usage:
REM   run.bat                  full pipeline
REM   run.bat --quick          quick mode
REM   run.bat --check-only     check only (no modify)
REM   run.bat --nodes cdn-360  verify specific nodes

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM Find Node.js (prefer bundled node-runtime)
set "NODE_BIN="
if exist "%SCRIPT_DIR%node-runtime\node.exe" (
    set "NODE_BIN=%SCRIPT_DIR%node-runtime\node.exe"
    goto check_version
)

where node >nul 2>nul
if errorlevel 1 goto no_node
set "NODE_BIN=node"

:check_version
"%NODE_BIN%" -p "process.exit(process.versions.node.split('.')[0] < 18 ? 1 : 0)" >nul 2>nul
if errorlevel 1 goto old_node

for /f "delims=" %%v in ('"%NODE_BIN%" -v') do set "NODE_VER=%%v"
echo [OK] Node.js %NODE_VER%
echo.

"%NODE_BIN%" scripts\pipeline.mjs %*
set "EXIT_CODE=%errorlevel%"

if "%~1"=="" pause
exit /b %EXIT_CODE%

:no_node
echo [ERROR] Node.js not found ^(18+ required^)
echo.
echo Install Node.js first, choose one:
echo   1. Run install.bat in this folder
echo   2. winget:  winget install OpenJS.NodeJS.LTS
echo   3. Download: https://nodejs.org/
echo.
if "%~1"=="" pause
exit /b 1

:old_node
echo [ERROR] Node.js version too old ^(18+ required^)
echo         Run install.bat or upgrade manually.
echo.
if "%~1"=="" pause
exit /b 1
