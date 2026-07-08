/*
============================================================
    Source Data Profiling Checks
============================================================
Script Purpose:
    This script profiles raw data in the Bronze layer before
    any cleansing or transformation is applied.

    It is used to understand source data quality issues such as:
    - NULL and blank values
    - inconsistent formats
    - invalid date and numeric conversions
    - duplicate candidates
    - referential gaps between source tables
    - unusual value distributions

    Run this script after:
    EXEC bronze.load_bronze;
============================================================
*/

-- Table: bronze.core_client_extract

-- Check NULL/blank percentage for optional client contact attributes
WITH null_check_cte AS (
SELECT
	COUNT(*) AS all_rows,
	SUM(CASE WHEN NULLIF(TRIM(email),'') IS NULL THEN 1 ELSE 0 END) AS email_null_check,
	SUM(CASE WHEN NULLIF(TRIM(phone),'') IS NULL THEN 1 ELSE 0 END) AS phone_null_check,
	SUM(CASE WHEN NULLIF(TRIM(address_city),'') IS NULL THEN 1 ELSE 0 END) AS address_city_null_check
FROM bronze.core_client_extract
)
SELECT
	ROUND(email_null_check / CAST(NULLIF(all_rows,0) AS FLOAT) * 100, 2) AS email_null_pct,
	ROUND(phone_null_check / CAST(NULLIF(all_rows,0) AS FLOAT) * 100, 2) AS phone_null_pct,
	ROUND(address_city_null_check / CAST(NULLIF(all_rows,0) AS FLOAT) * 100, 2) AS address_city_null_pct
FROM null_check_cte;

-- Profile phone number formats before standardization
WITH phone_number_cte AS (
SELECT
	CASE 
		WHEN phone LIKE '+420 [0-9][0-9][0-9] [0-9][0-9][0-9] [0-9][0-9][0-9]' THEN '+420_with_spaces'
		WHEN phone LIKE '+420[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN '+420_no_spaces'
		WHEN phone LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN 'no_spaces'
		WHEN phone LIKE '[0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9]' THEN 'with_dash'
		ELSE 'unknown'
	END AS phone_format
FROM bronze.core_client_extract
)
SELECT 
	COUNT(*) AS all_rows,
	SUM(CASE phone_format WHEN '+420_with_spaces' THEN 1 ELSE 0 END) AS '420_with_spaces',
	SUM(CASE phone_format WHEN '+420_no_spaces' THEN 1 ELSE 0 END) AS '+420_no_spaces',
	SUM(CASE phone_format WHEN 'no_spaces' THEN 1 ELSE 0 END) AS 'no_spaces',
	SUM(CASE phone_format WHEN 'with_dash' THEN 1 ELSE 0 END) AS 'with_dash',
	SUM(CASE phone_format WHEN 'unknown' THEN 1 ELSE 0 END) AS 'unknown'
FROM phone_number_CTE;

-- Identify invalid email patterns
SELECT * FROM bronze.core_client_extract
WHERE email NOT LIKE '%@%' OR email NOT LIKE '%.%';

-- Identify possible duplicate clients by name and birth date
SELECT first_name, last_name, birth_date, COUNT(DISTINCT client_id) AS dups FROM bronze.core_client_extract
GROUP BY first_name, last_name, birth_date
HAVING COUNT(DISTINCT client_id) > 1;

-- Validate date conversion for client date columns
WITH convert_date_cte AS (
SELECT
	client_id,
	extract_date AS extract_date_raw,
	birth_date AS birth_date_raw,
	client_since_date AS client_since_date_raw,
	TRY_CONVERT(DATE, NULLIF(TRIM(extract_date), '')) AS extract_date,
	TRY_CONVERT(DATE, NULLIF(TRIM(birth_date), '')) AS birth_date,
	TRY_CONVERT(DATE, NULLIF(TRIM(client_since_date), '')) AS client_since_date
FROM bronze.core_client_extract
)
SELECT 
	client_id, 
	extract_date_raw, 
	extract_date, 
	birth_date_raw,
	birth_date,
	client_since_date_raw,
	client_since_date 
FROM convert_date_cte
WHERE (extract_date_raw IS NOT NULL AND extract_date IS NULL)
 OR (client_since_date_raw IS NOT NULL AND client_since_date IS NULL)
 OR (birth_date_raw IS NOT NULL AND birth_date IS NULL);


