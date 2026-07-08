/*
============================================================
			DDL Script: Create Bronze Tables
============================================================
Script Purpose:
	This script creates tables in the 'bronze' schema,
	dropping existing tables if they already exists.

	Run this script to re-define the DDL sctructure of 'bronze' Tables
============================================================
*/
IF OBJECT_ID('bronze.cards_card_master', 'U') IS NOT NULL
    DROP TABLE bronze.cards_card_master;
GO

CREATE TABLE bronze.cards_card_master (
    card_id NVARCHAR (50),
	account_id NVARCHAR(50),
	cif NVARCHAR(50),
	card_holder_name NVARCHAR(50),
	card_type NVARCHAR(50),
	card_status NVARCHAR(50),
	issue_date NVARCHAR(50),
	[expiry_date] NVARCHAR(50)
);
GO

IF OBJECT_ID('bronze.cards_transactions', 'U') IS NOT NULL
	DROP TABLE bronze.cards_transactions;
GO

CREATE TABLE bronze.cards_transactions(
	transaction_id NVARCHAR(50),
	card_id NVARCHAR(50),
	transaction_datetime NVARCHAR(50),
	amount NVARCHAR(50),
	currency NVARCHAR(50),
	merchant_category NVARCHAR(50),
	transaction_type NVARCHAR(50),
	country_code NVARCHAR(50)
);
GO

IF OBJECT_ID('bronze.core_account', 'U') IS NOT NULL
	DROP TABLE bronze.core_account;
GO

CREATE TABLE bronze.core_account(
	account_id NVARCHAR(50),
	client_id NVARCHAR(50),
	product_id NVARCHAR(50),
	open_date NVARCHAR(50),
	close_date NVARCHAR(50),
	[status] NVARCHAR(50),
	currency NVARCHAR(50)
);
GO

IF OBJECT_ID('bronze.core_product', 'U') IS NOT NULL
	DROP TABLE bronze.core_product;
GO

CREATE TABLE bronze.core_product(
	product_id NVARCHAR(50),
	product_name NVARCHAR(100),
	product_category NVARCHAR(50)
);
GO

IF OBJECT_ID('bronze.core_client_extract', 'U') IS NOT NULL
	DROP TABLE bronze.core_client_extract;
GO

CREATE TABLE bronze.core_client_extract(
	extract_date NVARCHAR(50),
	client_id NVARCHAR(50),
	first_name NVARCHAR(50),
	last_name NVARCHAR(50),
	birth_date NVARCHAR(50),
	email NVARCHAR(100),
	phone NVARCHAR(50),
	address_city NVARCHAR(50),
	segment NVARCHAR(50),
	client_since_date NVARCHAR(50)
);

IF OBJECT_ID('bronze.core_account_balance_extract', 'U') IS NOT NULL
	DROP TABLE bronze.core_account_balance_extract;
GO

CREATE TABLE bronze.core_account_balance_extract(
	extract_month NVARCHAR(50),
	account_id NVARCHAR(50),
	balance NVARCHAR(50)
);
