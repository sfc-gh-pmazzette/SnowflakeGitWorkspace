-- =============================================================================
-- Agent DevOps POC - 03: semantic views (same definition, one per environment)
-- Run as: ACCOUNTADMIN       Re-runnable: yes
--
-- Scope note: the POC promotes the AGENT through Git. The semantic view is
-- created per environment here; promoting semantic views can follow the same
-- pattern later (SV YAML in Git + SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML).
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;

-- ---------------------------------- DEV -------------------------------------
CREATE OR REPLACE SEMANTIC VIEW AGENT_POC_DEV.SALES.SALES_SV
  TABLES (
    orders   AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS   PRIMARY KEY (O_ORDERKEY)  COMMENT = 'Sales orders',
    customer AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER PRIMARY KEY (C_CUSTKEY)   COMMENT = 'Customers',
    nation   AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION   PRIMARY KEY (N_NATIONKEY) COMMENT = 'Countries'
  )
  RELATIONSHIPS (
    orders_to_customer AS orders (O_CUSTKEY) REFERENCES customer,
    customer_to_nation AS customer (C_NATIONKEY) REFERENCES nation
  )
  DIMENSIONS (
    orders.order_date      AS O_ORDERDATE                        COMMENT = 'Date the order was placed',
    orders.order_month     AS DATE_TRUNC('MONTH', O_ORDERDATE)   COMMENT = 'Month the order was placed',
    orders.order_year      AS YEAR(O_ORDERDATE)                  COMMENT = 'Year the order was placed',
    orders.order_status    AS O_ORDERSTATUS                      COMMENT = 'F=fulfilled, O=open, P=partial',
    orders.order_priority  AS O_ORDERPRIORITY                    COMMENT = 'Order priority',
    customer.customer_name AS C_NAME                             COMMENT = 'Customer name',
    customer.market_segment AS C_MKTSEGMENT                      COMMENT = 'Customer market segment',
    nation.nation_name     AS N_NAME                             COMMENT = 'Customer country'
  )
  METRICS (
    orders.total_revenue    AS SUM(O_TOTALPRICE)          COMMENT = 'Total revenue in USD',
    orders.order_count      AS COUNT(O_ORDERKEY)          COMMENT = 'Number of orders',
    orders.avg_order_value  AS AVG(O_TOTALPRICE)          COMMENT = 'Average order value in USD',
    customer.customer_count AS COUNT(DISTINCT C_CUSTKEY)  COMMENT = 'Number of customers'
  )
  COMMENT = 'Agent POC - DEV sales semantic view (TPCH, 1992-1998)';

-- ---------------------------------- QA --------------------------------------
CREATE OR REPLACE SEMANTIC VIEW AGENT_POC_QA.SALES.SALES_SV
  TABLES (
    orders   AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS   PRIMARY KEY (O_ORDERKEY)  COMMENT = 'Sales orders',
    customer AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER PRIMARY KEY (C_CUSTKEY)   COMMENT = 'Customers',
    nation   AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION   PRIMARY KEY (N_NATIONKEY) COMMENT = 'Countries'
  )
  RELATIONSHIPS (
    orders_to_customer AS orders (O_CUSTKEY) REFERENCES customer,
    customer_to_nation AS customer (C_NATIONKEY) REFERENCES nation
  )
  DIMENSIONS (
    orders.order_date      AS O_ORDERDATE                        COMMENT = 'Date the order was placed',
    orders.order_month     AS DATE_TRUNC('MONTH', O_ORDERDATE)   COMMENT = 'Month the order was placed',
    orders.order_year      AS YEAR(O_ORDERDATE)                  COMMENT = 'Year the order was placed',
    orders.order_status    AS O_ORDERSTATUS                      COMMENT = 'F=fulfilled, O=open, P=partial',
    orders.order_priority  AS O_ORDERPRIORITY                    COMMENT = 'Order priority',
    customer.customer_name AS C_NAME                             COMMENT = 'Customer name',
    customer.market_segment AS C_MKTSEGMENT                      COMMENT = 'Customer market segment',
    nation.nation_name     AS N_NAME                             COMMENT = 'Customer country'
  )
  METRICS (
    orders.total_revenue    AS SUM(O_TOTALPRICE)          COMMENT = 'Total revenue in USD',
    orders.order_count      AS COUNT(O_ORDERKEY)          COMMENT = 'Number of orders',
    orders.avg_order_value  AS AVG(O_TOTALPRICE)          COMMENT = 'Average order value in USD',
    customer.customer_count AS COUNT(DISTINCT C_CUSTKEY)  COMMENT = 'Number of customers'
  )
  COMMENT = 'Agent POC - QA sales semantic view (TPCH, 1992-1998)';

-- ---------------------------------- Grants ----------------------------------
GRANT SELECT ON SEMANTIC VIEW AGENT_POC_DEV.SALES.SALES_SV TO ROLE AGENT_POC_DEV_ROLE;
GRANT SELECT ON SEMANTIC VIEW AGENT_POC_QA.SALES.SALES_SV  TO ROLE AGENT_POC_QA_ROLE;
GRANT SELECT ON SEMANTIC VIEW AGENT_POC_QA.SALES.SALES_SV  TO ROLE AGENT_POC_RELEASE_ROLE;

SHOW SEMANTIC VIEWS IN DATABASE AGENT_POC_DEV;
SHOW SEMANTIC VIEWS IN DATABASE AGENT_POC_QA;
