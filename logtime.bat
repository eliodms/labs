@echo off
echo Logging time every second. Press Ctrl+C to stop.
:loop
time /t
choice /n /t:y,1 >nul
goto loop
