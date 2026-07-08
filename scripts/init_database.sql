/*
============================================================
				CREATE DATABASE AND SCHEMA 
============================================================
Script Purpose:
	This script creates a new database named "BankDataWarehouse" after checking if it already exists.
	If the database exists, it is dropped and recreated. Additionally, the script sets up three schemas
	within the database: 'bronze', 'silver', and 'gold'.

WARNING:
	Running this script will drop the entire 'DataWarehouse' database if it exists.
============================================================
*/

USE master;
GO

-- Drop and recreate the 'BankDataWarehouse' database
IF EXISTS(SELECT 1 FROM sys.databases WHERE name = 'BankDataWarehouse')
BEGIN
	ALTER DATABASE BankDataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE BankDataWarehouse;
END;
GO

-- Create the 'BankDataWarehouse' database
CREATE DATABASE BankDataWarehouse;
GO

USE BankDataWarehouse;
GO

-- Creates Schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;

