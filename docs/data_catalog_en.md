# Data Catalog – Lipa Bank a.s. DWH

Data dictionary for all three layers of the data warehouse.
Purpose: anyone reviewing this project should understand what each table and column contains without reading the SQL code.

---

## Bronze Layer – Raw Source Data

### `bronze.core_client_extract`
Monthly periodic export of clients from the CORE system. One client = multiple rows (one per extract).

| Column | Description |
|---|---|
| extract_date | Date when CORE performed the periodic export |
| client_id | Internal client identifier in CORE (format `C00001`) |
| first_name | First name |
| last_name | Last name |
| birth_date | Date of birth |
| email | Email address (may be missing) |
| phone | Phone number – inconsistent format in source |
| address_city | City of residence |
| segment | Client segment – inconsistent casing in source (Retail/retail/RETAIL…) |
| client_since_date | Date when the client first joined the bank |

### `bronze.core_product`
Static product catalog.

| Column | Description |
|---|---|
| product_id | Product identifier (format `P01`) |
| product_name | Product name |
| product_category | Category: `Běžný účet` (Current Account) or `Spořicí účet` (Savings Account) |

### `bronze.core_account`
Bank accounts belonging to clients.

| Column | Description |
|---|---|
| account_id | Account identifier (format `A000001`) |
| client_id | Reference to client in `core_client_extract` |
| product_id | Reference to product in `core_product` |
| open_date | Date the account was opened |
| close_date | Date the account was closed (empty = still active) |
| status | Status: `Active`, `Closed`, `Dormant` |
| currency | Currency: `CZK` or `EUR` |

### `bronze.core_account_balance_extract`
Monthly balance extract per account. Grain: one row = one account × one month.

| Column | Description |
|---|---|
| extract_month | First day of the month covered by the extract |
| account_id | Reference to account |
| balance | Account balance (may be blank or negative – see DQ checks) |

### `bronze.cards_card_master`
Payment cards from the CARDS system (different vendor than CORE).

| Column | Description |
|---|---|
| card_id | Card identifier (format `K000001`) |
| account_id | Reference to account in CORE – **may not exist** (orphan cards) |
| cif | CARDS system's own client reference – **not the same as `client_id`** |
| card_holder_name | Card holder name – free text, may not match CORE |
| card_type | Card type: `Debit` or `Credit` |
| card_status | Status: `Active`, `Blocked`, `Expired` |
| issue_date | Date the card was issued |
| expiry_date | Card expiry date |

### `bronze.cards_transactions`
Card transactions.

| Column | Description |
|---|---|
| transaction_id | Unique transaction identifier |
| card_id | Reference to card |
| transaction_datetime | Date and time of transaction |
| amount | Amount (negative for Refund, positive for Purchase/Withdrawal – exceptions in DQ checks) |
| currency | Transaction currency |
| merchant_category | Merchant category (may be missing) |
| transaction_type | Type: `Purchase`, `Withdrawal`, `Refund` |
| country_code | Country code (ISO 2 characters) |

---

## Silver Layer – Cleansed & Standardized Data

### `silver.core_client_extract`

| Column | Change vs. Bronze |
|---|---|
| extract_date | Converted to `DATE` |
| phone | Standardized to format `+420XXXXXXXXX` |
| segment | Standardized to `Retail` / `Premium` / `Private` |
| birth_date, client_since_date | Converted to `DATE` |
| other | TRIM applied, same values |

### `silver.core_account`

| Column | Change vs. Bronze |
|---|---|
| open_date, close_date | Converted to `DATE` |
| other | TRIM applied |

### `silver.core_account_balance_extract`
Contains only rows that passed business rule validation (see quarantine).

| Column | Change vs. Bronze |
|---|---|
| extract_month | Converted to `DATE` |
| balance | Converted to `DECIMAL(15,2)` |

### `silver.cards_card_master`

