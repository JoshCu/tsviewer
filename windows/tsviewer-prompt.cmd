@echo off
rem Opens a command prompt with tsviewer on the PATH, ready to use.
setlocal
set "PATH=%~dp0;%PATH%"
if exist "%~dp0examples" cd /d "%~dp0examples"
echo tsviewer is on the PATH for this window.
echo.
echo Try one of:
echo     tsviewer model1_temperatures.csv
echo     tsviewer model1_temperatures.csv model2_temperatures.csv
echo     tsviewer --help
echo.
cmd /k
