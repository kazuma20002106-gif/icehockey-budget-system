@echo off
title Ice Hockey Budget System
echo =========================================
echo Starting Ice Hockey Budget System...
echo Please wait.
echo.
echo [NOTICE]
echo Please DO NOT close this black window while using the app!
echo Close this window with the 'X' button only when you are done.
echo =========================================
echo.

set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot
cd /d "%~dp0"
call mvnw.cmd spring-boot:run

pause
