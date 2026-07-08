/*
============================================================
    Bronze Load Validation
============================================================
Script Purpose:
    This script validates that all Bronze tables were loaded
    from the source CSV files by checking row counts.

    Run this script after:
    EXEC bronze.load_bronze;
============================================================
*/

SELECT 'bronze.cards_card_master' AS [table], COUNT(*) AS nr_rows FROM bronze.cards_card_master
UNION ALL
SELECT 'bronze.cards_transactions' AS [table], COUNT(*) AS nr_rows FROM bronze.cards_transactions
UNION ALL
SELECT 'bronze.core_account' AS [table], COUNT(*) AS nr_rows FROM bronze.core_account
UNION ALL
SELECT 'bronze.core_product' AS [table], COUNT(*) AS nr_rows FROM bronze.core_product
UNION ALL
SELECT 'bronze.core_client_extract' AS [table], COUNT(*) AS nr_rows FROM bronze.core_client_extract
UNION ALL
SELECT 'bronze.core_account_balance_extract' AS [table], COUNT(*) AS nr_rows FROM bronze.core_account_balance_extract