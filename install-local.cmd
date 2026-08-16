@echo off
REM ---------------------------------------------------------------------------
REM Instaluje w VS Code wszystkie paczki .vsix lezace w tym samym folderze.
REM
REM Nie laczy sie z niczym. Zadnej sieci, zadnego pobierania, zadnego proxy -
REM czyta pliki z dysku i podaje je edytorowi. Do uzycia tam, gdzie maszyna nie
REM ma wyjscia na zewnatrz albo nie powinna go uzywac.
REM
REM   install-local.cmd            zainstaluj wszystko z tego folderu
REM   install-local.cmd /nopause   nie czekaj na klawisz na koncu
REM ---------------------------------------------------------------------------
echo.
echo ==========================================
echo   Instalator rozszerzen VS Code (offline)
echo ==========================================
echo.

setlocal

set "NOPAUSE="
if /i "%~1"=="/nopause" set "NOPAUSE=1"

REM Folder tego pliku, ze slashem na koncu. Dzieki temu dziala tak samo po
REM dwukliku, jak i uruchomiony z innego katalogu.
set "HERE=%~dp0"

echo [1/3] Szukam CLI VS Code...
set "CODE="
where code.cmd >nul 2>&1 && for /f "delims=" %%p in ('where code.cmd') do if not defined CODE set "CODE=%%p"
if not defined CODE if exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd" set "CODE=%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd"
if not defined CODE if exist "%ProgramFiles%\Microsoft VS Code\bin\code.cmd"          set "CODE=%ProgramFiles%\Microsoft VS Code\bin\code.cmd"
if not defined CODE if exist "%ProgramFiles(x86)%\Microsoft VS Code\bin\code.cmd"     set "CODE=%ProgramFiles(x86)%\Microsoft VS Code\bin\code.cmd"
if not defined CODE (
  echo       NIE ZNALEZIONO polecenia `code`.
  echo       Otworz VS Code, nacisnij Ctrl+Shift+P i wybierz
  echo       "Shell Command: Install 'code' command in PATH", potem sprobuj ponownie.
  goto fail
)
echo       %CODE%

echo [2/3] Szukam paczek .vsix obok tego pliku...
set "FOUND=0"
for %%f in ("%HERE%*.vsix") do set /a FOUND+=1
if "%FOUND%"=="0" (
  echo       NIE ZNALEZIONO zadnego pliku .vsix w:
  echo       %HERE%
  echo       Rozpakuj paczke do konca - instalator musi lezec razem z .vsix-ami.
  goto fail
)
echo       znalazlem: %FOUND%
echo.

echo [3/3] Instaluje...
set "OKN=0"
set "FAILN=0"
for %%f in ("%HERE%*.vsix") do call :one "%%f"

echo.
echo ============ PODSUMOWANIE ============
echo   zainstalowane: %OKN%
echo   bledy:         %FAILN%
if not "%FAILN%"=="0" goto fail
echo.
echo Przeladuj okno VS Code ^(Ctrl+Shift+P -^> Developer: Reload Window^).
call :waitkey
endlocal & exit /b 0

REM ---------------------------------------------------------------------------
REM Kazda paczka w podprocedurze, zeby nie bylo potrzebne opoznione rozwijanie
REM zmiennych - w petli for lubi ono zjadac wykrzykniki i nawiasy ze sciezek.
:one
echo   [^>] %~nx1
REM code.cmd to plik wsadowy - bez `call` sterowanie nie wrocilo by tutaj.
call "%CODE%" --install-extension "%~1" --force
if errorlevel 1 (
  echo       BLAD instalacji
  set /a FAILN+=1
) else (
  set /a OKN+=1
)
goto :eof

REM ---------------------------------------------------------------------------
REM Czekamy na klawisz zawsze, chyba ze poproszono inaczej. Po dwukliku okno
REM znikneloby razem z komunikatem o bledzie, a to wlasnie ten komunikat jest
REM potrzebny, zeby cokolwiek naprawic.
:waitkey
if defined NOPAUSE goto :eof
echo.
pause
goto :eof

:fail
echo.
echo Instalacja przerwana.
call :waitkey
endlocal & exit /b 1