-- Check whether each client appears in all expected extract dates
SELECT
    client_id,
    COUNT(DISTINCT extract_date) AS extracts_present_in
FROM bronze.core_client_extract
GROUP BY client_id
HAVING COUNT(DISTINCT extract_date) != (SELECT COUNT(DISTINCT extract_date) FROM bronze.core_client_extract);


-- Table: bronze.core_account

-- Validate date conversion for account lifecycle columns
WITH date_cte AS (
	SELECT 
		account_id,
		client_id,
		product_id,
		open_date AS open_date_raw,
		TRY_CONVERT(DATE, NULLIF(TRIM(open_date), '')) AS open_date,
		close_date AS close_date_raw,
		TRY_CONVERT(DATE, NULLIF(TRIM(close_date),'')) AS close_date
	FROM bronze.core_account
)
SELECT 
	account_id,
	client_id,
	product_id,
	open_date AS open_date_raw,
	open_date,
	close_date AS close_date_raw,
	close_date
FROM date_cte
WHERE (open_date_raw IS NOT NULL AND open_date IS NULL) 
 OR (close_date_raw IS NOT NULL AND close_date IS NULL);


-- Profile account status and currency distributions

SELECT [status], COUNT(*) AS total FROM bronze.core_account
GROUP BY [status];

SELECT currency, COUNT(*) AS total FROM bronze.core_account
GROUP BY currency;

-- Identify account records referencing missing client_id values
SELECT 
	client_id
FROM bronze.core_account AS ca
WHERE client_id IS NOT NULL 
	AND NOT EXISTS(SELECT 1 FROM bronze.core_client_extract AS ce WHERE ca.client_id = ce.client_id);

-- Identify account records referencing missing product_id values
SELECT 
	product_id
FROM bronze.core_account AS ca
WHERE product_id IS NOT NULL 
	AND NOT EXISTS (SELECT 1 FROM bronze.core_product AS cp WHERE ca.product_id = cp.product_id);


-- Table: bronze.core_account_balance_extract

-- Check NULL and blank balance percentage
WITH balance_check_cte AS (
SELECT 
	COUNT(*) AS all_rows,
	SUM(CASE WHEN balance IS NULL THEN 1 ELSE 0 END) AS balance_null_check,
	SUM(CASE WHEN TRIM(balance) = '' THEN 1 ELSE 0 END) AS balance_blank_check
FROM bronze.core_account_balance_extract
)
SELECT 
	ROUND((balance_null_check / NULLIF(CAST(all_rows AS FLOAT), 0) * 100), 2) AS null_check_pct,
	ROUND((balance_blank_check / NULLIF(CAST(all_rows AS FLOAT), 0)) * 100, 2) AS blank_check_pct
FROM
balance_check_cte;


-- Identify missing monthly balance records for active accounts
WITH all_months_cte AS (
	SELECT 
		DISTINCT(TRY_CONVERT(DATE, NULLIF(TRIM(extract_month),''))) AS month_date
	FROM bronze.core_account_balance_extract
), 
expected AS (
	SELECT * FROM bronze.core_account AS ca
	CROSS JOIN all_months_cte AS mc
	WHERE TRY_CONVERT(DATE, NULLIF(TRIM(ca.open_date),'')) <= mc.month_date
	 AND (
			NULLIF(TRIM(ca.close_date), '') IS NULL
			OR TRY_CONVERT(DATE, NULLIF(TRIM(ca.close_date),'')) >= mc.month_date
		)
)
SELECT 
	e.account_id,
	e.month_date
FROM expected AS e
LEFT JOIN bronze.core_account_balance_extract AS be
	ON be.account_id = e.account_id
	AND TRY_CONVERT(DATE, NULLIF(TRIM(be.extract_month),'')) = e.month_date
WHERE be.account_id IS NULL
ORDER BY e.account_id, e.month_date



-- Profile minimum and maximum balance values
SELECT
	MIN(TRY_CONVERT(DECIMAL(18,2), NULLIF(TRIM(balance),''))) AS min_balance,
	MAX(TRY_CONVERT(DECIMAL(18,2), NULLIF(TRIM(balance),''))) AS max_balance
FROM
bronze.core_account_balance_extract;


