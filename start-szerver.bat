@echo off
title Kemence Akademia - helyi szerver
set "PORT=5500"
set "WEBDIR=%~dp0web"

echo(
echo ==========================================================
echo    KEMENCE AKADEMIA - helyi fejlesztoi szerver
echo ==========================================================
echo(
echo    Publikus oldal  :  http://localhost:%PORT%/
echo    Admin felulet   :  http://localhost:%PORT%/admin/
echo(
echo    Kiszolgalt mappa:  %WEBDIR%
echo    Leallitas       :  Ctrl+C, vagy zard be ezt az ablakot
echo ==========================================================
echo(
echo    (Csak a fajlokat szolgalja ki. Az adat a Supabase-bol jon.)
echo(

cd /d "%WEBDIR%"

where python >nul 2>nul && (
  python -m http.server %PORT% --bind 127.0.0.1
) || (
  py -m http.server %PORT% --bind 127.0.0.1
)

echo(
echo A szerver leallt. Nyomj egy billentyut a bezarashoz.
pause >nul
