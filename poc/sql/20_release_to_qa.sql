-- =============================================================================
-- Agent DevOps POC - 20: release a Git tag to QA   (this is "the CI step")
-- Run as: AGENT_POC_RELEASE_ROLE      Re-runnable: yes (same tag = no new version)
--
-- Prerequisite: the tag exists on GitHub (created after the PR was merged).
-- >>> Set the tag to release <<<
-- =============================================================================
SET RELEASE_TAG = 'v1.1';

USE ROLE AGENT_POC_RELEASE_ROLE;
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;

-- 0. (optional) What does Snowflake see for this tag?
ALTER GIT REPOSITORY AGENT_POC_OPS.RELEASE.AGENTS_REPO FETCH;
SHOW GIT TAGS IN AGENT_POC_OPS.RELEASE.AGENTS_REPO;

-- 1. Release: render DEV spec at the tag for QA, import as frozen version, alias 'qa', set default
CALL AGENT_POC_OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', $RELEASE_TAG, 'QA', 'qa', TRUE);

-- 2. What was rendered (should reference AGENT_POC_QA only)
LIST @AGENT_POC_OPS.RELEASE.RELEASE_STAGE/SALES_AGENT/QA/;

-- 3. Release log
SELECT RELEASED_AT, AGENT_FQN, ENV, GIT_TAG, VERSION_NAME, ALIAS_NAME, ACTION, STATUS, DETAILS
FROM AGENT_POC_OPS.RELEASE.RELEASE_LOG
ORDER BY RELEASED_AT DESC
LIMIT 10;
