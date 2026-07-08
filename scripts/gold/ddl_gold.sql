/*
============================================================
			DDL Script: Create Gold Tables
============================================================
Script Purpose:
	This script creates tables in the 'gold' schema, 
	dropping existing tables if they already exist.
	
	Run this script to re-define the DDL structure of 'gold' Tables
============================================================
*/

IF OBJECT_ID('gold.fact_card_transactions', 'U') IS NOT NULL
    DROP TABLE gold.fact_card_transactions;
GO

IF OBJECT_ID('gold.fact_account_monthly_snapshot', 'U') IS NOT NULL
    DROP TABLE gold.fact_account_monthly_snapshot;
GO

IF OBJECT_ID('gold.dim_client', 'U') IS NOT NULL
    DROP TABLE gold.dim_client;
GO

IF OBJECT_ID('gold.dim_account', 'U') IS NOT NULL
    DROP TABLE gold.dim_account;
GO

IF OBJECT_ID('gold.dim_card', 'U') IS NOT NULL
    DROP TABLE gold.dim_card;
GO

IF OBJECT_ID('gold.dim_product', 'U') IS NOT NULL
    DROP TABLE gold.dim_product;
GO

IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL
    DROP TABLE gold.dim_date;
GO

CREATE TABLE gold.dim_client(
	client_sk INT IDENTITY(1,1) NOT NULL,
	client_id VARCHAR(10) NOT NULL, 
	first_name NVARCHAR(50),
	last_name NVARCHAR(50),
	birth_date DATE,
	email VARCHAR(100),
	phone VARCHAR(13),
	address_city NVARCHAR(50),
	segment VARCHAR(10),
	client_since_date DATE,
	valid_from DATE NOT NULL,
	valid_to DATE,
	is_current BIT NOT NULL,

	CONSTRAINT PK_dim_client
		PRIMARY KEY(client_sk)
);

CREATE TABLE gold.dim_account(
	account_sk INT IDENTITY(1,1) NOT NULL,
	account_id VARCHAR(12) NOT NULL,
	client_id VARCHAR(10) NOT NULL,
	product_id VARCHAR(10) NOT NULL,
	open_date DATE NOT NULL,
	close_date DATE,
	[status] VARCHAR(15) NOT NULL,
	currency VARCHAR(3) NOT NULL,

	CONSTRAINT PK_dim_account
		PRIMARY KEY(account_sk)
);

CREATE TABLE gold.dim_card(
	card_sk INT IDENTITY(1,1) NOT NULL,
	card_id VARCHAR(12) NOT NULL,
	account_id VARCHAR(12) NOT NULL,
	cif VARCHAR(12) NOT NULL,
	card_holder_name NVARCHAR(100),
	card_type VARCHAR(10) NOT NULL,
	card_status VARCHAR(10) NOT NULL,
	issue_date DATE NOT NULL,
	[expiry_date] DATE NOT NULL,
	account_resolved_in_core BIT NOT NULL,
	holder_name_matches_core BIT,

	CONSTRAINT PK_dim_card
		PRIMARY KEY(card_sk)
);

CREATE TABLE gold.dim_product(
	product_sk INT IDENTITY(1,1) NOT NULL,
	product_id VARCHAR(10) NOT NULL,
	product_name NVARCHAR(50) NOT NULL,
	product_category NVARCHAR(20) NOT NULL,

	CONSTRAINT PK_dim_product
		PRIMARY KEY(product_sk)
);

CREATE TABLE gold.dim_date(
	date_sk INT NOT NULL,
	full_date DATE NOT NULL,
	[year] SMALLINT NOT NULL,
	[quarter] TINYINT NOT NULL,
	month_number TINYINT NOT NULL,
	month_name VARCHAR(20) NOT NULL,
	day_of_month TINYINT NOT NULL,
	day_of_the_week VARCHAR(20) NOT NULL,
	is_weekend BIT NOT NULL,
	is_month_end BIT NOT NULL,

	CONSTRAINT PK_dim_date
		PRIMARY KEY(date_sk)
);

CREATE TABLE gold.fact_card_transactions(
	transaction_id BIGINT NOT NULL,
	date_sk INT NOT NULL,
	card_sk INT NOT NULL,
	account_sk INT NOT NULL,
	client_sk INT NOT NULL,
	amount DECIMAL(15,2) NOT NULL,
	currency VARCHAR(3) NOT NULL,
	merchant_category VARCHAR(30),
	transaction_type VARCHAR(15) NOT NULL,
	country_code VARCHAR(2) NOT NULL,

	CONSTRAINT PK_fact_card_transactions
		PRIMARY KEY(transaction_id),

	CONSTRAINT FK_fact_card_transactions_date_sk
		FOREIGN KEY(date_sk)
		REFERENCES gold.dim_date(date_sk),

	CONSTRAINT FK_fact_card_transactions_card_sk
		FOREIGN KEY(card_sk)
		REFERENCES gold.dim_card(card_sk),

	CONSTRAINT FK_fact_card_transactions_account_sk
		FOREIGN KEY(account_sk)
		REFERENCES gold.dim_account(account_sk),

	CONSTRAINT FK_fact_card_transactions_client_sk
		FOREIGN KEY(client_sk)
		REFERENCES gold.dim_client(client_sk)
);

CREATE TABLE gold.fact_account_monthly_snapshot(
	date_sk INT NOT NULL,
	account_sk INT NOT NULL,
	client_sk INT NOT NULL,
	product_sk INT NOT NULL,
	balance DECIMAL(15,2),

	CONSTRAINT PK_fact_account_monthly_snapshot_date_sk
		PRIMARY KEY(date_sk, account_sk),
	
	CONSTRAINT FK_fact_account_monthly_snapshot_date_sk
		FOREIGN KEY(date_sk)
		REFERENCES gold.dim_date(date_sk),

	CONSTRAINT FK_fact_account_monthly_snapshot_account_sk
		FOREIGN KEY(account_sk)
		REFERENCES gold.dim_account(account_sk),

	CONSTRAINT FK_fact_account_monthly_snapshot_client_sk
		FOREIGN KEY(client_sk)
		REFERENCES gold.dim_client(client_sk),

	CONSTRAINT FK_fact_account_monthly_snapshot_product_sk
		FOREIGN KEY(product_sk)
		REFERENCES gold.dim_product(product_sk)
);
