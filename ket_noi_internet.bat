@echo off
title SoulMate - Ket noi Internet (Cloudflare Tunnel)
cd /d "%~dp0"

echo ==========================================================
echo   SoulMate - VAO DUOC TU BAT KY DAU (khong can cung WiFi)
echo ==========================================================
echo.

where node >nul 2>&1
if errorlevel 1 (
  echo [LOI] Chua cai Node.js - chay cai_dat.bat truoc.
  goto :end
)

:: Tai cloudflared neu chua co
if not exist "server\cloudflared.exe" (
  echo Dang tai cloudflared lan dau, khoang 53MB...
  curl -sL -o "server\cloudflared.exe" https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
)
if not exist "server\cloudflared.exe" (
  echo [LOI] Tai cloudflared that bai - kiem tra ket noi Internet.
  goto :end
)

:: Khoi dong server neu chua chay
curl -sk https://localhost:3000/health >nul 2>&1
if errorlevel 1 (
  echo Khoi dong SoulMate Server...
  start "SoulMate Server" cmd /k cd /d "%~dp0server" ^&^& node src/index.js
  ping -n 5 127.0.0.1 >nul
) else (
  echo Server da chay san.
)

:: Khoi dong tunnel (chay ngam, ghi log vao tunnel.log)
del /q "tunnel.log" 2>nul
echo Dang mo tunnel Cloudflare...
start "SoulMate Tunnel - khong dong cua so nay" /min "%~dp0server\tunnel.bat"

:: Doi tunnel len URL (thu toi 5 lan x 3 giay)
set "URL="
for /l %%n in (1,1,5) do (
  if not defined URL (
    for /f "tokens=4" %%u in ('findstr /r /c:"https://[a-z0-9-]*\.trycloudflare\.com" tunnel.log 2^>nul') do set "URL=%%u"
    if not defined URL ping -n 4 127.0.0.1 >nul
  )
)

if not defined URL (
  echo.
  echo [LOI] Khong lay duoc URL tunnel. Noi dung log:
  echo -----------------------------------------------
  type "tunnel.log" 2>nul
  echo -----------------------------------------------
  goto :end
)

echo %URL% | clip
echo.
echo ==========================================================
echo   URL CONG PUBLIC (da copy vao clipboard):
echo.
echo     %URL%
echo ==========================================================
echo.
echo   CACH DUNG TREN DIEN THOAI:
echo    1. Mo app - Ca nhan - the Mang - vao man Demo
echo    2. Dan URL vao o "May chu" - bam Luu
echo    3. Bam "Ping server" - thay "may chu online" = OK
echo.
echo   LUU Y:
echo    - URL thay moi lan mo lai tunnel - nhap lai khi bi loi ket noi
echo    - GIU ca 3 cua so (Server, Tunnel, cua so nay) dang mo
echo    - Muon dung: dong 2 cua so Server + Tunnel
echo.
:end
echo Nhan phim bat ky de dong...
pause >nul
