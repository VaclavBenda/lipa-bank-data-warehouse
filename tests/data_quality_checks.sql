/*
============================================================
    Data Quality Checks
============================================================
Script Purpose:
    This script identifies business rule violations and
    cross-system inconsistencies in the Bronze layer before
    they are handled by the Silver load process.
============================================================
*/

-- Calculate percentage of CARDS account_id values not found in CORE accounts
WITH not_matching_acc_id_cte AS (
SELECT
	cm.card_id,
	cm.cif,
	cm.card_holder_name,
	cm.card_type,
	cm.card_status,
	cm.issue_date,
	cm.[expiry_date],
	cm.account_id AS card_account_id,
	ca.account_id AS matched_account_id,
	ca.client_id,
	ca.product_id,
	ca.open_date,
	ca.close_date,
	ca.[status],
	ca.currency
FROM bronze.cards_card_master AS cm
LEFT JOIN bronze.core_account AS ca
	ON cm.account_id = ca.account_id
),
counting_CTE AS (
SELECT 
	COUNT(*) AS all_rows,
	SUM(CASE WHEN matched_account_id IS NULL THEN 1 ELSE 0 END) AS account_id_nulls_cnt
FROM not_matching_acc_id_cte
)
SELECT
	ROUND(account_id_nulls_cnt / NULLIF(CAST(all_rows AS FLOAT), 0) * 100, 2) AS missing_account_id_pct
FROM counting_CTE;


-- Identify card holder names that do not match the latest CORE client name
WITH rank_cte AS (
	SELECT 
		extract_date,
		client_id,
		CONCAT(first_name, ' ' ,last_name) AS full_name,
		birth_date,
		email,
		phone,
		address_city,
		segment,
		client_since_date,
	ROW_NUMBER() OVER(PARTITION BY client_id ORDER BY extract_date DESC) AS ranking FROM silver.core_client_extract
),
ranking_out_cte AS (
		SELECT 
			extract_date,
			client_id,
			full_name,
			birth_date,
			email,
			phone,
			address_city,
			segment,
			client_since_date
		FROM rank_cte
		WHERE ranking = 1
),
 joining_cte AS (
	SELECT 
		cm.card_id,
		cm.account_id,
		cm.cif,
		cm.card_holder_name,
		cm.card_type,
		cm.card_status,
		cm.issue_date,
		cm.[expiry_date],
		ca.client_id,
		ca.product_id,
		ca.open_date,
		ca.close_date,
		ca.[status],
		ca.currency
	FROM silver.cards_card_master AS cm
	INNER JOIN silver.core_account AS ca
		ON cm.account_id = ca.account_id
 )
SELECT 
	jc.card_id,
	jc.account_id,
	jc.client_id,
	jc.product_id,
	jc.cif,
	jc.card_holder_name,
	jc.card_type,
	jc.card_status,
	jc.issue_date,
	jc.[expiry_date],
	jc.open_date,
	jc.close_date,
	jc.[status],
	jc.currency,
	oc.extract_date,
	oc.full_name,
	oc.birth_date,
	oc.email,
	oc.phone,
	oc.address_city,
	oc.segment,
	oc.client_since_date
FROM joining_cte AS jc
INNER JOIN ranking_out_cte AS oc
	ON jc.client_id = oc.client_id
	AND card_holder_name != full_name

-- Identify invalid transaction amount signs by transaction type
-- Purchase and Withdrawal should be positive; Refund should be negative
SELECT * FROM bronze.cards_transactions
WHERE (transaction_type = 'Purchase' AND TRY_CONVERT(DECIMAL(18,2), amount) < 0)
	OR (transaction_type = 'Withdrawal' AND TRY_CONVERT(DECIMAL(18,2), amount) < 0)
	OR (transaction_type = 'Refund' AND TRY_CONVERT(DECIMAL(18,2), amount) >= 0)
ORDER BY transaction_type

-- Identify transactions outside the card issue/expiry validity window
SELECT * FROM bronze.cards_transactions AS ct
LEFT JOIN bronze.cards_card_master AS cm
	ON ct.card_id = cm.card_id
WHERE TRY_CONVERT(DATE, ct.transaction_datetime) < TRY_CONVERT(DATE, cm.issue_date)
	OR TRY_CONVERT(DATE, ct.transaction_datetime) > TRY_CONVERT(DATE, cm.[expiry_date])

-- Identify accounts where close_date is earlier than open_date
SELECT * FROM bronze.core_account
WHERE TRY_CONVERT(DATE, open_date) > TRY_CONVERT(DATE, close_date)

-- Identify negative or missing balances for non-savings products
SELECT * FROM bronze.core_account_balance_extract AS be
LEFT JOIN bronze.core_account AS ca
	ON be.account_id = ca.account_id
LEFT JOIN bronze.core_product AS cp
	ON ca.product_id = cp.product_id
WHERE cp.product_category != N'Spořicí účet' AND 
(TRY_CONVERT(NUMERIC(18,2),be.balance) < 0 OR NULLIF(TRIM(be.balance),'') IS NULL)


-- Identify active cards linked to closed accounts
SELECT * FROM bronze.core_account AS ca
LEFT JOIN bronze.cards_card_master AS cm
	ON ca.account_id = cm.account_id
WHERE cm.card_status = 'Active' AND ca.[status] = 'Closed'

-- Identify duplicate account_id values in CORE accounts
SELECT
	account_id,
	COUNT(*) AS dups
FROM bronze.core_account
GROUP BY account_id
HAVING COUNT(*) > 1

-- Identify duplicate card_id values in card master
SELECT
	card_id,
	COUNT(*) AS dups
FROM bronze.cards_card_master
GROUP BY card_id
HAVING COUNT(*) > 1

-- Identify duplicate transaction_id values in card transactions
SELECT
	transaction_id,
	COUNT(*) AS dups
FROM bronze.cards_transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1

-- Identify duplicate product_id values in product catalog
SELECT
	product_id,
	COUNT(*) AS dups
FROM bronze.core_product
GROUP BY product_id
HAVING COUNT(*) > 1