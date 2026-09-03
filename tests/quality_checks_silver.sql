--MASTER CHECKS LIST SILVER

-- CHECKS ON DIFFERENT SCHEMAS CAN BE TOGGLLED BY CHANGING FROM
-- SILVER / BRONZE 
/*
==============================================
Quality Checks
==============================================
Script Purpose:
  This script performs various quality checks for data consistency, accuracy,
  and standardization accross the 'silver' schemas. It includes checks for:
  - Null or duplicate primary keys
  - Unwanted Spaces
  - Data Standardization and Consistency
  - Invalid Date Ranges and Orders
  - Data Consistency between related fields

Usage Notes:
  - Run these checks after loading data to silver layer.
  - Investigate and resolve and discrepancies found during the checks.
==============================================
silver.crm_cust_info
==============================================
*/
SELECT *
FROM bronze.crm_cust_info

---CHECK FOR NULLS OR DUPLICATES IN PRIMARY KEY
-- EXPECTATION = NO RESULT

SELECT
	cst_id,
	COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL

-- REMOVE DUPLICATES USING RANK FUNCTION

-- CHECK FOR UNWANTED SPACES
-- EXPECTATION: NO RESULT

SELECT *
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname)

-- DATA STANDARDIZATION AND CONSISTENCY
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info




/*
==============================================
silver.crm_prd_info
==============================================
*/
SELECT TOP 1000 *
FROM bronze.crm_prd_info


-- CHECK FOR DUPLICATES
-- EXPECTED RESULTS = NONE
SELECT 
	prd_id,
	COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) != 1

-- CHECK FOR UNWANTED SPACES
SELECT 
	prd_cost
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm)

-- CHECK FOR NULLS OR NEGATIVE NUMBERS
-- EXPECTATION: NO RESULT
SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL

-- DATA STANDARDIZATION AND CONSISTENCY
SELECT DISTINCT prd_line
FROM silver.crm_prd_info

-- CHECK FOR INVALID DATE ORDERS
SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt



/*
==============================================
silver.crm_sales_details
==============================================
*/
-- CHECK FOR INVALID DATES	
SELECT
NULLIF(sls_order_dt, 0) sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
OR LEN(sls_order_dt) != 0
OR sls_order_dt > 20500101
OR sls_order_dt < 19000101

-- CHECK FOR INVALID DATE ORDERS
SELECT *
FROM silver.crm_sales_details
WHERE 
	sls_order_dt > sls_ship_dt OR
	sls_order_dt > sls_due_dt


-- CHECK DATA CONSISTENCY
-- NO NEGATIVES, 0, NULL VALUES
-- SALES = QUANTITY * PRICE
SELECT 
	sls_sales,
	sls_quantity,
	sls_price
FROM silver.[crm_sales_details]
WHERE sls_price * sls_quantity != sls_sales
OR sls_price IS NULL OR sls_quantity IS NULL OR sls_sales IS NULL
OR sls_price <= 0 OR sls_quantity <= 0 OR sls_sales <= 0


SELECT *
FROM silver.crm_sales_details



/*
==============================================
silver.erp_CUST_AZ12
==============================================
*/
--CHECKING UNWANTED SPACES
SELECT TOP (1000) [CID]
      ,[BDATE]
      ,[GEN]
  FROM [DataWarehouse].[bronze].[erp_CUST_AZ12]
  WHERE CID != TRIM(CID)


--CHECKING FOR DUPLICATES
SELECT
    CID,
    COUNT(*)
FROM silver.erp_CUST_AZ12
GROUP BY CID
HAVING COUNT(*) > 1

--DATA STANDARDISATION
SELECT 
    DISTINCT GEN
FROM SILVER.erp_CUST_AZ12
   

--DATA INTEGRATION CHECK WITH OTHER TABLE
SELECT
    CID
FROM silver.erp_CUST_AZ12
WHERE CID NOT IN (
SELECT cst_key 
FROM silver.crm_cust_info
)

--IDENTIFY OUT OF RANGE DATES
SELECT DISTINCT 
    bdate
FROM silver.erp_CUST_AZ12
WHERE bdate > GETDATE() OR bdate < '1924-01-01'



/*
==============================================
silver.erp_PX_LOC_A101
==============================================
*/
SELECT 
	CID,
	CNTRY
FROM silver.erp_PX_LOC_A101

SELECT cst_key
FROM bronze.crm_cust_info

--INTEGRATION CHECK WITH OTHER TABLE
SELECT 
	CID,
	CNTRY
FROM silver.erp_PX_LOC_A101
WHERE CID NOT IN (
SELECT cst_key
FROM bronze.crm_cust_info
)

--DATA STANDARDISATION AND CONSISTENCY CHECK
SELECT DISTINCT 
	CNTRY
FROM silver.erp_PX_LOC_A101



/*
==============================================
silver.erp_PX_CAT_G1V2
==============================================
*/
SELECT TOP (1000) [ID]
      ,[CAT]
      ,[SUBCAT]
      ,[MAINTENANCE]
  FROM [DataWarehouse].[bronze].[erp_PX_CAT_G1V2]




--INTEGRATION COMPATIBILITY CHECK WITH OTHER TABLE
SELECT
    ID,
    CAT,
    SUBCAT,
    MAINTENANCE
FROM bronze.erp_PX_CAT_G1V2
WHERE ID NOT IN (
SELECT 
    cat_id
FROM silver.crm_prd_info
)

SELECT 
    cat_id
FROM silver.crm_prd_info


--CHECK FOR UNWANTED SPACES
SELECT *
FROM bronze.erp_PX_CAT_G1V2
WHERE CAT != TRIM(CAT) OR
      SUBCAT != TRIM(SUBCAT) OR
      MAINTENANCE != TRIM(MAINTENANCE)

--DATA STANDARDISATION AND CONSISTENCY CHECK
SELECT DISTINCT
    SUBCAT
FROM bronze.erp_PX_CAT_G1V2