| Column | Description |
|---|---|
| account_resolved_in_core | `1` = account_id found in CORE, `0` = orphan card |
| holder_name_matches_core | `1` = name matches CORE, `0` = mismatch, `NULL` = orphan card (cannot evaluate) |
| issue_date, expiry_date | Converted to `DATE` |

### `silver.cards_transactions`
Contains only transactions that passed business rule validation.

| Column | Change vs. Bronze |
|---|---|
| transaction_id | Converted to `BIGINT` |
| transaction_datetime | Converted to `DATETIME2` |
| amount | Converted to `DECIMAL(15,2)` |

### `silver.possible_duplicate_clients`
Log table for potential duplicate clients – requires a business decision.

| Column | Description |
|---|---|
| duplicate_group_id | Surrogate key (IDENTITY) |
| client_id_1 | First client_id of the pair |
| client_id_2 | Second client_id of the pair |
| first_name, last_name, birth_date | Basis of the match |
| match_reason | Why these records were flagged as potential duplicates |
| resolution_status | `Open` / `Resolved` / `False Positive` |
| created_timestamp | When the finding was logged |

### `silver.quarantine_balance`
Rows from `core_account_balance_extract` that violated the business rule (negative or missing balance on a non-savings product).

| Column | Description |
|---|---|
| extract_month, account_id, balance | Raw values from source (NVARCHAR) |
| quarantine_reason | Reason for exclusion |
| quarantine_timestamp | When the row was quarantined |

### `silver.quarantine_transactions`
Rows from `cards_transactions` that violated business rules.

| Column | Description |
|---|---|
| transaction_id … country_code | Raw values from source (NVARCHAR) |
| quarantine_reason | `Negative numbers in Purchase/Withdrawal and Positive in Refund` or `Expired Credit Card` |
| quarantine_timestamp | When the row was quarantined |

---

## Gold Layer – Analytical Model (Star Schema)

### `gold.dim_client` (SCD Type 2)

| Column | Description |
|---|---|
| client_sk | Surrogate key – unique per client version. `-1` = Unknown member |
| client_id | Natural key – one client may have multiple rows |
| email, phone, address_city, segment | Tracked attributes – a change triggers a new SCD2 version |
| client_since_date | Date of first relationship with the bank |
| valid_from | Start date of this version (first day of the extract month) |
| valid_to | End date of this version (`NULL` = current version) |
| is_current | `1` = current version, `0` = historical version |

### `gold.dim_account`

| Column | Description |
|---|---|
| account_sk | Surrogate key. `-1` = Unknown member |
| client_id, product_id | Natural keys retained for traceability (no FK – SCD2 limitation) |
| open_date, close_date | Account lifecycle dates |
| status, currency | Account attributes |

### `gold.dim_card`

| Column | Description |
|---|---|
| card_sk | Surrogate key. `-1` = Unknown member |
| account_resolved_in_core | Carried from Silver – `0` = orphan card |
| holder_name_matches_core | Carried from Silver – `0` = name mismatch, `NULL` = orphan |

### `gold.dim_product`
Static dimension – 5 products, 2 categories. `-1` = Unknown member.

### `gold.dim_date`
Calendar dimension covering 2024-01-01 to 2026-12-31 (1 096 days).

| Column | Description |
|---|---|
| date_sk | Format `YYYYMMDD` – no IDENTITY, value equals the date |
| is_weekend | `1` = Saturday or Sunday |
| is_month_end | `1` = last day of the month |

### `gold.fact_card_transactions`
Grain: one row = one card transaction.

| Column | Description |
|---|---|
| transaction_id | Natural key (degenerate dimension) |
| client_sk | SCD2 version of the client valid **at the time of the transaction** |
| card_sk, account_sk | `-1` if orphan reference (card or account not resolvable in CORE) |

### `gold.fact_account_monthly_snapshot`
Grain: one row = one account × one month.

| Column | Description |
|---|---|
| date_sk + account_sk | Composite PK |
| client_sk | SCD2 version of the client valid for the given month |
| balance | `NULL` = missing extract (intentionally not replaced with zero) |
