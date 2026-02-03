@echo off
REM Windows CMD wrapper for activate-skills
REM Calls the PowerShell script with all arguments

REM Check if PowerShell is available
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: PowerShell is required but not found in PATH.
    echo Please ensure PowerShell is installed and accessible.
    exit /b 1
)

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0activate-skills.ps1" %*
