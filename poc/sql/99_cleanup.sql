-- =============================================================================
-- Agent DevOps POC - 99: cleanup (drops EVERYTHING created by the POC)
-- Run as: ACCOUNTADMIN
-- Afterwards: set the GitHub repository back to private.
-- =============================================================================
USE ROLE ACCOUNTADMIN;

DROP DATABASE IF EXISTS AGENT_POC_QA;     -- QA agent + semantic view
DROP DATABASE IF EXISTS AGENT_POC_DEV;    -- DEV agent + semantic view
DROP DATABASE IF EXISTS AGENT_POC_OPS;    -- Git repo object, stage, procedure, log
DROP INTEGRATION IF EXISTS AGENT_POC_GIT_API;

DROP ROLE IF EXISTS AGENT_POC_DEV_ROLE;
DROP ROLE IF EXISTS AGENT_POC_QA_ROLE;
DROP ROLE IF EXISTS AGENT_POC_RELEASE_ROLE;

-- Workspace leftovers to remove manually (optional):
--   cortex_project/SALES_AGENT_POC.agent.yaml  and its entry in cortex_project/cortex-project.yaml
--   poc/
