# Rozszerzenia VS Code — gotowe paczki

To repozytorium nie zawiera kodu. Są tu wyłącznie **gotowe paczki `.vsix`**,
doczepiane automatycznie do release'u
[`latest-build`](../../releases/tag/latest-build) po każdej zmianie w źródłach.
Źródła są w osobnym, prywatnym repozytorium.

Repozytorium jest publiczne, więc pobieranie idzie zwykłym HTTPS — bez tokena
i bez logowania.

## Instalacja bez Node.js, gita i basha

Na maszynie, która ma tylko Windows i VS Code:

1. Pobierz **[`install-extensions.cmd`](install-extensions.cmd)** — leży wyżej,
   na liście plików tego repozytorium. Kliknij go, potem przycisk pobierania
   (albo *Raw*), i zapisz gdziekolwiek. Kopia repozytorium nie jest potrzebna.
2. Uruchom go (dwuklik albo z wiersza poleceń).

Ten sam plik jest doczepiony do
[release'u](../../releases/download/latest-build/install-extensions.cmd) —
obie kopie trzyma w zgodzie ten sam build, więc obojętne, skąd go weźmiesz.

To zwykły plik wsadowy: **bez PowerShella**, bez basha, bez interpretera do
doinstalowania. Wywołuje wyłącznie `curl.exe` (część Windowsa od wersji 1803)
oraz `code.cmd` z VS Code. Czyta z release'u listę wersji, porównuje ją z tym,
co już jest w edytorze, i pobiera tylko to, czego brakuje albo co jest
nieaktualne.

```bat
install-extensions.cmd                  :: wszystko, co nieaktualne
install-extensions.cmd api-designer     :: tylko wskazane rozszerzenia
install-extensions.cmd /list            :: pokaż, co by się zmieniło
install-extensions.cmd /force           :: zainstaluj także to, co aktualne
```

Po instalacji przeładuj okno VS Code (**Developer: Reload Window**).

## Instalacja ręczna

Pojedynczą paczkę można pobrać z release'u i zainstalować przez
**Extensions → `…` → Install from VSIX…**, albo:

```bash
code --install-extension api-designer.vsix
```

## Co jest w release'ie

| Plik | Zawartość |
|---|---|
| `<nazwa>.vsix` | paczka rozszerzenia, **bez numeru wersji w nazwie** — dzięki temu adres do pobrania jest stały |
| `versions.txt` | wersje w formacie `katalog\|id\|wersja\|plik` |
| `install-extensions.cmd` | instalator dla Windowsa |
