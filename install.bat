@echo off
REM speedtest-cdn - Windows environment installer (delegates to install.ps1)
REM Usage:
REM   install.bat            auto install
REM   install.bat --force    force re-download portable Node

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
