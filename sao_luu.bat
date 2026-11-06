:: sao_luu.bat - Sao luu database SoulMate ra backend/backups/ kem ngay gio,
:: dung VACUUM INTO nen an toan ca khi server dang chay.
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
call node backend\scripts\backup_db.js
if errorlevel 1 (
  echo [LOI] Sao luu that bai.
  goto :fail
)
echo.
echo Ban sao luu nam trong: backend\backups\
echo (tu dong giu 14 ban gan nhat, xoa ban cu)
echo.
if /i "%~1"=="--nopause" exit /b 0
pause
exit /b 0

:fail
if /i "%~1"=="--nopause" exit /b 1
pause
exit /b 1
