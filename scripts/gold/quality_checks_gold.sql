/*
Quality Check for GOLD LAYER
=======================================
Script Purpose:
	This script performs quality checks to validate data integrity,
	consistency and accuracy of the Gold Layer. These checks ensure:
	- Uniqueness of surrogate keys in dimension tables.
	- Referential integrity between facts and dimension tables.
	- Validation of relationships in the data model for analytical purposes.

Usage Notes:
	- Run these checks after data loading Silver Layer.
	- Investigate and resolve any discrepancies found during the checks.
=======================================
*/

--========================================
--gold.dim_customers
--========================================
--CHECK FOR DUPLICATES
SELECT 
	customer_id,
	COUNT(*)
FROM gold.dim_customers
GROUP BY customer_id
HAVING COUNT (*) > 1

--CHECK DISTINCT GENDERS
SELECT 
	DISTINCT gender
FROM gold.dim_customers

--========================================
--gold.dim_products
--========================================
--CHECK FOR DUPLICATES
SELECT prd_id, COUNT(*) FROM (
SELECT
	pri.prd_id,
	pri.cat_id,
	pri.prd_key,
	pri.prd_nm,
	pri.prd_cost,
	pri.prd_line,
	prc.CAT,
	prc.SUBCAT,
	prc.MAINTENANCE,
	pri.prd_start_dt,
	pri.prd_end_dt
FROM silver.crm_prd_info AS pri
LEFT JOIN silver.erp_PX_CAT_G1V2 prc
ON pri.cat_id = prc.ID
WHERE pri.prd_end_dt IS NULL
)t GROUP BY prd_id
HAVING COUNT(*) > 1

SELECT 
	*
FROM gold.dim_products
--CHECK FOR DATA STANDARDIZATION AND CONSISTENCY
SELECT 
	DISTINCT category
FROM gold.dim_products

--========================================
--gold.fact_sales
--========================================
--FOREIGN KEY INTEGRITY (DIMENSIONS)
SELECT
	*
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
WHERE p.product_key IS NULL

SELECT *
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
LEFT HASH JOIN gold.dim_products p
    ON f.product_key = p.product_key
WHERE p.product_key IS NULL
OPTION (HASH JOIN);

SELECT *
FROM gold.dim_products

SELECT *
FROM gold.dim_customers

