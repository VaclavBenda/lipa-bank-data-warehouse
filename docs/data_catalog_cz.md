# Data Catalog – Lipa Bank a.s. DWH

Datový slovník pro všechny tři vrstvy datového skladu.
Účel: kdokoliv, kdo se podívá na projekt, musí bez čtení SQL kódu vědět,
co každá tabulka a každý sloupec obsahuje.

---

## Bronze Layer – zdrojová data (syrová)

### `bronze.core_client_extract`
Měsíční periodický export klientů ze systému CORE. Jeden klient = více řádků (jeden na každý extrakt).

| Sloupec | Popis |
|---|---|
| extract_date | Datum, kdy CORE provedl periodický export |
| client_id | Interní identifikátor klienta v CORE (formát `C00001`) |
| first_name | Křestní jméno |
| last_name | Příjmení |
| birth_date | Datum narození |
| email | E-mailová adresa (může chybět) |
| phone | Telefonní číslo – nekonzistentní formát ve zdroji |
| address_city | Město bydliště |
| segment | Segment klienta – nekonzistentní casing ve zdroji (Retail/retail/RETAIL…) |
| client_since_date | Datum, kdy se klient stal klientem banky |

### `bronze.core_product`
Statický katalog bankovních produktů.

| Sloupec | Popis |
|---|---|
| product_id | Identifikátor produktu (formát `P01`) |
| product_name | Název produktu |
| product_category | Kategorie: `Běžný účet` nebo `Spořicí účet` |

### `bronze.core_account`
Bankovní účty klientů.

| Sloupec | Popis |
|---|---|
| account_id | Identifikátor účtu (formát `A000001`) |
| client_id | Odkaz na klienta v `core_client_extract` |
| product_id | Odkaz na produkt v `core_product` |
| open_date | Datum otevření účtu |
| close_date | Datum uzavření účtu (prázdné = stále aktivní) |
| status | Stav: `Active`, `Closed`, `Dormant` |
| currency | Měna: `CZK` nebo `EUR` |

### `bronze.core_account_balance_extract`
Měsíční extrakt zůstatku účtu. Grain: jeden řádek = jeden účet × jeden měsíc.

| Sloupec | Popis |
|---|---|
| extract_month | První den měsíce, za který je extrakt |
| account_id | Odkaz na účet |
| balance | Zůstatek účtu (může být prázdný nebo záporný – viz DQ checks) |

### `bronze.cards_card_master`
Platební karty ze systému CARDS (jiný dodavatel než CORE).

| Sloupec | Popis |
|---|---|
| card_id | Identifikátor karty (formát `K000001`) |
| account_id | Odkaz na účet v CORE – **nemusí existovat** (orphan karty) |
| cif | Vlastní reference klienta v systému CARDS – **není totéž co `client_id`** |
| card_holder_name | Jméno držitele karty – volný text, nemusí souhlasit s CORE |
| card_type | Typ karty: `Debit` nebo `Credit` |
| card_status | Stav: `Active`, `Blocked`, `Expired` |
| issue_date | Datum vydání karty |
| expiry_date | Datum expirace karty |

### `bronze.cards_transactions`
Kartové transakce.

| Sloupec | Popis |
|---|---|
| transaction_id | Unikátní identifikátor transakce |
| card_id | Odkaz na kartu |
| transaction_datetime | Datum a čas transakce |
| amount | Částka (záporná u Refund, kladná u Purchase/Withdrawal – výjimky viz DQ) |
| currency | Měna transakce |
| merchant_category | Kategorie obchodníka (může chybět) |
| transaction_type | Typ: `Purchase`, `Withdrawal`, `Refund` |
| country_code | Kód země (ISO 2 znaky) |

---

## Silver Layer – vyčištěná a standardizovaná data

### `silver.core_client_extract`

| Sloupec | Změna oproti Bronze |
|---|---|
| extract_date | Konvertováno na `DATE` |
| phone | Standardizováno na formát `+420XXXXXXXXX` |
| segment | Standardizováno na `Retail` / `Premium` / `Private` |
| birth_date, client_since_date | Konvertováno na `DATE` |
| ostatní | TRIM, stejné hodnoty |

### `silver.core_account`

| Sloupec | Změna oproti Bronze |
|---|---|
| open_date, close_date | Konvertováno na `DATE` |
| ostatní | TRIM |

### `silver.core_account_balance_extract`
Obsahuje pouze řádky, které prošly business rule validací.

