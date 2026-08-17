# Rozszerzenia VS Code — gotowe paczki

To repozytorium nie zawiera kodu. Są tu wyłącznie **gotowe paczki `.vsix`** —
widoczne wprost na liście plików wyżej i odświeżane automatycznie po każdej
zmianie w źródłach (data ostatniego commita = data ostatniego builda).
Źródła są w osobnym, prywatnym repozytorium.

Repozytorium jest publiczne, więc pobieranie idzie zwykłym HTTPS — bez tokena
i bez logowania.

Te same pliki wiszą jako załączniki release'u
**[`latest-build`](../../releases/tag/latest-build)** — podmieniane w miejscu
przez ten sam build, który aktualizuje listę plików, więc to jeden zestaw,
nie dwa. Opis release'u niesie **datę builda, źródłowy commit i tabelę
wersji** — po tym poznasz, że są nowe paczki.

## Instalacja na maszynie bez dostępu do sieci dla skryptów

Na maszynie, na której sieć działa tylko w przeglądarce (firmowe proxy z PAC,
którego `curl` nie przejdzie):

1. Pobierz przeglądarką
   **[`all-extensions.zip`](../../releases/download/latest-build/all-extensions.zip)**
   ze strony release'u [`latest-build`](../../releases/tag/latest-build).
   W środku są wszystkie `.vsix` oraz instalator.
2. Rozpakuj i w terminalu VS Code uruchom skrypt z rozpakowanego katalogu:

```bash
bash build-and-install.sh --local       # instaluje .vsix leżące obok skryptu
```

Skrypt nie wykona ani jednego połączenia sieciowego i pominie to, co w edytorze
jest już aktualne.

## Instalacja na maszynie z działającą siecią

Na macOS, Linuksie albo Windowsie z Git Bashem wystarczy sam
**[`build-and-install.sh`](build-and-install.sh)** — też leży na liście plików
wyżej i nie potrzebuje kopii repozytorium:

```bash
./build-and-install.sh                  # wszystko, co nieaktualne
./build-and-install.sh api-designer     # tylko wskazane rozszerzenia
FORCE=1 ./build-and-install.sh          # zainstaluj także to, co aktualne
```

Potrzebuje `curl` (albo `wget`) i CLI VS Code — nie potrzebuje Node.js ani npm.
Listę wersji i paczki pobiera z listy plików tego repozytorium
(`raw.githubusercontent.com`). Opisany w jego pomocy tryb `--build` **tutaj nie
zadziała**: buduje ze źródeł, a w tym repozytorium źródeł nie ma.

Po instalacji przeładuj okno VS Code (**Developer: Reload Window**).

## Instalacja ręczna

Pojedynczą paczkę można pobrać ze strony release'u (albo z listy plików wyżej,
przycisk **Download raw file** — to ten sam zestaw) i zainstalować przez
**Extensions → `…` → Install from VSIX…**, albo:

```bash
code --install-extension api-designer.vsix
```

## Co jest w repozytorium i w release'ie

| Plik | Zawartość |
|---|---|
| `<nazwa>.vsix` | paczka rozszerzenia, **bez numeru wersji w nazwie** — dzięki temu adres do pobrania jest stały |
| `versions.txt` | wersje w formacie `katalog\|id\|wersja\|plik` |
| `all-extensions.zip` | wszystkie `.vsix` + `build-and-install.sh`, do instalacji bez sieci (`--local`) |
| `build-and-install.sh` | instalator (bash) |
| `skills/`, `skills.zip` | skille agentowe jadące razem z rozszerzeniami |
