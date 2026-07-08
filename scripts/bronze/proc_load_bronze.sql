/*
============================================================
   Stored Procedure: Load Bronze Layer (Source -> Bronze)
============================================================
Script Purpose:
	This stored procedure loads data into the 'bronze' schema from external CSV files.
	It performs the following actions:
	- Truncates the bronze tables before loading data
	- Uses the `BULK INSERT` command to load data from csv files to bronze tables.

Parameters:
	None.
	This stored procedure does not accept any parameters or return any values.

Usage Example:
	EXEC bronze.load_bronze;
============================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '==============================================';
		PRINT			'Loading Bronze Layer';
		PRINT '==============================================';

		PRINT '----------------------------------------------';
		PRINT			'Loading cards Tables';
		PRINT '----------------------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.cards_card_master';
		TRUNCATE TABLE bronze.cards_card_master;

		PRINT '>> Inserting Data Into: bronze.cards_card_master';
		BULK INSERT bronze.cards_card_master
		FROM 'G:\My Drive\bank project\BankDataWarehouse\datasets\cards_card_master.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '0x0d0a',
			CODEPAGE = '65001',
			TABLOCK
		);
		SET @end_time = GETDATE()
		PRINT 'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds'
		PRINT '----------------------------------------------';

		SET @start_time = GETDATE()
		PRINT '>> Truncating Table: bronze.cards_transactions';
		TRUNCATE TABLE bronze.cards_transactions;

		PRINT '>> Inserting Data Into: bronze.cards_transactions';
		BULK INSERT bronze.cards_transactions
		FROM 'G:\My Drive\bank project\BankDataWarehouse\datasets\cards_transactions.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '0x0d0a',
			CODEPAGE = '65001',
			TABLOCK
		);
		SET @end_time = GETDATE()
		PRINT 'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '----------------------------------------------';

		PRINT '----------------------------------------------';
		PRINT			'Loading core Tables';
		PRINT '----------------------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.core_account';
		TRUNCATE TABLE bronze.core_account;

		PRINT '>> Inserting Data Into: bronze.core_account';
		BULK INSERT bronze.core_account
		FROM 'G:\My Drive\bank project\BankDataWarehouse\datasets\core_account.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '0x0d0a',
			CODEPAGE = '65001',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '----------------------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.core_account_balance_extract';
		TRUNCATE TABLE bronze.core_account_balance_extract;

		PRINT '>> Inserting Data Into: bronze.core_account_balance_extract';
		BULK INSERT bronze.core_account_balance_extract
		FROM 'G:\My Drive\bank project\BankDataWarehouse\datasets\core_account_balance_extract.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '0x0d0a',
			CODEPAGE = '65001',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '----------------------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.core_client_extract';
		TRUNCATE TABLE bronze.core_client_extract;

		PRINT '>> Inserting Data Into: bronze.core_client_extract';
		BULK INSERT bronze.core_client_extract
		FROM 'G:\My Drive\bank project\BankDataWarehouse\datasets\core_client_extract.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '0x0d0a',
			CODEPAGE = '65001',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '----------------------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.core_product';
		TRUNCATE TABLE bronze.core_product;

		PRINT '>> Inserting Data Into: bronze.core_product';
		BULK INSERT bronze.core_product
		FROM 'G:\My Drive\bank project\BankDataWarehouse\datasets\core_product.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '0x0d0a',
			CODEPAGE = '65001',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '----------------------------------------------';

		SET @batch_end_time = GETDATE();
		PRINT '==============================================';
		PRINT 'Loading Bronze Layer is Completed';
		PRINT 'Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '==============================================';
	END TRY
	BEGIN CATCH
		PRINT '==============================================';
		PRINT 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
		PRINT 'ERROR MESSAGE ' + ERROR_MESSAGE();
		PRINT 'ERROR NUMBER ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'ERROR STATE ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '==============================================';
	END CATCH
END