/*
============================================================
    Silver Data Quality Validation
============================================================
Script Purpose:
    This script validates the cleaned Silver layer after load.
    It checks whether standardization, type conversion, and
    business rule filtering were applied correctly.
============================================================
*/

-- Validate phone number standardization after Silver load
SELECT *, COUNT(*) AS all_r FROM (
SELECT
	CASE 
		WHEN phone LIKE '+420 [0-9][0-9][0-9] [0-9][0-9][0-9] [0-9][0-9][0-9]' THEN '+420_with_spaces'
		WHEN phone LIKE '+420[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN '+420_no_spaces'
		WHEN phone LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN 'no_spaces'
		WHEN phone LIKE '[0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9]' THEN 'with_dash'
		ELSE 'unknown'
	END AS phone_format
FROM silver.core_client_extract
)t
GROUP BY phone_format;

-- Check whether possible duplicate clients are still present in Silver
SELECT first_name, last_name, birth_date, COUNT(DISTINCT client_id) AS dups FROM silver.core_client_extract
GROUP BY first_name, last_name, birth_date
HAVING COUNT(DISTINCT client_id) > 1;


-- Confirm that invalid transaction amount signs were removed from Silver transactions
SELECT * FROM silver.cards_transactions
WHERE (transaction_type = 'Purchase' AND amount < 0)
	OR (transaction_type = 'Withdrawal' AND amount < 0)
	OR (transaction_type = 'Refund' AND amount >= 0)
ORDER BY transaction_type

-- Confirm that transactions outside card validity were removed from Silver transactions
SELECT * FROM silver.cards_transactions AS ct
LEFT JOIN silver.cards_card_master AS cm
	ON ct.card_id = cm.card_id
WHERE transaction_datetime < issue_date
	OR transaction_datetime > [expiry_date]

-- Confirm that account close_date is not earlier than open_date
SELECT * FROM silver.core_account
WHERE open_date > close_date

-- Confirm that negative or missing balances for non-savings products were removed
SELECT * FROM silver.core_account_balance_extract AS be
LEFT JOIN silver.core_account AS ca
	ON be.account_id = ca.account_id
LEFT JOIN silver.core_product AS cp
	ON ca.product_id = cp.product_id
WHERE cp.product_category != N'Spořicí účet' AND 
	be.balance < 0 OR balance IS NULL