@echo off
REM Windows CMD wrapper for activate-skills
REM Calls the PowerShell script with all arguments

powershell -ExecutionPolicy Bypass -File "%~dp0activate-skills.ps1" %*
