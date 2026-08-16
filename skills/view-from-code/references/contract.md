# Kontrakt wyjścia

Piszesz **jeden plik**: `analysis/ui/<pakiet>/view-mapping.json`.

Pełny schemat i słownik pól leżą w tym samym repo, w
[`ui-analysis/schema/`](../../../ui-analysis/schema/):

- `view-mapping.schema.json` — JSON Schema draft-07 (10 KB; do walidacji
  narzędziem, nie do czytania przed każdą analizą)
- `field-keys.json` — dozwolone klucze `values` per typ komponentu (31 KB;
  **odpytuj `jq`**, nie wczytuj)
- `README.md` — zasady kontraktu

Poniżej tyle, ile trzeba, żeby napisać plik bez sięgania po tamte.

## Kształt

```json
{
  "schemaVersion": 4,
  "endpoints": [
    { "id": "ep-1", "method": "POST", "path": "/offer/details",
      "note": "", "samples": {} }
  ],
  "entries": [
    { "componentId": "1:23", "componentName": "PESEL",
      "fieldPath": "wnioskodawca.pesel", "role": "request",
      "endpointId": "ep-1", "suggested": true,
      "note": "offer-form.component.ts:42" }
  ],
  "analysis": {
    "values": { "1:23.testId": "wniosek.pesel", "1:23.required": true },
    "types": { "1:23": "Input" },
    "actions": { "1:30": [
      { "id": "a1", "kind": "Endpoint", "target": "POST /offer/details",
        "doc": "", "success": "", "error": "" }
    ]},
    "columns": { "1:40": [
      { "id": "c1", "name": "Nr", "field": "pozycje[].nr",
        "sort": true, "filter": false }
    ]},
    "issues": [
      { "id": "i1", "componentId": "1:50", "field": "walidacja",
        "status": "Do ustalenia",
        "comment": "Reguła tylko po stronie serwera — offer.service.ts:88" }
    ]
  }
}
```

## Klucze, które muszą się zgadzać

**`componentId`, klucze w `values`/`types`/`actions`/`columns`** — to
`figmaNodeId` z `analysis-model.json`. Nigdy własne.

**`endpointId` w `entries`** wskazuje `id` z tablicy `endpoints` tego samego
pliku.

**Klucz w `values`** ma postać `"<figmaNodeId>.<klucz pola>"`. Dozwolone
klucze **zależą od typu komponentu**; klucz nierozpoznany dla danego typu
znika przy wczytaniu bez ostrzeżenia. Sprawdź zanim napiszesz:

```bash
jq -c '.byType["Input"].keys' field-keys.json
```

## Wartości zamknięte

| Pole | Dozwolone |
|---|---|
| `method` | `GET` `POST` `PUT` `PATCH` `DELETE` |
| `role` | `request` `response` |
| `kind` (krok akcji) | `Endpoint` `Navigate` `Open Modal` `Close Modal` `Download File` `Refresh` `Show Message` |
| `status` (kwestia) | `Do uzupełnienia` `Do ustalenia` `Czeka na dane` `Nie dotyczy` `Rozwiązane` |
| `types[...]` | 26 typów analitycznych — `jq -r '.byType \| keys[]' field-keys.json` |

Pierwsze trzy statusy liczą się jako **otwarte** i trafiają do licznika
w dokumencie.

## Najczęściej używane klucze `values`

Dostępne dla większości typów pól. Pełna lista per typ — przez `jq`.

| Klucz | Co znaczy |
|---|---|
| `testId` | identyfikator testowy; **pierwsza klauzula** w dokumencie |
| `required` | `true`/`false` |
| `minLen` / `maxLen` | długość tekstu |
| `minVal` / `maxVal` | zakres wartości |
| `regex` | wzorzec |
| `visible` | `Zawsze` / `Warunkowo` / `Ukryty` |
| `condition` | warunek, gdy `visible: "Warunkowo"` |
| `enabled` | aktywność kontrolki |
| `placeholder`, `help`, `tooltip` | teksty pomocnicze |
| `options` | lista wartości (tablica) |
| `default` | wartość domyślna |
| `transform` | przekształcenie przy wysyłce |

## Scalanie: człowiek wygrywa

Jeśli `view-mapping.json` już istnieje, **wczytaj go i zachowaj każdą
wartość, która tam jest**. Dokładasz wyłącznie brakujące. Ponowne
uruchomienie skilla nie może skasować pracy analityka.

## Dowody

Każde ustalenie niesie ślad pochodzenia — w `note` przy wpisie albo
w `comment` kwestii otwartej, w formacie `plik:linia`. Analityk musi móc
skoczyć do miejsca, zamiast szukać po module.
