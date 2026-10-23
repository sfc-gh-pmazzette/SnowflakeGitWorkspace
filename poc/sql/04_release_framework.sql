-- =============================================================================
-- Agent DevOps POC - 04: release framework
-- Run as: ACCOUNTADMIN       Re-runnable: yes
--
-- Objects (all in AGENT_POC_OPS.RELEASE):
--   ENVIRONMENTS   : where each environment's agents live + which role may run them
--   ENV_MAPPING    : string substitutions applied to the DEV spec per environment
--   RELEASE_STAGE  : rendered, environment-specific specs (agent_spec.yaml) per tag
--   RELEASE_LOG    : audit trail of every release / promotion / rollback
--   RELEASE_AGENT  : the ONE procedure CI (or you) calls:
--                    CALL RELEASE_AGENT('<AGENT>', '<git tag>', '<ENV>', '<alias>', <set_default>)
--
-- What RELEASE_AGENT does (re-runnable for the same tag):
--   1. FETCH the Git repository
--   2. read  <spec_path> at tags/<tag>  (the DEV spec you authored)
--   3. apply ENV_MAPPING for <ENV>       (e.g. AGENT_POC_DEV -> AGENT_POC_QA)
--   4. write @RELEASE_STAGE/<AGENT>/<ENV>/<tag>/agent_spec.yaml
--   5. agent missing     -> CREATE AGENT ... FROM @stage   (VERSION$1)
--      tag not imported  -> ALTER AGENT ... ADD VERSION FROM @stage COMMENT='git <tag>'
--      tag already there -> reuse that version (this is how rollback works)
--   6. move <alias> to that version, optionally set DEFAULT_VERSION
--   7. grant USAGE on the agent to the environment's consumer role
--   8. log the result
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA AGENT_POC_OPS.RELEASE;

-- ---------- Configuration tables ----------------------------------------------
CREATE TABLE IF NOT EXISTS ENVIRONMENTS (
  ENV            STRING NOT NULL PRIMARY KEY,   -- DEV / QA / PRD
  AGENT_DATABASE STRING NOT NULL,
  AGENT_SCHEMA   STRING NOT NULL,
  CONSUMER_ROLE  STRING NOT NULL                -- role that gets USAGE on released agents
);

CREATE TABLE IF NOT EXISTS ENV_MAPPING (
  ENV          STRING NOT NULL,                 -- target environment
  SOURCE_VALUE STRING NOT NULL,                 -- text in the DEV spec
  TARGET_VALUE STRING NOT NULL,                 -- replacement in the target spec
  NOTE         STRING
);

CREATE TABLE IF NOT EXISTS RELEASE_LOG (
  RELEASED_AT   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
  RELEASED_BY   STRING        DEFAULT CURRENT_USER(),
  RELEASE_ROLE  STRING        DEFAULT CURRENT_ROLE(),
  AGENT_FQN     STRING,
  ENV           STRING,
  GIT_TAG       STRING,
  VERSION_NAME  STRING,
  ALIAS_NAME    STRING,
  SET_DEFAULT   BOOLEAN,
  ACTION        STRING,                         -- CREATED / IMPORTED / REUSED
  STATUS        STRING,                         -- SUCCESS / FAILED
  DETAILS       STRING
);

