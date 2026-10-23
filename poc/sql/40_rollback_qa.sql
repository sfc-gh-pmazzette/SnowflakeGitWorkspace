-- =============================================================================
-- Agent DevOps POC - 40: rollback and repeatability in QA
-- Run as: AGENT_POC_RELEASE_ROLE      Prerequisite: v1.0 and v1.1 both released
--
-- Rollback = release an OLDER tag again. RELEASE_AGENT finds the existing
-- version by its comment ('git v1.0'), imports nothing, and only moves the
-- alias + default. No VERSION$N is ever hardcoded.
-- =============================================================================
USE ROLE AGENT_POC_RELEASE_ROLE;
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;

-- 1. Before
SHOW VERSIONS IN AGENT AGENT_POC_QA.SALES.SALES_AGENT;

-- 2. Roll back QA to v1.0   (expect ACTION = REUSED)
CALL AGENT_POC_OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', 'v1.0', 'QA', 'qa', TRUE);
SHOW VERSIONS IN AGENT AGENT_POC_QA.SALES.SALES_AGENT;

-- 3. Roll forward to v1.1, twice: the 2nd call must not create a new version (REUSED)
CALL AGENT_POC_OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', 'v1.1', 'QA', 'qa', TRUE);
CALL AGENT_POC_OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', 'v1.1', 'QA', 'qa', TRUE);
SHOW VERSIONS IN AGENT AGENT_POC_QA.SALES.SALES_AGENT;   -- still exactly one version per tag

-- 4. Audit trail
SELECT RELEASED_AT, RELEASED_BY, GIT_TAG, VERSION_NAME, ALIAS_NAME, ACTION, STATUS
FROM AGENT_POC_OPS.RELEASE.RELEASE_LOG
WHERE ENV = 'QA'
ORDER BY RELEASED_AT;
