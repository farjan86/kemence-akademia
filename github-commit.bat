@echo off
REM =====================================================================
REM  Kemence Akademia - GitHub feltoltes (commit + push)
REM  Repo: https://github.com/farjan86/kemence-akademia
REM
REM  Hasznalat:
REM    - Dupla kattintas    -> alapertelmezett commit uzenet (datum/ido)
REM    - Parancssorbol:      github-commit.bat "sajat commit uzenet"
REM =====================================================================
setlocal
cd /d "%~dp0"

set REPO=https://github.com/farjan86/kemence-akademia.git

REM --- Git telepitve van-e? ---
where git >nul 2>nul
if errorlevel 1 (
  echo [HIBA] A git nincs telepitve vagy nincs a PATH-ban.
  echo        Telepitsd innen: https://git-scm.com/download/win
  pause
  exit /b 1
)

REM --- Elso inditas: repo letrehozas + remote beallitas ---
if not exist ".git" (
  echo [1/5] Git repo letrehozasa...
  git init
  git branch -M main
  git remote add origin %REPO%
) else (
  git remote get-url origin >nul 2>nul || git remote add origin %REPO%
)

REM --- Biztositjuk, hogy a "main" agon vagyunk ---
git branch -M main

REM --- Commit uzenet: a parancssori argumentum, vagy datum/ido ---
set "MSG=%~1"
if "%MSG%"=="" set "MSG=Frissites %DATE% %TIME%"

echo [2/5] Valtozasok hozzaadasa (a .gitignore kizarja a titkokat)...
git add -A
echo    --- Ami fel fog kerulni (ellenorizd: NINCS kozte titok!): ---
git status --short
echo    ------------------------------------------------------------

echo [3/5] Commit: "%MSG%"
git commit -m "%MSG%"
if errorlevel 1 echo [INFO] Nincs commitolando valtozas - tovabblepes a push-ra.

echo [4/5] Push a GitHubra (main ag)...
git push -u origin main
if errorlevel 1 (
  echo.
  echo [FIGYELEM] A push nem sikerult. Lehetseges okok:
  echo   1) Elso alkalommal be kell jelentkezni a GitHubra (bongeszo / GitHub bejelentkezes).
  echo   2) A tavoli repoban mar van commit (pl. README/LICENSE). Ez esetben EGYSZER futtasd:
  echo        git pull origin main --allow-unrelated-histories --no-edit
  echo      majd inditsd ujra ezt a bat-ot.
  echo.
  pause
  exit /b 1
)

echo [5/5] KESZ. Feltoltve ide: %REPO%
pause
