/*
=============================================================
DDL Script: Create Gold Views
=============================================================
Script Purpose:
	This script creates	views for the Gold Layer in the Data Warehouse.
	The Gold Layer represents the final dimension and fact tables (Star Schema)

	Each view performs transformations and combines data from silver-layer
	to produce a clean, and enriched dataset ready for business needs.

Usage:
	- These views can be queried directly for analytics and reporting.
=============================================================
*/

--gold.dim_customers
CREATE VIEW gold.dim_customers AS
SELECT
	ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name,
	cl.CNTRY AS country,
	ci.cst_marital_status AS marital_status,
	CASE WHEN ci.cst_gndr != 'n/a'
		 THEN ci.cst_gndr
		 ELSE COALESCE(eci.gen, 'n/a')
		 END AS gender,
	eci.BDATE AS birth_date,
	ci.cst_create_dt AS create_date
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_CUST_AZ12 AS eci
ON ci.cst_key = eci.CID
LEFT JOIN silver.erp_PX_LOC_A101 AS cl
ON ci.cst_key = cl.CID;

--gold.dim_products
CREATE VIEW gold.dim_products AS
SELECT
	ROW_NUMBER() OVER(ORDER BY pri.prd_start_dt, pri.prd_key) AS product_key,
	pri.prd_id AS product_id,
	pri.prd_key AS product_number,
	pri.prd_nm AS prouct_name,
	pri.cat_id AS category_id,
	prc.CAT AS category,
	prc.SUBCAT AS subcategory,
	prc.MAINTENANCE AS maintenance,
	pri.prd_cost AS cost,
	pri.prd_line AS product_line,
	pri.prd_start_dt AS product_start_date
FROM silver.crm_prd_info AS pri
LEFT JOIN silver.erp_PX_CAT_G1V2 prc
ON pri.cat_id = prc.ID
WHERE pri.prd_end_dt IS NULL;

--gold.fact_sales
CREATE VIEW gold.fact_sales AS
SELECT
	s.sls_ord_num AS order_number,
	gp.product_key,
	gc.customer_key,
	s.sls_order_dt AS order_date,
	s.sls_ship_dt AS shipping_date,
	s.sls_due_dt AS due_date,
	s.sls_sales AS sales_amount,
	s.sls_quantity AS quantity,
	s.sls_price as price
FROM silver.crm_sales_details s
LEFT JOIN gold.dim_products gp
ON s.sls_prd_key = gp.product_number
LEFT JOIN gold.dim_customers gc
ON s.sls_cust_id = gc.customer_id
