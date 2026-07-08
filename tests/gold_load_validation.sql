/*
============================================================
    Gold Load Validation
============================================================
Script Purpose:
    This script validates the Gold layer by checking row counts
    for all dimension and fact tables in the analytical model.

    Run this script after:
    EXEC gold.load_gold;
============================================================
*/

SELECT 'gold.dim_date' AS [table], COUNT(*) AS nr_rows FROM gold.dim_date
UNION ALL
SELECT 'gold.dim_client', COUNT(*) FROM gold.dim_client
UNION ALL
SELECT 'gold.dim_product', COUNT(*) FROM gold.dim_product
UNION ALL
SELECT 'gold.dim_account', COUNT(*) FROM gold.dim_account
UNION ALL
SELECT 'gold.dim_card', COUNT(*) FROM gold.dim_card
UNION ALL
SELECT 'gold.fact_card_transactions', COUNT(*) FROM gold.fact_card_transactions
UNION ALL
SELECT 'gold.fact_account_monthly_snapshot', COUNT(*) FROM gold.fact_account_monthly_snapshot