@echo off
cd /d "%~dp0."
"%~dp0cloudflared.exe" tunnel --url https://localhost:3000 --no-tls-verify > "%~dp0..\tunnel.log" 2>&1
