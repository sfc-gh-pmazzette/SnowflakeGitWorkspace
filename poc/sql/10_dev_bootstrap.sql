-- =============================================================================
-- Agent DevOps POC - 10: DEV agent (authoring environment)
--
-- PREFERRED: create/update the DEV agent from the workspace file
--   cortex_project/SALES_AGENT_POC.agent.yaml
-- with either
--   a) the editor's Deploy button (note: creates a new VERSION$N every click), or
--   b) terminal:  cortex agent-studio agent-save --file-path cortex_project/SALES_AGENT_POC.agent.yaml
--      (CREATE if new, otherwise updates LIVE only)
--
-- FALLBACK (pure SQL): the block below creates the DEV agent once with the same
-- spec. After that, keep editing the workspace file - not this script - since
-- the file is what goes to Git and gets released.
-- Run as: ACCOUNTADMIN or AGENT_POC_DEV_ROLE
-- =============================================================================
USE ROLE AGENT_POC_DEV_ROLE;
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;

CREATE AGENT IF NOT EXISTS AGENT_POC_DEV.SALES.SALES_AGENT
  COMMENT = 'Agent POC - DEV (edited from the workspace)'
  PROFILE = '{"display_name": "Sales Assistant (DEV)"}'
  FROM SPECIFICATION
$$
models:
  orchestration: auto
instructions:
  response: |
    You are a sales analytics assistant (TPCH sample data, orders 1992-1998).
    Be concise and data-driven. Format currency as dollars (e.g., $1,234.56).
    Use tables when presenting multiple rows of results.
    Always include the relevant time period for the data you return.
  orchestration: "Use sales_analyst for all questions about sales, revenue, orders, customers, market segments and countries."
  sample_questions:
    - question: "Which 5 nations have the highest revenue?"
    - question: "What is the average order value by market segment?"
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: sales_analyst
      description: "Queries sales orders (1992-1998): revenue, order count, average order value, customer count by date, status, priority, customer, market segment and nation."
tool_resources:
  sales_analyst:
    execution_environment:
      type: warehouse
      warehouse: SNOWFLAKE_LEARNING_WH
    semantic_view: AGENT_POC_DEV.SALES.SALES_SV
$$;

SHOW VERSIONS IN AGENT AGENT_POC_DEV.SALES.SALES_AGENT;

-- Quick interactive test of DEV LIVE
SELECT TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'AGENT_POC_DEV.SALES.SALES_AGENT',
  $${"messages":[{"role":"user","content":[{"type":"text","text":"Which 5 nations have the highest revenue?"}]}]}$$,
  TRUE)) AS RESPONSE;
