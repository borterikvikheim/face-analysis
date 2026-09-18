@echo off
setlocal
cd /d "%~dp0"
set "R_LIBS_USER=%~dp0library"
set "R_LIBS_SITE=%~dp0library"
set "ABIS_RSCRIPT=%~dp0runtime\bin\Rscript.exe"
if not exist "%ABIS_RSCRIPT%" set "ABIS_RSCRIPT=%~dp0runtime\bin\x64\Rscript.exe"
if not exist "%ABIS_RSCRIPT%" (
  echo Bundled R is missing. Extract the entire ZIP before starting.
  pause
  exit /b 1
)
"%ABIS_RSCRIPT%" --vanilla "%~dp0launch.R"
if errorlevel 1 (
  echo ABIS stopped. See the error above.
  pause
)
endlocal
