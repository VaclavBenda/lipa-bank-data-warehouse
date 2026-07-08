/*
==============================================================
	Stored Procedure: Load Gold Layer (Silver -> Gold)
==============================================================
Script Purpose:
	This stored procedure loads data into the 'gold' schema from the 'silver' schema.
    It performs the following actions:
    - Deletes the gold tables before loading data
    - Loads dimension tables from cleansed silver tables
    - Applies SCD Type2 logic for the client dimension
    - Loads fact tables using surrogate keys from gold dimensions.

Parameters:
	None.
	This stored procedure does not accept any parameters or return any values.

Usage Example:
	EXEC gold.load_gold;
==============================================================
*/

CREATE OR ALTER PROCEDURE gold.load_gold AS
BEGIN
    BEGIN TRY
        DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
            SET @batch_start_time = GETDATE();
		    PRINT '==============================================';
		    PRINT			'Loading Gold Layer';
		    PRINT '==============================================';

		    SET @start_time = GETDATE();
		    PRINT '>> Deleting Gold tables';

            DELETE FROM gold.fact_card_transactions;
            DELETE FROM gold.fact_account_monthly_snapshot;
            DELETE FROM gold.dim_card;
            DELETE FROM gold.dim_account;
            DELETE FROM gold.dim_product;
            DELETE FROM gold.dim_client;
            DELETE FROM gold.dim_date;

            DBCC CHECKIDENT ('gold.dim_client', RESEED, 0);
            DBCC CHECKIDENT ('gold.dim_account', RESEED, 0);
            DBCC CHECKIDENT ('gold.dim_card', RESEED, 0);
            DBCC CHECKIDENT ('gold.dim_product', RESEED, 0);

        SET @end_time = GETDATE();
	    PRINT '>> Delete Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	    PRINT '--------------------------------';

        SET @start_time = GETDATE();
	    PRINT '>> Inserting Table: gold.dim_date';
        ;WITH date_CTE AS (
	        SELECT CAST('2024-01-01' AS DATE) AS full_date
	        UNION ALL
	        SELECT DATEADD(DAY, 1, full_date)
	        FROM date_cte
	        WHERE full_date < '2026-12-31'
        )
        INSERT INTO gold.dim_date(
	        date_sk,
	        full_date,
	        [year],
	        [quarter],
	        month_number,
	        month_name,
	        day_of_month,
	        day_of_the_week,
	        is_weekend,
	        is_month_end
        )
        SELECT
	        CONVERT(INT, FORMAT(full_date, 'yyyyMMdd')) AS date_sk,
	        full_date,
	        YEAR(full_date) AS [year],
	        DATEPART(QUARTER, full_date) AS [quarter],
	        MONTH(full_date) AS month_number,
	        DATENAME(MONTH, full_date) AS month_name,
	        DAY(full_date) AS day_of_month,
	        DATENAME(WEEKDAY, full_date) AS day_of_the_week,
	        CASE
		        WHEN DATENAME(WEEKDAY, full_date) IN ('Saturday', 'Sunday') THEN 1
		        ELSE 0
	        END AS is_weekend,
	        CASE 
		        WHEN EOMONTH(full_date) = full_date THEN 1
		        ELSE 0
	        END AS is_month_end
        FROM date_CTE
        OPTION (MAXRECURSION 0);
        SET @end_time = GETDATE();
	    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	    PRINT '--------------------------------';

        SET @start_time = GETDATE();
	    PRINT '>> Inserting Table: gold.dim_client';
        SET IDENTITY_INSERT gold.dim_client ON;
        INSERT INTO gold.dim_client (
            client_sk,
            client_id,
            first_name,
            last_name,
            birth_date,
            email,
            phone,
            address_city,
            segment,
            client_since_date,
            valid_from,
            valid_to,
            is_current
        )
        VALUES (
            -1,
            'UNKNOWN',
            N'Unknown',
            N'Unknown',
            NULL,
            NULL,
            NULL,
            NULL,
            'Unknown',
            NULL,
            '1900-01-01',
            NULL,
            1
        );
        SET IDENTITY_INSERT gold.dim_client OFF;

        ;WITH lag_cte AS (
            SELECT
                extract_date,
                client_id,
                first_name,
                last_name,
                birth_date,
                email,
                phone,
                address_city,
                segment,
                client_since_date,

                LAG(segment) OVER (PARTITION BY client_id ORDER BY extract_date) AS prev_segment,
                LAG(phone) OVER(PARTITION BY client_id ORDER BY extract_date) AS prev_phone,
                LAG(address_city) OVER(PARTITION BY client_id ORDER BY extract_date) AS prev_address_city,
                LAG(email) OVER(PARTITION BY client_id ORDER BY extract_date) AS prev_email

            FROM silver.core_client_extract
        ),
        version_start_cte AS (
            SELECT
                extract_date,
                client_id,
                first_name,
                last_name,
                birth_date,
                email,
                phone,
                address_city,
                segment,
                client_since_date
            FROM lag_cte
            WHERE prev_segment IS NULL
               OR segment != prev_segment
               OR COALESCE(phone,'') != COALESCE(prev_phone,'')
               OR address_city != prev_address_city
               OR COALESCE(email,'') != COALESCE(prev_email,'')
        ),
        client_cte AS (
            SELECT
                extract_date,
                client_id,
                first_name,
                last_name,
                birth_date,
                email,
                phone,
                address_city,
                segment,
                client_since_date,

                LEAD(extract_date) OVER (
                    PARTITION BY client_id
                    ORDER BY extract_date
                ) AS next_version_date

            FROM version_start_cte
        )
        INSERT INTO gold.dim_client(
            client_id,
            first_name,
            last_name,
            birth_date,
            email,
            phone,
            address_city,
            segment,
            client_since_date,
            valid_from,
            valid_to,
            is_current
        )
        SELECT
            client_id,
            first_name,
            last_name,
            birth_date,
            email,
            phone,
            address_city,
            segment,
            client_since_date,
            DATEADD(DAY,1, EOMONTH(extract_date, -1)) AS valid_from,
            CASE
                WHEN next_version_date IS NULL THEN NULL
                ELSE EOMONTH(next_version_date, -1)
            END AS valid_to,
            CASE
                WHEN next_version_date IS NULL THEN 1
                ELSE 0
            END AS is_current
        FROM client_cte;
        SET @end_time = GETDATE();
	    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	    PRINT '--------------------------------';

        SET @start_time = GETDATE();
	    PRINT '>> Inserting Table: gold.dim_product';

        SET IDENTITY_INSERT gold.dim_product ON;
        INSERT INTO gold.dim_product (
            product_sk,
            product_id,
            product_name,
            product_category
        )
        VALUES (
            -1,
            'UNKNOWN',
            'Unknown',
            'Unknown'
        );
        SET IDENTITY_INSERT gold.dim_product OFF;

        INSERT INTO gold.dim_product(
            product_id,
            product_name,
            product_category
        )
        SELECT
            product_id,
            product_name,
            product_category
        FROM silver.core_product;
        SET @end_time = GETDATE();
	    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	    PRINT '--------------------------------';

        SET @start_time = GETDATE();
	    PRINT '>> Inserting Table: gold.dim_account';
        SET IDENTITY_INSERT gold.dim_account ON;
        INSERT INTO gold.dim_account (
            account_sk,
            account_id,
            client_id,
            product_id,
            open_date,
            close_date,
            [status],
            currency
        )
        VALUES (
            -1,
            'UNKNOWN',
            'UNKNOWN',
            'UNKNOWN',
            '1900-01-01',
            NULL,
            'Unknown',
            'UNK'
        );
        SET IDENTITY_INSERT gold.dim_account OFF;

        INSERT INTO gold.dim_account(
            account_id,
            client_id,
            product_id,
            open_date,
            close_date,
            [status],
            currency
        )
        SELECT
            account_id,
            client_id,
            product_id,
            open_date,
            close_date,
            [status],
            currency
        FROM silver.core_account;
        SET @end_time = GETDATE();
	    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	    PRINT '--------------------------------';

        SET @start_time = GETDATE();
	    PRINT '>> Inserting Table: gold.dim_card';
        SET IDENTITY_INSERT gold.dim_card ON;
        INSERT INTO gold.dim_card (
            card_sk,
            card_id,
            account_id,
            cif,
            card_holder_name,
            card_type,
            card_status,
            issue_date,
            [expiry_date],
            account_resolved_in_core,
            holder_name_matches_core
        )
        VALUES (
            -1,
            'UNKNOWN',
            'UNKNOWN',
            'UNKNOWN',
            N'Unknown',
            'Unknown',
            'Unknown',
            '1900-01-01',
            '9999-12-31',
            0,
            NULL
        );
        SET IDENTITY_INSERT gold.dim_card OFF;

        INSERT INTO gold.dim_card(
            card_id,
            account_id,
            cif,
            card_holder_name,
            card_type,
            card_status,
            issue_date,
            [expiry_date],
            account_resolved_in_core,
            holder_name_matches_core
        )
        SELECT
            card_id,
            account_id,
            cif,
            card_holder_name,
            card_type,
            card_status,
            issue_date,
            [expiry_date],
            account_resolved_in_core,
            holder_name_matches_core
        FROM silver.cards_card_master;
        SET @end_time = GETDATE();
	    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	    PRINT '--------------------------------';

        SET @start_time = GETDATE();
	    PRINT '>> Inserting Table: gold.fact_card_transactions';
        INSERT INTO gold.fact_card_transactions(
            transaction_id,
	        date_sk,
	        card_sk,
	        account_sk,
	        client_sk,
	        amount,
	        currency,
	        merchant_category,
	        transaction_type,
	        country_code
        )
        SELECT 
            ct.transaction_id,
            dd.date_sk,
            COALESCE(dc.card_sk, -1) AS card_sk,
            COALESCE(da.account_sk, -1) AS account_sk,
            COALESCE(dl.client_sk, -1) AS client_sk,
            ct.amount,
            ct.currency,
            ct.merchant_category,
            ct.transaction_type,
            ct.country_code
        FROM silver.cards_transactions AS ct
        LEFT JOIN gold.dim_card AS dc
            ON ct.card_id = dc.card_id
        LEFT JOIN gold.dim_account AS da
            ON dc.account_id = da.account_id
        LEFT JOIN gold.dim_client AS dl
            ON dl.client_id = da.client_id
            AND CAST(ct.transaction_datetime AS DATE) >= dl.valid_from
            AND (dl.valid_to IS NULL OR CAST(ct.transaction_datetime AS DATE) <= dl.valid_to)
        INNER JOIN gold.dim_date AS dd
            ON dd.full_date = CAST(ct.transaction_datetime AS DATE);
        SET @end_time = GETDATE();
	    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	    PRINT '--------------------------------';

        SET @start_time = GETDATE();
	    PRINT '>> Inserting Table: gold.fact_account_monthly_snapshot';
        INSERT INTO gold.fact_account_monthly_snapshot(
            date_sk,
            account_sk,
            client_sk,
            product_sk,
            balance
        )
        SELECT 
            dd.date_sk,
            COALESCE(da.account_sk, -1) AS account_sk,
            COALESCE(dl.client_sk, -1) AS client_sk,
            COALESCE(dp.product_sk, -1) AS product_sk,
            be.balance
        FROM silver.core_account_balance_extract AS be
        LEFT JOIN gold.dim_account AS da
            ON be.account_id = da.account_id
        LEFT JOIN gold.dim_client AS dl
            ON da.client_id = dl.client_id
            AND be.extract_month >= dl.valid_from
            AND (dl.valid_to IS NULL OR be.extract_month <= dl.valid_to)
        LEFT JOIN gold.dim_product AS dp
            ON dp.product_id = da.product_id
        INNER JOIN gold.dim_date AS dd
            ON dd.full_date = be.extract_month;
        SET @end_time = GETDATE();
	    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	    PRINT '--------------------------------';

        SET @batch_end_time = GETDATE();
	    PRINT '==============================================';
	    PRINT 'Loading Gold Layer is Completed';
	    PRINT '>> Total Load Duration: ' + CAST(DATEDIFF(SECOND,@batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
	    PRINT '==============================================';

    END TRY
    BEGIN CATCH
    	PRINT '==============================================';
		PRINT 'ERROR OCCURRED DURING LOADING GOLD LAYER';
		PRINT 'ERROR MESSAGE ' + ERROR_MESSAGE();
		PRINT 'ERROR NUMBER ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'ERROR STATE ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '==============================================';
    END CATCH
END

