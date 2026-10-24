@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ==========================================================
echo    SOULMATE - CAI DAT MOT LAN (server + app Android)
echo ==========================================================
echo.

REM ===== 1. Kiem tra cong cu =====
where flutter >nul 2>nul
if errorlevel 1 (
  echo [LOI] Khong tim thay Flutter. Cai Flutter SDK roi them vao PATH.
  goto :fail
)
where node >nul 2>nul
if errorlevel 1 (
  echo [LOI] Khong tim thay Node.js. Cai tu https://nodejs.org roi chay lai file nay.
  goto :fail
)
echo [1/7] Flutter + Node.js - OK

REM ===== 2. Dependency cua app Flutter =====
echo.
echo [2/7] flutter pub get...
call flutter pub get >nul 2>nul
if errorlevel 1 (
  echo [LOI] flutter get that bai.
  goto :fail
)
echo        OK

REM ===== 3. Dependency cua server =====
echo.
echo [3/7] npm install (server)...
pushd "%~dp0server"
call npm install --no-audit --no-fund >nul 2>nul
if errorlevel 1 (
  popd
  echo [LOI] npm install that bai - kiem tra mang roi chay lai.
  goto :fail
)
popd
echo        OK

REM ===== 4. Tao certificate HTTPS (neu chua co) =====
echo.
echo [4/7] Kiem tra certificate HTTPS (cert pinning)...
pushd "%~dp0server"
call npm run gen-cert --silent >nul 2>nul
popd
echo        OK

REM ===== 5. Tim ADB =====
set "ADB="
where adb >nul 2>nul
if not errorlevel 1 set "ADB=adb"
if not defined ADB if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not defined ADB if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"

REM ===== 6. Build APK =====
echo.
echo [5/7] Build APK debug (lan dau co the mat 2-5 phut)...
call flutter build apk --debug
if errorlevel 1 (
  echo [LOI] Build APK that bai - xem loi o tren.
  goto :fail
)
echo        APK: build\app\outputs\flutter-apk\app-debug.apk

if not defined ADB (
  echo.
  echo [CANH BAO] Khong tim thay ADB - bo qua buoc cai vao dien thoai.
  echo        Cai Android SDK platform-tools roi chay lai file nay.
  goto :start_server
)

set "SERIAL="
for /f "skip=1 tokens=1,2" %%a in ('""%ADB%" devices"') do (
  if not defined SERIAL if "%%b"=="device" set "SERIAL=%%a"
)
if not defined SERIAL (
  echo.
  echo [CANH BAO] Khong thay dien thoai nao - cam cap USB roi chay lai file nay.
  echo        Bat Cai dat - Nha phat trien - Go do USB tren dien thoai truoc.
  goto :start_server
)

echo.
echo [6/7] Cai APK vao dien thoai %SERIAL%...
"%ADB%" -s %SERIAL% install -r "build\app\outputs\flutter-apk\app-debug.apk"
REM Chuyen tiep cong 3000 tu dien thoai - PC (qua cap USB)
"%ADB%" -s %SERIAL% reverse tcp:3000 tcp:3000
echo        Da cai + da mo cong adb reverse tcp:3000

:start_server

REM ===== 7. Khoi dong server =====
echo.
echo [7/7] Khoi dong server...
netstat -ano | findstr ":3000" | findstr "LISTENING" >nul
if not errorlevel 1 (
  echo        Server dang chay tren cong 3000 - bo qua.
) else (
  start "SoulMate Server" cmd /k node "%~dp0server\src\index.js"
  echo        Server da mo trong cua so "SoulMate Server".
)

REM Mo app neu da cai
if defined SERIAL if defined ADB (
  "%ADB%" -s %SERIAL% shell am start -n com.datingapp.dating_app/.MainActivity >nul 2>nul
)

echo.
echo ==========================================================
echo   HOAN TAT!
echo.
echo   - Tai khoan thu: demo1@soulmate.app / Demo@1234
echo   - Dang ky moi: dung nut "Dang ky" trong app
echo   - Server: https://localhost:3000 (dien thoai qua cap USB)
echo.
echo   Chay lai file nay bat cu khi nao muon build + cai app moi.
echo   Muon chay app o che do dev (hot reload):  flutter run
echo ==========================================================
echo.
if /i "%~1"=="--nopause" exit /b 0
pause
exit /b 0

:fail
echo.
echo *** CAI DAT THAT BAI - xem thong bao loi o tren ***
if /i "%~1"=="--nopause" exit /b 1
pause
exit /b 1
