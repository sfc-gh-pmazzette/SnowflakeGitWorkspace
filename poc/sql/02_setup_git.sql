-- =============================================================================
-- Agent DevOps POC - 02: Git connection (read-only, used by releases)
-- Run as: ACCOUNTADMIN       Re-runnable: yes
--
-- This is NOT the Git workspace. The workspace is where you edit and push.
-- This GIT REPOSITORY object is Snowflake's read-only copy of the same remote,
-- used by the release procedure to read the spec at a given tag.
--
-- >>> Edit the ORIGIN URL below if your repo URL differs. <<<
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------------------------
-- OPTION A (POC default): repository temporarily PUBLIC -> no credentials
-- ---------------------------------------------------------------------------
CREATE API INTEGRATION IF NOT EXISTS AGENT_POC_GIT_API
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-pmazzette/')
  ENABLED = TRUE
  COMMENT = 'Agent POC - read-only Git access for releases';

GRANT USAGE ON INTEGRATION AGENT_POC_GIT_API TO ROLE AGENT_POC_RELEASE_ROLE;

CREATE GIT REPOSITORY IF NOT EXISTS AGENT_POC_OPS.RELEASE.AGENTS_REPO
  API_INTEGRATION = AGENT_POC_GIT_API
  ORIGIN = 'https://github.com/sfc-gh-pmazzette/SnowflakeGitWorkspace.git'
  COMMENT = 'Agent POC - source of agent specs for releases';

-- ---------------------------------------------------------------------------
-- OPTION B (what you'd use in PRD): PRIVATE repository + read-only token
-- Replace Option A with this block. Use a GitHub fine-grained token with
-- "Contents: Read-only" on this repo only.
-- ---------------------------------------------------------------------------
-- CREATE SECRET IF NOT EXISTS AGENT_POC_OPS.RELEASE.GIT_READ_SECRET
--   TYPE = password
--   USERNAME = 'sfc-gh-pmazzette'
--   PASSWORD = '<github_fine_grained_token>';
--
-- CREATE OR REPLACE API INTEGRATION AGENT_POC_GIT_API
--   API_PROVIDER = git_https_api
--   API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-pmazzette/')
--   ALLOWED_AUTHENTICATION_SECRETS = (AGENT_POC_OPS.RELEASE.GIT_READ_SECRET)
--   ENABLED = TRUE;
--
-- CREATE OR REPLACE GIT REPOSITORY AGENT_POC_OPS.RELEASE.AGENTS_REPO
--   API_INTEGRATION = AGENT_POC_GIT_API
--   GIT_CREDENTIALS = AGENT_POC_OPS.RELEASE.GIT_READ_SECRET
--   ORIGIN = 'https://github.com/sfc-gh-pmazzette/SnowflakeGitWorkspace.git';
--
-- GRANT USAGE ON SECRET AGENT_POC_OPS.RELEASE.GIT_READ_SECRET TO ROLE AGENT_POC_RELEASE_ROLE;

-- ---------------------------------------------------------------------------
-- Release role can read the repository
-- ---------------------------------------------------------------------------
GRANT READ ON GIT REPOSITORY AGENT_POC_OPS.RELEASE.AGENTS_REPO TO ROLE AGENT_POC_RELEASE_ROLE;

-- ---------------------------------------------------------------------------
-- Smoke check: fetch and list what Snowflake sees
-- ---------------------------------------------------------------------------
ALTER GIT REPOSITORY AGENT_POC_OPS.RELEASE.AGENTS_REPO FETCH;
SHOW GIT BRANCHES IN AGENT_POC_OPS.RELEASE.AGENTS_REPO;
SHOW GIT TAGS     IN AGENT_POC_OPS.RELEASE.AGENTS_REPO;
LIST @AGENT_POC_OPS.RELEASE.AGENTS_REPO/branches/main/cortex_project/;
