@echo off
REM =====================================================================
REM  Kemence Akademia - ELES TELEPITESI CSOMAG (indito)
REM
REM  A munkat a build_deploy.py vegzi: a web\ mappabol legyartja a
REM  deploy_web\ mappat, kihagyja a js\config.js-t, a .htaccess-t es a nem
REM  hasznalt kepeket, majd ellenorzi, hogy nem maradt-e a csomagban fejlesztoi
REM  vagy demo adat. A reszletek a .py fajl elejen vannak leirva.
REM
REM  Ez a .bat csak elinditja, hogy dupla kattintassal is mukodjon.
REM
REM  Hasznalat:
REM    - Dupla kattintas  -> ratkerdez a deploy_web uritesere
REM    - build.bat /Y     -> kerdes es varakozas nelkul epit
REM =====================================================================
setlocal
cd /d "%~dp0"

REM --- A Python ekezetes kimenetehez UTF-8 kodlap kell a konzolon ---
chcp 65001 >nul
set "PYTHONIOENCODING=utf-8"

set "ARG="
if /i "%~1"=="/Y" set "ARG=--yes"
if /i "%~1"=="-y" set "ARG=--yes"

REM --- Python keresese: eloszor "python", utana "py" ---
set "PY="
where python >nul 2>nul && set "PY=python"
if not defined PY (
  where py >nul 2>nul && set "PY=py"
)
if not defined PY (
  echo [HIBA] Nem talalom a Pythont a gepen.
  echo        Telepitsd innen: https://www.python.org/downloads/
  echo(
  pause
  exit /b 1
)

%PY% "%~dp0build_deploy.py" %ARG%
set "EC=%ERRORLEVEL%"

if not "%ARG%"=="--yes" pause
exit /b %EC%
