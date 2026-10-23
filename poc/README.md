# Agent DevOps POC: DEV → Git → QA

A re-runnable POC for **authoring, versioning, promoting and rolling back** a Cortex Agent across environments. It uses the same mechanics you would use in PRD. The agent is `SALES_AGENT`, over TPCH sample data.

## Design in one picture

```
 Workspace (you)                 GitHub                         Snowflake
 ───────────────                 ──────                         ─────────
 edit cortex_project/            PR → merge → tag v1.0          AGENT_POC_OPS.RELEASE.AGENTS_REPO  (read-only copy)
   SALES_AGENT_POC.agent.yaml ──push──►                ──FETCH──►       │
   (references AGENT_POC_DEV.*)                                         ▼  RELEASE_AGENT('SALES_AGENT','v1.0','QA','qa',TRUE)
        │                                                         read spec @ tag → apply ENV_MAPPING (DEV→QA)
        │ agent-save / Deploy                                     → @RELEASE_STAGE/SALES_AGENT/QA/v1.0/agent_spec.yaml
        ▼                                                         → CREATE AGENT / ADD VERSION FROM stage (comment 'git v1.0')
 AGENT_POC_DEV.SALES.SALES_AGENT                                  → alias 'qa' + DEFAULT_VERSION → GRANT USAGE → RELEASE_LOG
   LIVE = work in progress                                        ▼
                                                           AGENT_POC_QA.SALES.SALES_AGENT  (frozen versions only)
```

**The rules the POC demonstrates:**
1. **One authored file.** `cortex_project/SALES_AGENT_POC.agent.yaml` is written against DEV objects. QA (and later PRD) specs are *generated* from it with the `ENV_MAPPING` table.
2. **Only reviewed code reaches QA.** QA versions are created only from **Git tags**, by `RELEASE_AGENT`.
3. **QA is never edited by hand.** That means no LIVE edits and no Deploy button. Testers (`AGENT_POC_QA_ROLE`) can only run the agent.
4. **No hardcoded `VERSION$N`.** Every version has the comment `git <tag>`. Promotion and rollback mean "release tag X again", and running it twice is harmless.
5. **Manual = CI.** `poc/sql/20_release_to_qa.sql` and `poc/ci/release-qa.yml` make the same procedure call.

## Files

| File | Purpose | Run as |
|---|---|---|
| `sql/01_setup_infra.sql` | Databases (DEV, QA, OPS), schemas, roles, grants | ACCOUNTADMIN |
| `sql/02_setup_git.sql` | API integration + read-only `GIT REPOSITORY` (public repo; private-repo variant commented) | ACCOUNTADMIN |
| `sql/03_semantic_views.sql` | `SALES_SV` in DEV and QA | ACCOUNTADMIN |
| `sql/04_release_framework.sql` | `ENVIRONMENTS`, `ENV_MAPPING`, `RELEASE_LOG`, `RELEASE_STAGE`, `RELEASE_AGENT` procedure | ACCOUNTADMIN |
| `sql/10_dev_bootstrap.sql` | Create the DEV agent with SQL, if you don't use the workspace | AGENT_POC_DEV_ROLE |
| `sql/20_release_to_qa.sql` | **The release ("CI") step** for one tag | AGENT_POC_RELEASE_ROLE |
| `sql/30_test_qa.sql` | Verify versions, aliases and spec contents; smoke tests | AGENT_POC_QA_ROLE |
| `sql/40_rollback_qa.sql` | Roll back to v1.0, roll forward to v1.1, check that repeating changes nothing | AGENT_POC_RELEASE_ROLE |
| `sql/99_cleanup.sql` | Drop everything | ACCOUNTADMIN |
| `tests/smoke_questions.yaml` | Expected answers for the smoke tests | — |
| `ci/release-qa.yml` | GitHub Actions workflow (phase 2) | — |
| `../cortex_project/SALES_AGENT_POC.agent.yaml` | **The DEV spec you author** (target: `AGENT_POC_DEV.SALES.SALES_AGENT`) | — |

Open each SQL file in a Snowsight worksheet and run it all. Every script sets its own role and warehouse.

## Runbook

### Step 0: Prerequisites (once)
- [ ] Confirm the repo URL in `sql/02_setup_git.sql` (assumed: `https://github.com/sfc-gh-pmazzette/SnowflakeGitWorkspace.git`).
- [ ] Make the repo **public** for the duration of the POC, or use Option B in `02` with a read-only token.
- [ ] Commit and push the current workspace content (including `poc/` and `SALES_AGENT_POC.agent.yaml`) to `main` from the workspace Git panel.