-- Validate numeric conversion for balance
WITH convert_cte AS (
SELECT 
	balance AS balance_raw, 
	TRY_CONVERT(DECIMAL(18,2), NULLIF(TRIM(balance),'')) AS balance
FROM bronze.core_account_balance_extract
)
SELECT 
	balance_raw,
	balance
FROM convert_cte
WHERE balance_raw IS NOT NULL AND balance IS NULL;


-- Table: bronze.cards_card_master

-- Check NULL/blank percentage for card holder name
WITH card_holder_name_cte AS (
SELECT
	COUNT(*) AS all_rows,
	SUM(CASE WHEN NULLIF(TRIM(card_holder_name),'') IS NULL THEN 1 ELSE 0 END) AS card_holder_name_null_check
FROM bronze.cards_card_master
)
SELECT
	ROUND((card_holder_name_null_check / NULLIF(CAST(all_rows AS FLOAT), 0)) * 100, 2) AS card_holder_name_null_pct
FROM card_holder_name_cte;

-- Validate date conversion for card issue and expiry dates
WITH convert_cte AS (
SELECT 
	issue_date AS issue_date_raw,
	TRY_CONVERT(DATE, NULLIF(TRIM(issue_date),'')) AS issue_date,
	[expiry_date] AS expiry_date_raw,
	TRY_CONVERT(DATE, NULLIF(TRIM([expiry_date]), '')) AS [expiry_date]
FROM bronze.cards_card_master
)
SELECT
	issue_date_raw,
	issue_date,
	expiry_date_raw,
	[expiry_date]
FROM convert_cte
WHERE (issue_date_raw IS NOT NULL AND issue_date IS NULL)
 OR (expiry_date_raw IS NOT NULL AND [expiry_date] IS NULL);

-- Profile card type and card status distributions
SELECT 
	card_type,
	COUNT(*) AS total
FROM bronze.cards_card_master
GROUP BY card_type;

SELECT 
	card_status,
	COUNT(*) AS total
FROM bronze.cards_card_master
GROUP BY card_status;


-- Identify cards referencing account_id values missing in CORE
SELECT DISTINCT(account_id) FROM bronze.cards_card_master AS cm
WHERE cm.account_id IS NOT NULL
 AND NOT EXISTS (SELECT 1 FROM bronze.core_account AS ca WHERE cm.account_id = ca.account_id);


-- Table: bronze.cards_transactions

-- Check NULL/blank percentage for merchant category
WITH merchant_category_null_cte AS (
SELECT
	COUNT(*) AS all_rows,
	SUM(CASE WHEN NULLIF(TRIM(merchant_category),'') IS NULL THEN 1 ELSE 0 END) AS merchant_category_null_check
FROM bronze.cards_transactions
)
SELECT
	ROUND((merchant_category_null_check / NULLIF(CAST(all_rows AS FLOAT), 0) * 100), 2) AS merchant_category_null_pct
FROM merchant_category_null_cte;

-- Validate numeric and date conversion for transaction fields
WITH convert_cte AS (
SELECT 
	amount AS amount_raw,
	TRY_CONVERT(DECIMAL(18,2), amount) AS amount,
	transaction_datetime AS transaction_datetime_raw,
	TRY_CONVERT(DATE, transaction_datetime) AS transaction_date
FROM bronze.cards_transactions
)
SELECT
	amount_raw,
	amount,
	transaction_datetime_raw,
	transaction_date
FROM convert_cte
WHERE (amount_raw IS NOT NULL AND amount IS NULL)
 OR (transaction_datetime_raw IS NOT NULL AND transaction_date IS NULL);


-- Profile transaction type, country and currency distributions
SELECT
	transaction_type,
	COUNT(*) AS total
FROM bronze.cards_transactions
GROUP BY transaction_type
ORDER BY total DESC;

SELECT
	country_code,
	COUNT(*) AS total
FROM bronze.cards_transactions
GROUP BY country_code
ORDER BY total DESC;

SELECT
	currency,
	COUNT(*) AS total
FROM bronze.cards_transactions
GROUP BY currency 
ORDER BY total DESC;

-- Profile minimum and maximum amount by transaction type
SELECT
	transaction_type,
	MIN(TRY_CONVERT(NUMERIC(18,2), amount)) AS min_amount,
	MAX(TRY_CONVERT(NUMERIC(18,2), amount)) AS max_amount
FROM bronze.cards_transactions
GROUP BY transaction_type
ORDER BY transaction_type;