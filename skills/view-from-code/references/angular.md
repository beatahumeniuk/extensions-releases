# Angular + NgRx — skąd brać dowody

Komendy są punktem wyjścia. Składnia zależy od tego, jak pisze zespół
(Material, PrimeNG, własna biblioteka; formularze reaktywne czy
template-driven). **Sprawdź pierwsze wywołanie na prawdziwym komponencie
i dostosuj wzorce**, zanim polecisz przez całe drzewo.

Wszystkie używają `rg -o` z podstawieniem: zwracają **wartość, nie linię**.

## Plik `.ts` to nie jest widok

Pola, etykiety, warunki widoczności i identyfikatory testowe są
w **szablonie**. Reguły walidacji — w definicji formularza. Komponent
czytany bez `.html` i bez `FormGroup` opisze klasę, nie ekran.

## Szablon i dzieci

```bash
rg -o 'templateUrl:\s*.([^\x27"]+)' -r '$1' <komponent>.ts
rg -o '<(app|ui|lib)-[a-z0-9-]+' <szablon>.html | sort -u
```

Selektory dzieci — **to jest lista do przetworzenia pojedynczo**, jeden
komponent na przebieg. Nie wciągaj całego drzewa naraz.

## Identyfikatory testowe

```bash
rg -o '(data-testid|data-test|attr\.data-test)="([^"]+)"' -r '$2' <szablon>.html
```

Najpewniejszy klucz dopasowania do katalogu z Figmy — jeśli analityk
wypełnił `testId`, trafienie jest pewne.

## Walidacja

```bash
rg -o 'Validators\.(\w+)\(([^)]*)\)' -r '$1 $2' <komponent>.ts
rg -n 'new FormControl|FormBuilder|formControlName' <komponent>.ts <szablon>.html
```

| W kodzie | Klucz `values` |
|---|---|
| `Validators.required` | `required: true` |
| `Validators.minLength(n)` / `maxLength(n)` | `minLen` / `maxLen` |
| `Validators.min(n)` / `max(n)` | `minVal` / `maxVal` |
| `Validators.pattern(…)` | `regex` |

Walidator własny (`myValidator`) — kwestia otwarta z `plik:linia`, nie
zgadywanie, co sprawdza.

## Widoczność i stan

```bash
rg -o '\*ngIf="([^"]+)"' -r '$1' <szablon>.html
rg -n '\[disabled\]|\.disable\(\)|\.enable\(\)' <szablon>.html <komponent>.ts
```

`*ngIf` na kontrolce → `visible: "Warunkowo"` + `condition` z wyrażeniem.

## Store

```bash
rg -o 'store\.select\((\w+)' -r '$1' <komponent>.ts
rg -o 'store\.dispatch\((\w+)' -r '$1' <komponent>.ts
```

Selektor zasilający kontrolkę → `entries` z `role: "response"`.
Dispatch → prowadzi do efektu, a dopiero efekt do HTTP.

## HTTP

```bash
rg -o 'this\.http\.(get|post|put|patch|delete)<[^>]*>\(([^,)]+)' -r '$1 $2' <serwis>.ts
rg -n 'createEffect|ofType' <efekty>.ts
```

Endpoint zwykle nie jest w komponencie. Ścieżka: kontrolka → dispatch →
efekt → serwis → `this.http`. **Każdy przeskok, którego nie da się przejść,
to kwestia otwarta**, nie domysł.

## Tabele

```bash
rg -o 'displayedColumns\s*[:=]\s*\[([^\]]+)\]' -r '$1' <komponent>.ts
rg -o 'matColumnDef="([^"]+)"' -r '$1' <szablon>.html
```

## Czego analiza statyczna nie zobaczy

Wszystko poniżej → `analysis.issues`, nigdy domysł:

- **wstrzykiwanie zależności** — który serwis stoi za tokenem, rozstrzyga
  konfiguracja providerów, nie import
- **komponenty dynamiczne** — `ViewContainerRef.createComponent`,
  `*ngComponentOutlet`
- **łańcuchy efektów** — `dispatch` → efekt → `dispatch` → dopiero HTTP
- **interceptory** — bazowy URL i przepisywanie ścieżek poza komponentem,
  więc ścieżka endpointu bywa niepełna
- **feature flagi** — widoczność nierozstrzygalna statycznie
- **kod generowany** — modele z OpenAPI, tłumaczenia

To nie są luki skilla. To granice metody i mają być widoczne w wyniku.