### Step 1: Set up Snowflake (once)
Run `01` → `02` → `03` → `04`.
**Expected:** `02` lists `SALES_AGENT_POC.agent.yaml` under `branches/main/cortex_project/`, and `04` shows 2 environments and 2 mapping rows.

### Step 2: Author in DEV
1. Open `cortex_project/SALES_AGENT_POC.agent.yaml` and create the DEV agent. Either:
   - in the terminal: `cortex agent-studio agent-save --file-path cortex_project/SALES_AGENT_POC.agent.yaml`, **or**
   - click Deploy (each click creates a DEV version, which is fine in DEV), **or**
   - run `sql/10_dev_bootstrap.sql`.
2. Chat with it: `cortex agents run AGENT_POC_DEV.SALES.SALES_AGENT "Which 5 nations have the highest revenue?"`
3. Edit the file and save again until you're happy.

### Step 3: Review and tag v1.0 (Git)
1. Workspace Git panel: create branch `feature/v1.0`, commit, push.
2. GitHub: open a PR to `main`, review, merge.
3. GitHub: create the tag **`v1.0`** on `main` (Releases → Draft a new release → new tag).

### Step 4: Release v1.0 to QA
Run `20` with `SET RELEASE_TAG = 'v1.0';`.
**Expected:** `AGENT_POC_QA.SALES.SALES_AGENT: v1.0 -> VERSION$1 (CREATED), alias=qa, default=True`

### Step 5: Test QA
Run `30`. **Expected:** `VERSION$1` has comment `git v1.0` and alias `qa` and is the default; `REFERENCES_DEV = FALSE`; the smoke answers match `tests/smoke_questions.yaml`.

### Step 6: Second iteration, rollback and repeatability
1. In DEV, change the instructions, e.g. add *"When showing revenue over time, include month-over-month % change."* Save, test, then do **Step 3** with `v1.1`.
2. Run `20` with `v1.1`. **Expected:** `VERSION$2 (IMPORTED)`, and the `qa` alias moves to it.
3. Run `40`. **Expected:** rolling back to v1.0 gives `REUSED` (no new version); releasing v1.1 twice gives `REUSED` (no duplicate); the log shows every action.

### Step 7 (optional): Real CI
Copy `ci/release-qa.yml` to `.github/workflows/`, create a service user with key-pair auth and `AGENT_POC_RELEASE_ROLE`, add the 3 repository secrets, then push a tag `v1.2`. The workflow makes the same call as `20`.

### Step 8: Clean up
Run `99`, then make the repo private again.

## What to check and record (unverified behaviors the POC tests)

| # | Question | Where it shows | Fallback if it fails |
|---|---|---|---|
| 1 | Does `CREATE AGENT … FROM @stage` / `ADD VERSION FROM @stage` accept a folder containing only `agent_spec.yaml`? | Step 4 / 6 | Check the docs for the expected manifest, or compare with `LIST snow://agent/AGENT_POC_DEV.SALES.SALES_AGENT/versions/live/` and copy that layout in `RELEASE_AGENT` step 4 |
| 2 | Can `MODIFY VERSION VERSION$1 SET COMMENT` be used after `CREATE AGENT … FROM`? | Step 4 | Replace the comment lookup with the first version, or log-based lookup |
| 3 | Does `SET ALIAS` move an alias that's already used? (The procedure falls back to `UNSET ALIAS` on the previous holder) | Step 6 | Adjust the procedure's alias block |
| 4 | Does `DATA_AGENT_RUN('…!qa')` accept an alias? | Step 5 | Use the `VERSION$N` from `SHOW VERSIONS` |
| 5 | Does `DESCRIBE AGENT` expose an `agent_spec` column? | Step 5 | Inspect `@RELEASE_STAGE/…/agent_spec.yaml` instead |
| 6 | Can the release role read Git through `AGENTS_REPO` from inside a procedure (`EXECUTE AS CALLER`)? | Step 4 | Grant missing privileges as reported in the error / `RELEASE_LOG` |

If something fails, the error is in the `CALL` result and in `AGENT_POC_OPS.RELEASE.RELEASE_LOG` (`STATUS = 'FAILED'`).

## Moving to PRD
- Add a `PRD` row to `ENVIRONMENTS`, plus its rows in `ENV_MAPPING` (database and warehouse names).
- Use Option B in `02` (private repo, read-only token) and a dedicated service user.
- PRD job: `CALL RELEASE_AGENT('SALES_AGENT', '<tag>', 'PRD', 'production', TRUE)`, behind an approval gate (a GitHub environment) and only for tags already validated in QA.
- If PRD is a separate Snowflake account, deploy `01`/`02`/`04` there. The procedure and process stay identical.