| Sloupec | Změna oproti Bronze |
|---|---|
| extract_month | Konvertováno na `DATE` |
| balance | Konvertováno na `DECIMAL(15,2)` |

### `silver.cards_card_master`

| Sloupec | Popis |
|---|---|
| account_resolved_in_core | `1` = account_id existuje v CORE, `0` = orphan karta |
| holder_name_matches_core | `1` = jméno souhlasí, `0` = nesouhlasí, `NULL` = orphan karta |
| issue_date, expiry_date | Konvertováno na `DATE` |

### `silver.cards_transactions`
Obsahuje pouze transakce, které prošly business rule validací.

| Sloupec | Změna oproti Bronze |
|---|---|
| transaction_id | Konvertováno na `BIGINT` |
| transaction_datetime | Konvertováno na `DATETIME2` |
| amount | Konvertováno na `DECIMAL(15,2)` |

### `silver.possible_duplicate_clients`

| Sloupec | Popis |
|---|---|
| duplicate_group_id | Surrogate key (IDENTITY) |
| client_id_1 | První client_id z dvojice |
| client_id_2 | Druhý client_id z dvojice |
| first_name, last_name, birth_date | Základ shody |
| match_reason | Proč byly označeny jako potenciální duplicita |
| resolution_status | `Open` / `Resolved` / `False Positive` |
| created_timestamp | Kdy byl nález zalogován |

### `silver.quarantine_balance`
Řádky porušující business rule (záporný nebo chybějící balance u neúspořicího produktu).

| Sloupec | Popis |
|---|---|
| extract_month, account_id, balance | Raw hodnoty ze zdroje (NVARCHAR) |
| quarantine_reason | Důvod vyřazení |
| quarantine_timestamp | Kdy byl řádek quarantinován |

### `silver.quarantine_transactions`
Řádky porušující business rule (záporná Purchase/Withdrawal, transakce mimo platnost karty).

| Sloupec | Popis |
|---|---|
| transaction_id … country_code | Raw hodnoty ze zdroje (NVARCHAR) |
| quarantine_reason | Důvod vyřazení |
| quarantine_timestamp | Kdy byl řádek quarantinován |

---

## Gold Layer – analytický model (star schema)

### `gold.dim_client` (SCD Type 2)

| Sloupec | Popis |
|---|---|
| client_sk | Surrogate key – unikátní pro každou verzi klienta |
| client_id | Natural key – jeden klient může mít více řádků |
| email, phone, address_city, segment | Sledované atributy – změna spustí novou SCD2 verzi |
| valid_from | Od kdy tato verze platí (první den měsíce extraktu) |
| valid_to | Do kdy platí (`NULL` = aktuální verze) |
| is_current | `1` = aktuální, `0` = historická verze |

### `gold.dim_account`

| Sloupec | Popis |
|---|---|
| account_sk | Surrogate key |
| client_id, product_id | Natural keys pro traceability (bez FK – SCD2 omezení) |
| open_date, close_date | Životní cyklus účtu |
| status, currency | Atributy účtu |

### `gold.dim_card`

| Sloupec | Popis |
|---|---|
| card_sk | Surrogate key |
| account_resolved_in_core | Přeneseno ze Silver – `0` = orphan karta |
| holder_name_matches_core | Přeneseno ze Silver – `0` = neshoda jména |

### `gold.dim_product`
Statická dimenze – 5 produktů, 2 kategorie.

### `gold.dim_date`
Kalendářní dimenze, rozsah 2024-01-01 až 2026-12-31.

| Sloupec | Popis |
|---|---|
| date_sk | Formát `YYYYMMDD` – bez IDENTITY, hodnota = datum |
| is_weekend | `1` = So/Ne |
| is_month_end | `1` = poslední den měsíce |

### `gold.fact_card_transactions`
Grain: jeden řádek = jedna kartová transakce.

| Sloupec | Popis |
|---|---|
| transaction_id | Natural key (degenerovaná dimenze) |
| client_sk | SCD2 verze klienta platná v okamžiku transakce |

### `gold.fact_account_monthly_snapshot`
Grain: jeden řádek = jeden účet × jeden měsíc.

| Sloupec | Popis |
|---|---|
| date_sk + account_sk | Composite PK |
| client_sk | SCD2 verze klienta platná k danému měsíci |
| balance | `NULL` = chybějící extrakt (záměrně nenahrazováno nulou) |
