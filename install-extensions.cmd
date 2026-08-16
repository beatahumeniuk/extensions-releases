@echo off
REM ---------------------------------------------------------------------------
REM Instaluje w VS Code najnowsze zbudowane wersje rozszerzen.
REM
REM Czysty plik wsadowy: bez PowerShella, bez basha, bez gita, bez Node.js
REM i bez kopii repozytorium. Wystarczy Windows z VS Code.
REM
REM Nie loguje sie nigdzie i nie prosi o zadne dane: paczki leza w publicznym
REM release, wiec curl pobiera je anonimowo, zwyklym HTTPS.
REM
REM curl.exe jest czescia Windowsa od wersji 1803, wiec nie trzeba nic doinstalowac.
REM
REM   install-extensions.cmd                    wszystko, co nieaktualne
REM   install-extensions.cmd api-designer       tylko wskazane rozszerzenia
REM   install-extensions.cmd /force             zainstaluj takze to, co aktualne
REM   install-extensions.cmd /list              pokaz, co by sie zmienilo
REM   install-extensions.cmd /debug             wypisz kazde wykonywane polecenie
REM   install-extensions.cmd /nopause           nie czekaj na klawisz na koncu
REM ---------------------------------------------------------------------------

REM Komunikat od razu, w pierwszej mozliwej linii. Jesli po uruchomieniu nie
REM widac nawet tego, to znaczy, ze plik w ogole nie zostal wykonany jako plik
REM wsadowy (otworzyl sie w edytorze, ma zla nazwe albo blokuje go polityka) -
REM i wiadomo, ze szukac trzeba tam, a nie w tresci skryptu.
echo.
echo ==========================================
echo   Instalator rozszerzen VS Code
echo ==========================================
echo.

setlocal

REM Publiczne repozytorium z samymi paczkami. Zrodla siedza gdzie indziej i moga
REM byc prywatne - stad nic sie tu nie pobiera, wiec ta maszyna nigdy nie musi
REM byc zalogowana do GitHuba.
set "REPO=beatahumeniuk/extensions-releases"
set "TAG=latest-build"
set "BASE=https://github.com/%REPO%/releases/download/%TAG%"

REM Adres na wierzchu, a nie dopiero w komunikacie o bledzie: jesli cokolwiek
REM na tej maszynie poprosi o zalogowanie, od razu widac, ze nie o to chodzi.
echo Pobieram wylacznie stad, anonimowo, bez logowania:
echo   %BASE%
echo.

set "FORCE="
set "LISTONLY="
set "NOPAUSE="
set "ONLY= "

REM Kazdy warunek domyka wlasny nawias: w plikach wsadowych `if ... cmd1 & cmd2`
REM wykonuje cmd2 zawsze, niezaleznie od warunku.
:parse
if "%~1"=="" goto parsed
if /i "%~1"=="/force"   ( set "FORCE=1"    & shift & goto parse )
if /i "%~1"=="/list"    ( set "LISTONLY=1" & shift & goto parse )
if /i "%~1"=="/nopause" ( set "NOPAUSE=1"  & shift & goto parse )
if /i "%~1"=="/debug"   ( echo on          & shift & goto parse )
if /i "%~1"=="/?"     goto usage
if /i "%~1"=="-h"     goto usage
if /i "%~1"=="--help" goto usage
REM Spacje z obu stron, zeby "api-designer" nie lapalo sie na "api-designer-2".
set "ONLY=%ONLY%%~1 "
shift
goto parse
:parsed

REM ---- 1/5 curl --------------------------------------------------------------
echo [1/5] Szukam curl.exe...
where curl.exe >nul 2>&1
if errorlevel 1 (
  echo       NIE ZNALEZIONO. curl.exe jest czescia Windowsa od wersji 1803.
  echo       Na starszym systemie pobierz paczki .vsix recznie:
  echo       https://github.com/%REPO%/releases/tag/%TAG%
  goto fail
)
echo       jest.

REM ---- 2/5 CLI VS Code -------------------------------------------------------
echo [2/5] Szukam CLI VS Code...
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

REM ---- 3/5 katalog roboczy ---------------------------------------------------
echo [3/5] Przygotowuje katalog roboczy...
set "WORK=%TEMP%\vsix-%RANDOM%%RANDOM%"
mkdir "%WORK%" 2>nul
if not exist "%WORK%" (
  echo       NIE UDALO SIE utworzyc %WORK%
  goto fail
)
echo       %WORK%

