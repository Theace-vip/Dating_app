@echo off
setlocal EnableExtensions
cd /d "%~dp0"
echo ==========================================
echo   SAO LUU DATABASE SOULMATE
echo ==========================================
where node >nul 2>nul
if errorlevel 1 (
  echo [LOI] Khong tim thay Node.js.
  goto :fail
)
call node server\scripts\backup_db.js
if errorlevel 1 (
  echo [LOI] Sao luu that bai.
  goto :fail
)
echo.
echo Ban sao luu nam trong: server\backups\
echo (tu dong giu 14 ban gan nhat, xoa ban cu)
echo.
if /i "%~1"=="--nopause" exit /b 0
pause
exit /b 0

:fail
if /i "%~1"=="--nopause" exit /b 1
pause
exit /b 1
