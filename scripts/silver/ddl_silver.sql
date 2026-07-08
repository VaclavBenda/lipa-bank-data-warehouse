/*
============================================================
			DDL Script: Create Silver Tables
============================================================
Script Purpose:
	This script creates tables in the 'silver' schema, 
	dropping existing tables if they already exist.
	
	Run this script to re-define the DDL structure of 'silver' Tables
============================================================
*/

IF OBJECT_ID('silver.cards_transactions', 'U') IS NOT NULL
    DROP TABLE silver.cards_transactions;
GO

IF OBJECT_ID('silver.core_account_balance_extract', 'U') IS NOT NULL
    DROP TABLE silver.core_account_balance_extract;
GO

IF OBJECT_ID('silver.cards_card_master', 'U') IS NOT NULL
    DROP TABLE silver.cards_card_master;
GO

IF OBJECT_ID('silver.core_account', 'U') IS NOT NULL
    DROP TABLE silver.core_account;
GO

IF OBJECT_ID('silver.core_product', 'U') IS NOT NULL
    DROP TABLE silver.core_product;
GO

IF OBJECT_ID('silver.core_client_extract', 'U') IS NOT NULL
    DROP TABLE silver.core_client_extract;
GO

IF OBJECT_ID('silver.possible_duplicate_clients', 'U') IS NOT NULL
    DROP TABLE silver.possible_duplicate_clients;
GO

IF OBJECT_ID('silver.quarantine_balance', 'U') IS NOT NULL
    DROP TABLE silver.quarantine_balance;
GO

IF OBJECT_ID('silver.quarantine_transactions', 'U') IS NOT NULL
    DROP TABLE silver.quarantine_transactions;
GO

CREATE TABLE silver.core_client_extract (
	extract_date DATE NOT NULL,
	client_id VARCHAR(10) NOT NULL,
	first_name NVARCHAR(50) NULL,
	last_name NVARCHAR(50) NULL,
	birth_date DATE NULL,
	email VARCHAR(100) NULL,
	phone VARCHAR(13) NULL,
	address_city NVARCHAR(50) NULL,
	segment VARCHAR(10) NULL,
	client_since_date DATE NULL,

	CONSTRAINT PK_silver_core_client_extract
		PRIMARY KEY (extract_date, client_id),

	CONSTRAINT CK_silver_core_client_extract
		CHECK (segment IN ('Retail', 'Premium', 'Private'))
);
GO

CREATE TABLE silver.core_product (
	product_id VARCHAR(10) NOT NULL,
	product_name NVARCHAR(50) NOT NULL,
	product_category NVARCHAR(20) NOT NULL,

	CONSTRAINT PK_silver_core_product
		PRIMARY KEY(product_id),

	CONSTRAINT CK_silver_core_product
		CHECK (product_category IN (N'Běžný účet', N'Spořicí účet'))
);
GO

CREATE TABLE silver.core_account(
	account_id VARCHAR(12) NOT NULL, 
	client_id VARCHAR(10) NOT NULL,
	product_id VARCHAR(10) NOT NULL,
	open_date DATE NOT NULL,
	close_date DATE NULL,
	[status] VARCHAR(15) NOT NULL,
	currency VARCHAR(3) NOT NULL,

	CONSTRAINT PK_silver_core_account
		PRIMARY KEY(account_id),
	
	CONSTRAINT FK_silver_core_account
		FOREIGN KEY(product_id) 
		REFERENCES silver.core_product(product_id),

	CONSTRAINT CK_silver_core_account
		CHECK ([status] IN ('Active', 'Closed', 'Dormant'))
);
GO

CREATE TABLE silver.core_account_balance_extract(
	extract_month DATE NOT NULL,
	account_id VARCHAR(12) NOT NULL,
	balance DECIMAL(15,2) NULL,

	CONSTRAINT PK_silver_core_account_balance_extract
		PRIMARY KEY(extract_month, account_id),

	CONSTRAINT FK_silver_core_account_balance_extract
		FOREIGN KEY(account_id)
		REFERENCES silver.core_account(account_id)
);
GO