REM ---- 4/5 lista wersji ------------------------------------------------------
echo [4/5] Pobieram liste wersji z release'u '%TAG%'...
curl -fsSL -o "%WORK%\versions.txt" "%BASE%/versions.txt"
if errorlevel 1 (
  echo       NIE UDALO SIE pobrac %BASE%/versions.txt
  echo       Sprawdz polaczenie z siecia albo dostep do github.com.
  goto fail
)
REM Pusty plik przy kodzie 0 oznaczalby, ze curl poszedl za czyms innym niz
REM paczka - lepiej powiedziec to teraz niz milczec przez cala petle.
REM Rozmiar w cudzyslowie: gdyby pliku nie bylo, goly %%~zs jest pusty
REM i `if  EQU 0 (` wywala sie bledem skladni zamiast dac komunikat.
for %%s in ("%WORK%\versions.txt") do if "%%~zs"=="0" (
  echo       POBRANY PLIK JEST PUSTY - przerywam.
  goto fail
)
for /f %%n in ('type "%WORK%\versions.txt" ^| find /c /v ""') do echo       rozszerzen w buildzie: %%n

REM ---- 5/5 co juz jest -------------------------------------------------------
echo [5/5] Sprawdzam, co jest juz zainstalowane...
REM code.cmd to plik wsadowy - bez `call` sterowanie nie wrocilo by tutaj.
call "%CODE%" --list-extensions --show-versions > "%WORK%\installed.txt" 2>nul
REM Bez nawiasow w tresci echo: w jednolinijkowym `if` cmd.exe potrafi wziac
REM nawias zamykajacy za koniec bloku.
if errorlevel 1 echo       uwaga: nie udalo sie odczytac listy - zainstaluje wszystko
echo.

set "OKN=0"
set "SKIPN=0"
set "FAILN=0"

REM Kazda linia obslugiwana w podprocedurze - dzieki temu nie trzeba opoznionego
REM rozwijania zmiennych, ktore w petli for lubi zjadac wykrzykniki i nawiasy.
for /f "usebackq eol=# tokens=1-4 delims=|" %%a in ("%WORK%\versions.txt") do call :one "%%a" "%%b" "%%c" "%%d"

echo.
echo ============ PODSUMOWANIE ============
echo   zainstalowane: %OKN%
echo   bez zmian:     %SKIPN%
echo   bledy:         %FAILN%
if not "%FAILN%"=="0" goto fail
if not "%OKN%"=="0" (
  echo.
  echo Przeladuj okno VS Code ^(Ctrl+Shift+P -^> Developer: Reload Window^).
)

rmdir /s /q "%WORK%" 2>nul
call :waitkey
endlocal & exit /b 0

REM ---------------------------------------------------------------------------
:one
set "NAME=%~1"
set "ID=%~2"
set "VER=%~3"
set "ASSET=%~4"
if "%ASSET%"=="" goto :eof

REM Nazwy podane w argumentach zawezaja liste. Bez potoku i bez nawiasow:
REM potok wewnatrz bloku ( ... ) uruchamia go w podprocesie i psuje `goto`.
REM `call set` daje druga runde rozwijania, wiec %NAME% wchodzi do wzorca
REM podstawienia bez wlaczania opoznionego rozwijania zmiennych.
if "%ONLY%"==" " goto :nofilter
set "HIT=%ONLY%"
call set "HIT=%%HIT: %NAME% =%%"
if "%HIT%"=="%ONLY%" goto :eof
:nofilter

if not defined FORCE (
  findstr /i /x /c:"%ID%@%VER%" "%WORK%\installed.txt" >nul 2>&1
  if not errorlevel 1 (
    echo   [=] %NAME% %VER% - juz aktualne
    set /a SKIPN+=1
    goto :eof
  )
)

if defined LISTONLY (
  echo   [^>] %NAME% %VER% - do zainstalowania
  goto :eof
)

echo   [^>] %NAME% %VER% - pobieram...
curl -fsSL -o "%WORK%\%ASSET%" "%BASE%/%ASSET%"
if errorlevel 1 (
  echo       BLAD pobierania %BASE%/%ASSET%
  set /a FAILN+=1
  goto :eof
)

echo       instaluje...
call "%CODE%" --install-extension "%WORK%\%ASSET%" --force
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

:usage
echo install-extensions.cmd [/force] [/list] [/debug] [/nopause] [nazwa ...]
echo.
echo   /force     zainstaluj takze to, co juz jest w aktualnej wersji
echo   /list      pokaz, co by sie zmienilo, i zakoncz
echo   /debug     wypisz kazde wykonywane polecenie (do zglaszania bledow)
echo   /nopause   nie czekaj na klawisz na koncu
echo   nazwa      ogranicz do wskazanych rozszerzen
call :waitkey
endlocal & exit /b 0

:fail
echo.
echo Instalacja przerwana.
if defined WORK rmdir /s /q "%WORK%" 2>nul
call :waitkey
endlocal & exit /b 1