-- Idempotent seed (MERGE so re-running doesn't duplicate rows)
MERGE INTO ENVIRONMENTS t USING (
  SELECT * FROM VALUES
    ('DEV', 'AGENT_POC_DEV', 'SALES', 'AGENT_POC_DEV_ROLE'),
    ('QA',  'AGENT_POC_QA',  'SALES', 'AGENT_POC_QA_ROLE')
    -- ,('PRD', 'AGENT_POC_PRD', 'SALES', 'AGENT_POC_PRD_ROLE')
  AS s(ENV, AGENT_DATABASE, AGENT_SCHEMA, CONSUMER_ROLE)
) s ON t.ENV = s.ENV
WHEN MATCHED THEN UPDATE SET AGENT_DATABASE = s.AGENT_DATABASE, AGENT_SCHEMA = s.AGENT_SCHEMA, CONSUMER_ROLE = s.CONSUMER_ROLE
WHEN NOT MATCHED THEN INSERT VALUES (s.ENV, s.AGENT_DATABASE, s.AGENT_SCHEMA, s.CONSUMER_ROLE);

MERGE INTO ENV_MAPPING t USING (
  SELECT * FROM VALUES
    ('QA', 'AGENT_POC_DEV.', 'AGENT_POC_QA.', 'database of every object referenced by the spec'),
    ('QA', 'SNOWFLAKE_LEARNING_WH', 'SNOWFLAKE_LEARNING_WH', 'warehouse (same in the POC; differs in a real setup)')
  AS s(ENV, SOURCE_VALUE, TARGET_VALUE, NOTE)
) s ON t.ENV = s.ENV AND t.SOURCE_VALUE = s.SOURCE_VALUE
WHEN MATCHED THEN UPDATE SET TARGET_VALUE = s.TARGET_VALUE, NOTE = s.NOTE
WHEN NOT MATCHED THEN INSERT VALUES (s.ENV, s.SOURCE_VALUE, s.TARGET_VALUE, s.NOTE);

-- ---------- Stage for rendered specs --------------------------------------------
CREATE STAGE IF NOT EXISTS RELEASE_STAGE
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = 'Rendered agent specs: <AGENT>/<ENV>/<tag>/agent_spec.yaml';

-- ---------- Release procedure ---------------------------------------------------
CREATE OR REPLACE PROCEDURE RELEASE_AGENT(
    AGENT_NAME  STRING,             -- e.g. 'SALES_AGENT'
    GIT_TAG     STRING,             -- e.g. 'v1.0'
    TARGET_ENV  STRING,             -- e.g. 'QA'
    ALIAS_NAME  STRING,             -- e.g. 'qa' / 'production'
    SET_DEFAULT BOOLEAN,            -- TRUE: also set DEFAULT_VERSION (what CoWork uses)
    SPEC_PATH   STRING DEFAULT 'cortex_project/SALES_AGENT_POC.agent.yaml'
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
COMMENT = 'Agent POC - render DEV spec at a Git tag for an environment, import as a frozen version, move alias'
EXECUTE AS CALLER
AS
$$
import io
import re

OPS = "AGENT_POC_OPS.RELEASE"
REPO = f"{OPS}.AGENTS_REPO"
STAGE = f"{OPS}.RELEASE_STAGE"

IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
TAG = re.compile(r"^[A-Za-z0-9._\-]+$")
PATH = re.compile(r"^[A-Za-z0-9._\-/]+$")


def _check(value, pattern, label):
    if value is None or not pattern.match(value):
        raise ValueError(f"Invalid {label}: {value!r}")


def _versions(session, fqn):
    return [r.as_dict() for r in session.sql(f"SHOW VERSIONS IN AGENT {fqn}").collect()]


def _version_for_comment(session, fqn, comment):
    for v in _versions(session, fqn):
        if v.get("name") and v.get("comment") == comment:
            return v["name"]
    return None


def _log(session, fqn, env, tag, version, alias, set_default, action, status, details):
    session.sql(
        f"INSERT INTO {OPS}.RELEASE_LOG "
        "(AGENT_FQN, ENV, GIT_TAG, VERSION_NAME, ALIAS_NAME, SET_DEFAULT, ACTION, STATUS, DETAILS) "
        "SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?",
        params=[fqn, env, tag, version, alias, set_default, action, status, details],
    ).collect()


def run(session, agent_name, git_tag, target_env, alias_name, set_default, spec_path):
    agent_name = agent_name.upper()
    target_env = target_env.upper()
    _check(agent_name, IDENT, "agent name")
    _check(git_tag, TAG, "git tag")
    _check(target_env, IDENT, "environment")
    _check(alias_name, IDENT, "alias")
    _check(spec_path, PATH, "spec path")

    env_rows = session.sql(
        f"SELECT AGENT_DATABASE, AGENT_SCHEMA, CONSUMER_ROLE FROM {OPS}.ENVIRONMENTS WHERE ENV = ?",
        params=[target_env],
    ).collect()
    if not env_rows:
        raise ValueError(f"Unknown environment {target_env} (see {OPS}.ENVIRONMENTS)")
    db, schema, consumer_role = env_rows[0][0], env_rows[0][1], env_rows[0][2]
    fqn = f"{db}.{schema}.{agent_name}"
    comment = f"git {git_tag}"
    version, action = None, None

    try:
        # 1-2. Fetch and read the spec as it was at the tag
        session.sql(f"ALTER GIT REPOSITORY {REPO} FETCH").collect()
        src = f"@{REPO}/tags/{git_tag}/{spec_path}"
        spec = session.file.get_stream(src).read().decode("utf-8")

        # 3. Environment substitution
        mapping = session.sql(
            f"SELECT SOURCE_VALUE, TARGET_VALUE FROM {OPS}.ENV_MAPPING WHERE ENV = ? "
            "ORDER BY LENGTH(SOURCE_VALUE) DESC",
            params=[target_env],
        ).collect()
        for source_value, target_value in mapping:
            spec = spec.replace(source_value, target_value)
        if target_env != "DEV" and "AGENT_POC_DEV" in spec:
            raise ValueError("Rendered spec still references AGENT_POC_DEV - check ENV_MAPPING")

        # 4. Write the rendered spec
        release_dir = f"@{STAGE}/{agent_name}/{target_env}/{git_tag}"
        session.file.put_stream(
            io.BytesIO(spec.encode("utf-8")),
            f"{release_dir}/agent_spec.yaml",
            auto_compress=False,
            overwrite=True,
        )

        # 5. Create / import / reuse
        exists = session.sql(f"SHOW AGENTS LIKE '{agent_name}' IN SCHEMA {db}.{schema}").collect()
        if not exists:
            session.sql(
                f"CREATE AGENT {fqn} COMMENT = 'Released from Git by RELEASE_AGENT' FROM {release_dir}"
            ).collect()
            committed = [v["name"] for v in _versions(session, fqn)
                         if (v.get("name") or "").upper().startswith("VERSION$")]
            if len(committed) != 1:
                raise RuntimeError(f"Expected exactly one committed version after CREATE, got {committed}")
            version = committed[0]
            session.sql(f"ALTER AGENT {fqn} MODIFY VERSION {version} SET COMMENT = '{comment}'").collect()
            action = "CREATED"
        else:
            version = _version_for_comment(session, fqn, comment)
            if version:
                action = "REUSED"
            else:
                session.sql(
                    f"ALTER AGENT {fqn} ADD VERSION FROM {release_dir} COMMENT = '{comment}'"
                ).collect()
                version = _version_for_comment(session, fqn, comment)
                if not version:
                    raise RuntimeError(f"ADD VERSION succeeded but no version has comment '{comment}'")
                action = "IMPORTED"

        # 6. Move the alias (unset it on the previous holder if Snowflake refuses a duplicate)
        current = {v.get("name"): (v.get("alias") or "") for v in _versions(session, fqn)}
        if current.get(version, "").upper() != alias_name.upper():
            try:
                session.sql(f"ALTER AGENT {fqn} MODIFY VERSION {version} SET ALIAS = {alias_name}").collect()
            except Exception:
                for name, alias in current.items():
                    if name and name != version and alias.upper() == alias_name.upper():
                        session.sql(f"ALTER AGENT {fqn} MODIFY VERSION {name} UNSET ALIAS").collect()
                session.sql(f"ALTER AGENT {fqn} MODIFY VERSION {version} SET ALIAS = {alias_name}").collect()

        if set_default:
            session.sql(f"ALTER AGENT {fqn} SET DEFAULT_VERSION = '{version}'").collect()

        # 7. Consumers can run the agent
        session.sql(f"GRANT USAGE ON AGENT {fqn} TO ROLE {consumer_role}").collect()

        result = f"{fqn}: {git_tag} -> {version} ({action}), alias={alias_name}, default={bool(set_default)}"
        _log(session, fqn, target_env, git_tag, version, alias_name, set_default, action, "SUCCESS", result)
        return result

    except Exception as e:
        _log(session, fqn, target_env, git_tag, version, alias_name, set_default, action, "FAILED", str(e)[:4000])
        raise
$$;

-- ---------- Grants for the release role ----------------------------------------
GRANT SELECT ON TABLE ENVIRONMENTS TO ROLE AGENT_POC_RELEASE_ROLE;
GRANT SELECT ON TABLE ENV_MAPPING  TO ROLE AGENT_POC_RELEASE_ROLE;
GRANT SELECT, INSERT ON TABLE RELEASE_LOG TO ROLE AGENT_POC_RELEASE_ROLE;
GRANT READ, WRITE ON STAGE RELEASE_STAGE TO ROLE AGENT_POC_RELEASE_ROLE;
GRANT USAGE ON PROCEDURE RELEASE_AGENT(STRING, STRING, STRING, STRING, BOOLEAN, STRING) TO ROLE AGENT_POC_RELEASE_ROLE;

SELECT * FROM ENVIRONMENTS;
SELECT * FROM ENV_MAPPING;
