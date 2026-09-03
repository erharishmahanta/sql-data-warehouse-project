--MASTER SCRIPT TO LOAD SILVER LAYER
--METHOD TRUNCATE & INSERT
/*
==============================================================
Stored Procedure: Load Silver Layer (Bronze --> Silver)
==============================================================
Script Purpose:
	This stored procedure performs the ETL(Extract, Transform, Load) Process
	to populate the 'Silver' Schema Tables from the 'Bronze' Schema.
Actions Performed:
	Truncate Silver Schema Tables.
	Insert transformed and cleansed data from Bronze into Silver tables.
Parameters:
	None.
	This stored procedure does not accept any parameters or return any values.

Usage Example:
	EXEC silver.load_silver
*/
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME;
	DECLARE	@start_batch DATETIME, @end_batch DATETIME;
	BEGIN TRY
		SET @start_batch = GETDATE();
		PRINT '===========================================';
		PRINT 'Loading Silver Layer';
		PRINT '===========================================';

		PRINT '-------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '-------------------------------------------';
		SET @start_time = GETDATE()
		PRINT '>> Truncating Table: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info
		PRINT '>> Inserting Data Into: silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info(
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_dt
		)

		SELECT
		cst_id,
		cst_key,
		TRIM(cst_firstname) AS cst_firstname,
		TRIM(cst_lastname) AS cst_lastname,
		CASE WHEN TRIM(UPPER(cst_marital_status)) = 'S' THEN 'Single'
			 WHEN TRIM(UPPER(cst_marital_status)) = 'M' THEN 'Married'
			 ELSE 'n/a'
		END cst_marital_status, -- NORMALISE marital status values to readable format
		CASE WHEN TRIM(UPPER(cst_gndr)) = 'F' THEN 'Female'
			 WHEN TRIM(UPPER(cst_gndr)) = 'M' THEN 'Male'
			 ELSE 'n/a'
		END cst_gndr, -- NORMALISE gender values to readable format
		cst_create_dt
		FROM(
		SELECT 
			*,
			ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_dt DESC) AS flag_last
		FROM bronze.crm_cust_info
		WHERE cst_id IS NOT NULL
		)t WHERE flag_last = 1 -- SELECT most recent customer info and remove duplicates from the result
		SET @end_time = GETDATE()
		PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';


		SET @start_time = GETDATE()
		PRINT '>> Truncating Table: silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info
		PRINT '>> Inserting Data Into: silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info (
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
		)

			SELECT 
				prd_id,
				REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id, --EXTRACT CATEGORY ID
				SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key, -- EXTRACT PRODUCT KEY
				prd_nm,
				COALESCE(prd_cost, 0) AS prd_cost, --HANDLING MISSING VALUES
				CASE WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
					 WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
					 WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
					 WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
					 ELSE 'n/a' END prd_line, --MAP PRODUCT LINR CODES TO DESRIPTIVE VALUES
				CAST(prd_start_dt AS DATE) AS prd_start_dt,
				CAST(
					DATEADD(DAY, -1, LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt)) 
					AS DATE) AS	prd_end_dt -- CALCULATE END DATE AS ONE DAY BEFORE THE NEXT START DATE
			FROM bronze.crm_prd_info
		SET @end_time = GETDATE()
		PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';




		SET @start_time = GETDATE()
		PRINT '>> Truncating Table: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details
		PRINT '>> Inserting Data Into: silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details(
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
		SELECT
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE WHEN sls_order_dt = 0 OR LEN (sls_order_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_order_dt AS NVARCHAR) AS DATE)
				 END AS sls_order_dt,
			CASE WHEN sls_ship_dt = 0 OR LEN (sls_ship_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_ship_dt AS NVARCHAR) AS DATE)
				 END AS sls_ship_dt,
			CASE WHEN sls_due_dt = 0 OR LEN (sls_due_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_due_dt AS NVARCHAR) AS DATE)
				 END AS sls_due_dt,
			CASE WHEN sls_sales IS NULL OR 
				sls_sales <= 0 OR 
				sls_sales != sls_quantity * ABS(sls_price)
			THEN sls_quantity * ABS(sls_price)
			ELSE sls_sales
			END sls_sales, -- RECALCULATE SALES IF ORIGINAL VALUE IS MISSING OR INCORRECT
			sls_quantity,
			CASE WHEN sls_price IS NULL OR
				sls_price <= 0
			THEN sls_sales / NULLIF(sls_quantity, 0)
			ELSE sls_price
			END sls_price -- DERIVE PRICE IF ORIGINAL IS VALUE IS INVALID
		FROM bronze.crm_sales_details
		SET @end_time = GETDATE()
		PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';



		PRINT '-------------------------------------------';
		PRINT 'Loading ERP Tables';
		PRINT '-------------------------------------------';
		SET @start_time = GETDATE()
		PRINT '>> Truncating Table: silver.erp_CUST_AZ12';
		TRUNCATE TABLE silver.erp_CUST_AZ12
		PRINT '>> Inserting Data Into: silver.erp_CUST_AZ12';
		INSERT INTO silver.erp_CUST_AZ12 (
			CID,
			BDATE,
			GEN
		)

		SELECT
			CASE WHEN CID LIKE 'NAS%'
				 THEN SUBSTRING(CID, 4, LEN(CID))
			ELSE CID
			END CID,
			CASE WHEN BDATE > GETDATE()
				 THEN NULL
				 ELSE BDATE
			END AS BDATE,
			CASE WHEN UPPER(TRIM(GEN)) IN ('M', 'MALE')
				 THEN 'Male'
				 WHEN UPPER(TRIM(GEN)) IN ('F', 'FEMALE')
				 THEN 'Female'
				 ELSE 'n/a'
			END AS GEN
		FROM bronze.erp_CUST_AZ12
		SET @end_time = GETDATE()
		PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';



		SET @start_time = GETDATE()
		PRINT '>> Truncating Table: silver.erp_PX_LOC_A101';
		TRUNCATE TABLE silver.erp_PX_LOC_A101
		PRINT '>> Inserting Data Into: silver.erp_PX_LOC_A101';
		INSERT INTO silver.erp_PX_LOC_A101(
			CID,
			CNTRY
		)
		SELECT 
			REPLACE(CID, '-', '') AS CID,
			CASE WHEN TRIM(UPPER(CNTRY)) IN ('USA','US', 'UNITED STATES')
				 THEN 'United States'
				 WHEN CNTRY = 'DE'
				 THEN 'Germany'
				 WHEN TRIM(CNTRY) IS NULL OR TRIM(CNTRY) = ''
				 THEN 'n/a'
				 ELSE TRIM(CNTRY)
			END AS CNTRY
		FROM bronze.erp_LOC_A101
		SET @end_time = GETDATE()
		PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';



		SET @start_time = GETDATE()
		PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';
		PRINT '>> Truncating Table: silver.erp_PX_CAT_G1V2';
		TRUNCATE TABLE silver.erp_PX_CAT_G1V2
		PRINT '>> Inserting Data Into: silver.erp_PX_CAT_G1V2';
		INSERT INTO silver.erp_PX_CAT_G1V2(
			ID,
			CAT,
			SUBCAT,
			MAINTENANCE)
		SELECT *
		FROM bronze.erp_PX_CAT_G1V2
		SET @end_time = GETDATE()
		PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';
		SET @end_batch = GETDATE();
		PRINT '=================================';
		PRINT 'Loading Silver Layer is Completed.';
		PRINT '>>Total Load Duration for Silver Layer: ' + CAST(DATEDIFF(second, @start_batch, @end_batch) AS NVARCHAR)
		PRINT '=================================';

	END TRY
	BEGIN CATCH
		PRINT '=================================';
		PRINT 'ERROR OCCURED WHILE LOADING SILVER LAYER';
		PRINT 'Error Message: ' + ERROR_MESSAGE();
		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);	
		PRINT '=================================';
	END CATCH
END
