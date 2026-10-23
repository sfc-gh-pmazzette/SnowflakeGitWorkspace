-- =============================================================================
-- Agent DevOps POC - 30: verify and smoke-test QA
-- Run as: AGENT_POC_QA_ROLE (testers can run, not edit)      Re-runnable: yes
-- =============================================================================
USE ROLE AGENT_POC_QA_ROLE;
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;

-- 1. Versions: each committed version should carry comment 'git <tag>',
--    'qa' alias on the latest released tag, is_default = true on the same row.
SHOW VERSIONS IN AGENT AGENT_POC_QA.SALES.SALES_AGENT;
SELECT "name", "alias", "is_default", "comment", "created_on"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY "created_on";

-- 2. The released spec must point at QA objects, never DEV
DESCRIBE AGENT AGENT_POC_QA.SALES.SALES_AGENT;
SELECT CONTAINS("agent_spec", 'AGENT_POC_DEV') AS REFERENCES_DEV,   -- expect FALSE
       CONTAINS("agent_spec", 'AGENT_POC_QA')  AS REFERENCES_QA     -- expect TRUE
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- 3. Smoke tests against the 'qa' alias (questions/answers: poc/tests/smoke_questions.yaml)
--    If the '!qa' alias form is rejected, replace it with the VERSION$N from step 1.
SELECT 'Q1 top nation by revenue' AS TEST, TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'AGENT_POC_QA.SALES.SALES_AGENT!qa',
  $${"messages":[{"role":"user","content":[{"type":"text","text":"Which nation has the highest total revenue?"}]}]}$$,
  TRUE)) AS RESPONSE
UNION ALL
SELECT 'Q2 total orders', TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'AGENT_POC_QA.SALES.SALES_AGENT!qa',
  $${"messages":[{"role":"user","content":[{"type":"text","text":"How many orders are there in total?"}]}]}$$,
  TRUE))
UNION ALL
SELECT 'Q3 segments', TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'AGENT_POC_QA.SALES.SALES_AGENT!qa',
  $${"messages":[{"role":"user","content":[{"type":"text","text":"How many customer market segments are there?"}]}]}$$,
  TRUE));

-- 4. Negative test: testers must NOT be able to change QA (expect an insufficient privileges error)
-- ALTER AGENT AGENT_POC_QA.SALES.SALES_AGENT MODIFY LIVE VERSION SET SPECIFICATION = $$ instructions: {response: "hacked"} $$;