CREATE TABLE silver.cards_card_master(
	card_id VARCHAR(12) NOT NULL,
	account_id VARCHAR(12) NOT NULL,
	cif VARCHAR(12) NOT NULL,
	card_holder_name NVARCHAR(100),
	card_type VARCHAR(10) NOT NULL,
	card_status VARCHAR(10) NOT NULL,
	issue_date DATE NOT NULL,
	[expiry_date] DATE NOT NULL,
	account_resolved_in_core BIT NOT NULL,
	holder_name_matches_core BIT NULL,

	CONSTRAINT PK_silver_cards_card_master
		PRIMARY KEY(card_id),

	CONSTRAINT CK_silver_cards_card_type
		CHECK (card_type IN ('Debit', 'Credit')),

	CONSTRAINT CK_silver_cards_card_status
		CHECK (card_status IN ('Active', 'Blocked', 'Expired'))
);
GO

CREATE TABLE silver.cards_transactions(
	transaction_id BIGINT NOT NULL,
	card_id VARCHAR(12) NOT NULL,
	transaction_datetime DATETIME2 NOT NULL,
	amount DECIMAL(15,2) NOT NULL,
	currency VARCHAR(3) NOT NULL,
	merchant_category VARCHAR(30) NULL,
	transaction_type VARCHAR(15) NOT NULL,
	country_code VARCHAR(2) NOT NULL,

	CONSTRAINT PK_silver_cards_transactions
		PRIMARY KEY(transaction_id),

	CONSTRAINT FK_silver_cards_transactions
		FOREIGN KEY(card_id)
		REFERENCES silver.cards_card_master(card_id),

	CONSTRAINT CK_silver_cards_transactions
		CHECK((transaction_type = 'Refund' AND amount <= 0) OR (transaction_type IN ('Purchase', 'Withdrawal') AND amount >= 0)),

	CONSTRAINT CK_silver_cards_transaction_type
		CHECK (transaction_type IN ('Purchase', 'Withdrawal', 'Refund'))
);
GO

CREATE TABLE silver.possible_duplicate_clients(
	duplicate_group_id INT IDENTITY(1,1) NOT NULL,
	client_id_1 VARCHAR(10) NOT NULL,
	client_id_2 VARCHAR(10) NOT NULL,
	first_name NVARCHAR(50) NULL,
	last_name NVARCHAR(50) NULL,
	birth_date DATE NULL,
	match_reason VARCHAR(100) NOT NULL,
	resolution_status VARCHAR(20) NOT NULL,
	created_timestamp DATETIME2 NOT NULL,

	CONSTRAINT PK_silver_possible_duplicate_clients
		PRIMARY KEY(duplicate_group_id),

	CONSTRAINT CK_silver_possible_duplicate_clients_status
		CHECK (resolution_status IN ('Open', 'Resolved', 'False Positive'))
);
GO

CREATE TABLE silver.quarantine_balance(
	extract_month NVARCHAR(50) NULL,
	account_id NVARCHAR(50) NULL,
	balance NVARCHAR(50) NULL,
	quarantine_reason VARCHAR(100) NOT NULL,
	quarantine_timestamp DATETIME2 NOT NULL
);
GO

CREATE TABLE silver.quarantine_transactions(
	transaction_id NVARCHAR(50) NULL,
	card_id NVARCHAR(50) NULL,
	transaction_datetime NVARCHAR(50) NULL,
	amount NVARCHAR(50) NULL,
	currency NVARCHAR(50) NULL,
	merchant_category NVARCHAR(50) NULL,
	transaction_type NVARCHAR(50) NULL,
	country_code NVARCHAR(50) NULL,
	quarantine_reason VARCHAR(100) NOT NULL,
	quarantine_timestamp DATETIME2 NOT NULL
);
