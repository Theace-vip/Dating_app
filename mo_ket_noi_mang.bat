@echo off
chcp 65001 >nul
title SoulMate - Mo ket noi mang (Firewall)

:: Tu elevate: chay lai bang quyen Admin neu chua co
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Dang yeu cau quyen Admin...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo ==================================================
echo   SoulMate - Mo ket noi mang cho may chu
echo ==================================================
echo.

:: Hien IP LAN cua may tinh
echo IP cua may tinh (dung cai nay tren app):
ipconfig | findstr /i /c:"IPv4" /c:"IPv4 Address"
echo.

:: Them rule firewall cho port 3000 (idempotent)
netsh advfirewall firewall delete rule name="SoulMate Server 3000" >nul 2>&1
netsh advfirewall firewall add rule name="SoulMate Server 3000" dir=in action=allow protocol=TCP localport=3000
if %errorlevel% equ 0 (
  echo.
  echo [OK] Da mo cong 3000 tren Firewall Windows.
) else (
  echo.
  echo [LOI] Khong them duoc rule - chay lai bang quyen Admin.
)
echo.

:: Kiem tra server dang chay khong
curl -sk https://localhost:3000/health >nul 2>&1
if %errorlevel% equ 0 (
  echo [OK] Server dang chay - dien thoai cung WiFi vao duoc
         https://<IP o tren>:3000
) else (
  echo [CANH BAO] Server chua chay - chay cai_dat.bat truoc.
)

echo.
echo Nhan phim bat ky de dong...
pause >nul
