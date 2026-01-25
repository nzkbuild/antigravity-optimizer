@echo off
setlocal
if "%~1"=="" (
  echo Usage: activate-skills ^<task text^>
  exit /b 1
)
set SCRIPT_DIR=%~dp0
python "%SCRIPT_DIR%tools\skill_router.py" %*
