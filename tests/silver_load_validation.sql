/*
============================================================
    Silver Load Validation
============================================================
Script Purpose:
    This script validates the Silver layer after transformation
    by checking row counts across cleaned, quarantined, and
    data quality support tables.

    Run this script after:
    EXEC silver.load_silver;
============================================================
*/

SELECT 'core_client_extract' AS [table], COUNT(*) AS nr_rows FROM silver.core_client_extract 
UNION ALL
SELECT 'core_product', COUNT(*) FROM silver.core_product 
UNION ALL
SELECT 'core_account', COUNT(*) FROM silver.core_account 
UNION ALL
SELECT 'core_account_balance_extract', COUNT(*) FROM silver.core_account_balance_extract 
UNION ALL
SELECT 'cards_card_master', COUNT(*) FROM silver.cards_card_master 
UNION ALL
SELECT 'cards_transactions', COUNT(*) FROM silver.cards_transactions 
UNION ALL
SELECT 'quarantine_balance', COUNT(*) FROM silver.quarantine_balance 
UNION ALL
SELECT 'quarantine_transactions', COUNT(*) FROM silver.quarantine_transactions 
UNION ALL
SELECT 'possible_duplicate_clients', COUNT(*) FROM silver.possible_duplicate_clients;