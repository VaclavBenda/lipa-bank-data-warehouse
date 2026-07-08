/*
==============================================================
	Stored Procedure: Load Silver Layer (Bronze -> Silver)
==============================================================
Script Purpose:
	This stored procedure performs the ETL (Extract, Transform, Load) process to
	populate the 'silver' schema tables from the 'bronze' schema.
	
	It performs the following actions:
	- Delete Silver tables
	- Inserts transformed and cleansed data from Bronze into Silver tables.

Parameters:
	None.
	This stored procedure does not accept any parameters or return any values.

Usage Example:
	EXEC silver.load_silver;
==============================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS 
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '==============================================';
		PRINT			'Loading Silver Layer';
		PRINT '==============================================';

		SET @start_time = GETDATE();
		PRINT '>> Deleting Silver tables';

		DELETE FROM silver.cards_transactions;
		DELETE FROM silver.core_account_balance_extract;
		DELETE FROM silver.core_account;
		DELETE FROM silver.core_product;
		DELETE FROM silver.cards_card_master;
		DELETE FROM silver.core_client_extract;

		DELETE FROM silver.quarantine_transactions;
		DELETE FROM silver.quarantine_balance;
		DELETE FROM silver.possible_duplicate_clients;

		DBCC CHECKIDENT ('silver.possible_duplicate_clients', RESEED, 0);

		SET @end_time = GETDATE();
		PRINT '>> Delete Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '--------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Inserting Table: silver.core_client_extract';
		INSERT INTO silver.core_client_extract(
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
		)
		SELECT 
			TRY_CONVERT(DATE, NULLIF(TRIM(extract_date),'')) AS extract_date,
			TRIM(client_id) AS client_id,
			TRIM(first_name) AS first_name,
			TRIM(last_name) AS last_name,
			TRY_CONVERT(DATE, NULLIF(TRIM(birth_date),'')) AS birth_date,
			TRIM(email) AS email,
			CASE
				WHEN phone LIKE '+420 [0-9][0-9][0-9] [0-9][0-9][0-9] [0-9][0-9][0-9]' THEN REPLACE(phone, ' ', '')
				WHEN phone LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN '+420'+phone
				WHEN phone LIKE '[0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9]' THEN REPLACE('+420'+phone, '-', '')
				ELSE phone
			END AS phone,
			TRIM(address_city) AS address_city,
			CASE UPPER(TRIM(segment))
				WHEN 'PREMIUM' THEN 'Premium'
				WHEN 'PRIVATE' THEN 'Private'
				WHEN 'RETAIL' THEN 'Retail'
			END segment,
			TRY_CONVERT(DATE, NULLIF(TRIM(client_since_date),'')) AS client_since_date
		FROM bronze.core_client_extract;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '--------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Inserting Table: silver.core_product';
		INSERT INTO silver.core_product (
			product_id,
			product_name,
			product_category
		)
		SELECT 
			TRIM(product_id) AS product_id,
			TRIM(product_name) AS product_name,
			CASE 
				WHEN TRIM(product_category) = N'Bežný úcet' THEN N'Běžný účet'
				WHEN TRIM(product_category) = N'Sporicí úcet' THEN N'Spořicí účet'
				ELSE TRIM(product_category)
			END AS product_category
		FROM bronze.core_product;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '--------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Inserting Table: silver.core_account';
		INSERT INTO silver.core_account (
			account_id, 
			client_id,
			product_id,
			open_date,
			close_date,
			[status],
			currency
		)
		SELECT 
			TRIM(account_id) AS account_id,
			TRIM(client_id) AS client_id,
			TRIM(product_id) AS product_id,
			TRY_CONVERT(DATE, NULLIF(TRIM(open_date),'')) AS open_date,
			TRY_CONVERT(DATE, NULLIF(TRIM(close_date), '')) AS close_date,
			TRIM([status]) AS [status],
			TRIM(currency) AS currency
		FROM bronze.core_account;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '--------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Inserting Table: silver.core_account_balance_extract';
		INSERT INTO silver.core_account_balance_extract(
			extract_month,
			account_id,
			balance
		)
		SELECT 
			TRY_CONVERT(DATE, NULLIF(TRIM(be.extract_month),'')) AS extract_month,
			TRIM(be.account_id) AS account_id,
			TRY_CONVERT(DECIMAL(15,2), be.balance) AS balance
		FROM bronze.core_account_balance_extract AS be
		LEFT JOIN silver.core_account AS ca
			ON TRIM(be.account_id) = ca.account_id
		LEFT JOIN silver.core_product AS cp
			ON ca.product_id = cp.product_id
		WHERE (cp.product_category = N'Běžný účet' AND TRY_CONVERT(NUMERIC(18,2), balance) >= 0 AND NULLIF(TRIM(be.balance),'') IS NOT NULL) 
			OR (cp.product_category = N'Spořicí účet' AND (TRY_CONVERT(NUMERIC(18,2), balance) > 0 OR NULLIF(TRIM(be.balance),'') IS NULL))
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '--------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Inserting Table: silver.quarantine_balance';
		INSERT INTO silver.quarantine_balance(
			extract_month,
			account_id,
			balance,
			quarantine_reason,
			quarantine_timestamp
		)
		SELECT 
			TRIM(be.extract_month) AS extract_month,
			TRIM(be.account_id) AS account_id,
			TRIM(be.balance) AS balance,
			'Negative Balance' AS quarantine_reason,
			GETDATE() AS quarantine_timestamp
		FROM bronze.core_account_balance_extract AS be
		LEFT JOIN silver.core_account AS ca
			ON TRIM(be.account_id) = ca.account_id
		LEFT JOIN silver.core_product AS cp
			ON ca.product_id = cp.product_id
		WHERE cp.product_category = N'Běžný účet' AND (TRY_CONVERT(NUMERIC(18,2), balance) < 0 OR NULLIF(TRIM(balance),'') IS NULL)
			OR cp.product_category = N'Spořicí účet' AND (TRY_CONVERT(NUMERIC(18,2), balance) < 0 AND NULLIF(TRIM(balance),'') IS NOT NULL);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '--------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Inserting Table: silver.cards_card_master';
		
		;WITH rank_cte AS (
			SELECT 
				extract_date,
				client_id,
				CONCAT(TRIM(first_name), ' ', TRIM(last_name)) AS full_name,
				birth_date,
				email,
				phone,
				address_city,
				segment,
				client_since_date,
				ROW_NUMBER() OVER (
					PARTITION BY client_id 
					ORDER BY TRY_CONVERT(DATE, NULLIF(TRIM(extract_date), ''), 23) DESC
				) AS ranking
			FROM bronze.core_client_extract
		),
		rank_1_cte AS (
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
		)
		INSERT INTO silver.cards_card_master (
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
			TRIM(cm.card_id) AS card_id,
			TRIM(cm.account_id) AS account_id,
			TRIM(cm.cif) AS cif,
			TRIM(cm.card_holder_name) AS card_holder_name,
			TRIM(cm.card_type) AS card_type,
			TRIM(cm.card_status) AS card_status,
			TRY_CONVERT(DATE, NULLIF(TRIM(cm.issue_date), ''), 23) AS issue_date,
			TRY_CONVERT(DATE, NULLIF(TRIM(cm.[expiry_date]), ''), 23) AS [expiry_date],
			CASE 
				WHEN ca.account_id IS NOT NULL THEN 1
				ELSE 0 
			END AS account_resolved_in_core,
			CASE
				WHEN ca.client_id IS NULL THEN NULL
				WHEN LOWER(TRIM(rc.full_name)) = LOWER(TRIM(cm.card_holder_name)) THEN 1
				ELSE 0
			END AS holder_name_matches_core
		FROM bronze.cards_card_master AS cm
		LEFT JOIN bronze.core_account AS ca
			ON TRIM(cm.account_id) = TRIM(ca.account_id)
		LEFT JOIN rank_1_cte AS rc
			ON TRIM(rc.client_id) = TRIM(ca.client_id);
	SET @end_time = GETDATE();
	PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	PRINT '--------------------------------';

	SET @start_time = GETDATE();
	PRINT '>> Inserting Table: silver.cards_transactions';

	INSERT INTO silver.cards_transactions(
		transaction_id,
		card_id,
		transaction_datetime,
		amount,
		currency,
		merchant_category,
		transaction_type,
		country_code
	)
	SELECT
		TRY_CONVERT(BIGINT, transaction_id) AS transaction_id,
		TRIM(ct.card_id) AS card_id,
		TRY_CONVERT(DATETIME2, transaction_datetime) AS transaction_datetime,
		TRY_CONVERT(DECIMAL(15,2), amount) AS amount,
		TRIM(currency) AS currency,
		TRIM(merchant_category) AS merchant_category,
		TRIM(transaction_type) AS transaction_type,
		TRIM(country_code) AS country_code
	FROM bronze.cards_transactions AS ct
	LEFT JOIN bronze.cards_card_master AS cm
		ON ct.card_id = cm.card_id
	WHERE TRY_CONVERT(DATE, ct.transaction_datetime) >= TRY_CONVERT(DATE, cm.issue_date)
		AND (TRY_CONVERT(DATE, ct.transaction_datetime) <= TRY_CONVERT(DATE, cm.[expiry_date]))
		AND ((transaction_type = 'Purchase' AND TRY_CONVERT(DECIMAL(18,2), amount) >= 0)
		OR (transaction_type = 'Withdrawal' AND TRY_CONVERT(DECIMAL(18,2), amount) >= 0)
		OR (transaction_type = 'Refund' AND TRY_CONVERT(DECIMAL(18,2), amount) <= 0));
	SET @end_time = GETDATE();
	PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	PRINT '--------------------------------';

	PRINT '>> Inserting Table: silver.quarantine_transactions';
	INSERT INTO silver.quarantine_transactions(
		transaction_id,
		card_id,
		transaction_datetime,
		amount,
		currency,
		merchant_category,
		transaction_type,
		country_code,
		quarantine_reason,
		quarantine_timestamp
	)
	SELECT 
		TRIM(transaction_id) AS transaction_id,
		TRIM(card_id) AS card_id,
		TRIM(transaction_datetime) AS transaction_datetime,
		TRIM(amount) AS amount,
		TRIM(currency) AS currency,
		TRIM(merchant_category) AS merchant_category,
		TRIM(transaction_type) AS transaction_type,
		TRIM(country_code) AS country_code,
		'Negative numbers in Purchase/Withdrawal and Positive in Refund' AS quarantine_reason,
		GETDATE() AS quarantine_timestamp
	FROM bronze.cards_transactions
	WHERE (transaction_type = 'Purchase' AND TRY_CONVERT(DECIMAL(18,2), amount) < 0)
		OR (transaction_type = 'Withdrawal' AND TRY_CONVERT(DECIMAL(18,2), amount) < 0)
		OR (transaction_type = 'Refund' AND TRY_CONVERT(DECIMAL(18,2), amount) >= 0);

	SET @start_time = GETDATE();
	PRINT '>> Inserting Table: silver.quarantine_transactions';
	INSERT INTO silver.quarantine_transactions(
		transaction_id,
		card_id,
		transaction_datetime,
		amount,
		currency,
		merchant_category,
		transaction_type,
		country_code,
		quarantine_reason,
		quarantine_timestamp
	)
	SELECT 	
		TRIM(ct.transaction_id) AS transaction_id,
		TRIM(ct.card_id) AS card_id,
		TRIM(ct.transaction_datetime) AS transaction_datetime,
		TRIM(ct.amount) AS amount,
		TRIM(ct.currency) AS currency,
		TRIM(ct.merchant_category) AS merchant_category,
		TRIM(ct.transaction_type) AS transaction_type,
		TRIM(ct.country_code) AS country_code,
		'Expired Credit Card' AS quarantine_reason,
		GETDATE() AS quarantine_timestamp 
	FROM bronze.cards_transactions AS ct
	LEFT JOIN bronze.cards_card_master AS cm
		ON ct.card_id = cm.card_id
	WHERE TRY_CONVERT(DATE, ct.transaction_datetime) < TRY_CONVERT(DATE, cm.issue_date)
		OR TRY_CONVERT(DATE, ct.transaction_datetime) > TRY_CONVERT(DATE, cm.[expiry_date])
	SET @end_time = GETDATE();
	PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	PRINT '--------------------------------';

	SET @start_time = GETDATE();
	PRINT '>> Inserting Table: possible_duplicate_clients';
	;WITH duplicate_CTE AS (
	SELECT 
		ce1.client_id AS client_id_1, 
		ce2.client_id AS client_id_2, 
		ce1.first_name, 
		ce1.last_name, 
		ce1.birth_date,
		ROW_NUMBER() OVER(PARTITION BY ce1.first_name, ce1.last_name, ce1.birth_date ORDER BY ce1.extract_date DESC) AS ranking
	FROM bronze.core_client_extract AS ce1
	INNER JOIN bronze.core_client_extract AS ce2
		ON ce1.first_name = ce2.first_name
		AND ce1.last_name = ce2.last_name
		AND ce1.birth_date = ce2.birth_date
		AND ce1.client_id != ce2.client_id
		AND ce1.client_id < ce2.client_id
	), rank_1_cte AS (
	SELECT 
		client_id_1,
		client_id_2,
		first_name,
		last_name,
		birth_date,
		'Matching first_name, last_name and birth_date' AS match_reason,
		'Open' AS resolution_status,
		GETDATE() AS created_timestamp
	FROM duplicate_CTE
	WHERE ranking = 1
	)
	INSERT INTO silver.possible_duplicate_clients(
		client_id_1,
		client_id_2,
		first_name,
		last_name,
		birth_date,
		match_reason,
		resolution_status,
		created_timestamp
	)
	SELECT
		client_id_1,
		client_id_2,
		first_name,
		last_name,
		birth_date,
		match_reason,
		resolution_status,
		created_timestamp 
	FROM rank_1_cte;
	SET @end_time = GETDATE();
	PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	PRINT '--------------------------------';

	SET @batch_end_time = GETDATE();
	PRINT '==============================================';
	PRINT 'Loading Silver Layer is Completed';
	PRINT '>> Total Load Duration: ' + CAST(DATEDIFF(SECOND,@batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
	PRINT '==============================================';

	END TRY
	BEGIN CATCH
		PRINT '==============================================';
		PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';
		PRINT 'ERROR MESSAGE ' + ERROR_MESSAGE();
		PRINT 'ERROR NUMBER ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'ERROR STATE ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '==============================================';
	END CATCH
END
