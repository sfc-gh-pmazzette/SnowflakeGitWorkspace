# Agent release framework: production-readiness checklist

The POC proved that the release mechanics work: Git tag → frozen QA version → aliases moved → rollback (see `poc/RELEASE_GUIDE.md`). Making it production-ready is mostly about **decisions** and **hardening**.

For each item, record the decision, an owner and a status. The suggested defaults are starting points, not decisions.

Status legend: ☐ open · ◐ in progress · ☑ decided/done

---

## 1. Architecture: decide first (everything else depends on it)

| # | Status | Question | Suggested default | Decision / owner |
|---|---|---|---|---|
| 1.1 | ☐ | **One account with separate databases, or one Snowflake account per environment?** | Follow the existing platform standard. If PRD is already its own account, use the simpler variant (guide §6.4: no `ENV_MAPPING`) | |
| 1.2 | ☐ | Which environments (DEV / QA / PRD / UAT), and who owns each? | DEV → QA → PRD | |
| 1.3 | ☐ | Where does the release framework live, and which role owns it? (It replaces `AGENT_POC_OPS.RELEASE`) | A dedicated platform database owned by a platform/ops role | |
| 1.4 | ☐ | One shared framework for all teams and agents, or one per team? | One shared framework, with an agent registry table | |

## 2. Scope of a release

| # | Status | Question | Suggested default | Decision / owner |
|---|---|---|---|---|
| 2.1 | ☐ | **Do semantic views go into the same release as the agent?** | Yes, as phase 2: YAML in Git, deployed before the agent | |
| 2.2 | ☐ | Cortex Search, custom tools (procedures/UDFs), MCP servers: in or out? | Out at first, managed separately as SQL in Git | |
| 2.3 | ☐ | What change policy applies to objects without versions (semantic views, search services)? | Backward-compatible changes only; a new object name for breaking changes | |
| 2.4 | ☐ | Release the agent's display profile (name, avatar, color)? | Yes, a small addition (`ALTER AGENT … SET PROFILE`) | |
| 2.5 | ☐ | Release order and behaviour when one step fails | Search → semantic view → agent; stop at the first failure; log each step | |

## 3. Git conventions

| # | Status | Question | Suggested default | Decision / owner |
|---|---|---|---|---|
| 3.1 | ☐ | One repo for everything, or one per team or domain? | One per team or domain | |
| 3.2 | ☐ | **Tag convention** when there are several agents: repo-wide `v1.2`, or per agent `sales_agent/v1.2`? | Per agent; the procedure's tag check must then allow `/` | |
| 3.3 | ☐ | Folder and file layout, and a release manifest? | Keep `cortex_project/`; add `release.yaml` listing the components and their order | |
| 3.4 | ☐ | Branch strategy | Feature branches → `main` → tags | |
| 3.5 | ☐ | Does the GitHub plan support rulesets on **private** repos? | Confirm with the GitHub admin | |
| 3.6 | ☐ | Who may create `v*` tags? | The release-manager team only (tag ruleset) | |

## 4. Security

| # | Status | Question | Suggested default | Decision / owner |
|---|---|---|---|---|
| 4.1 | ☐ | **How does Snowflake read a private repo?** | A read-only fine-grained token in a Snowflake secret, with rotation (Option B in `02_setup_git.sql`) | |
| 4.2 | ☐ | How does CI log in to Snowflake? | A service user with key-pair authentication and a network policy | |
| 4.3 | ☐ | Final roles and grants in each environment (developer, release, consumer, admin) | Least privilege; only the release role can create versions in QA and PRD | |
| 4.4 | ☐ | Who may run `RELEASE_AGENT` in PRD? | Only the CI service user; humans for emergencies, with a documented break-glass procedure | |
| 4.5 | ☐ | Should the procedure run with the caller's or the owner's privileges? | Owner's (`EXECUTE AS OWNER`) in PRD, so callers need only `USAGE` on the procedure | |
| 4.6 | ☐ | Set the repo back to private after the POC | Yes, now | |

## 5. Quality gates and approvals

| # | Status | Question | Suggested default | Decision / owner |
|---|---|---|---|---|
| 5.1 | ☐ | **What must pass before QA → PRD?** | An automated evaluation (native agent evaluation or smoke tests) above an agreed threshold, plus human sign-off | |
| 5.2 | ☐ | Where is the PRD approval enforced? | A GitHub "environment" with required reviewers on the PRD job | |
| 5.3 | ☐ | Must a tag be validated in QA before it can go to PRD? | Yes: check `RELEASE_LOG` for a QA `SUCCESS` (plus a test result) for the same tag | |
| 5.4 | ☐ | Automatic YAML or spec validation on each pull request? | Yes, a CI check (lint, plus a dry-run against DEV) | |

## 6. Operations

| # | Status | Question | Suggested default | Decision / owner |
|---|---|---|---|---|
| 6.1 | ☐ | Rollback runbook, and who can trigger it | Re-release the previous tag; documented runbook; the release role or CI | |
| 6.2 | ☐ | Monitoring after a release | Agent observability and usage, error rates, user feedback | |
| 6.3 | ☐ | Retention of old agent versions, and cleanup | Keep the last N versions, plus every one that holds an alias | |
| 6.4 | ☐ | Release log: retention, central view across accounts, alerting on `FAILED` | Keep it; alert CI or the team channel on failures | |
| 6.5 | ☐ | Canary or pilot releases in PRD? | Optional `canary` alias with `SET_DEFAULT = FALSE` | |
| 6.6 | ☐ | Release cadence and change management (ITSM ticket, release notes) | GitHub releases as release notes; link to the change ticket | |

## 7. Hardening the procedure (`RELEASE_AGENT`)

| # | Status | Item | Notes |
|---|---|---|---|
| 7.1 | ☐ | Make the hardcoded parts configurable: framework location (`OPS`/`REPO`/`STAGE`), safety check driven by `ENV_MAPPING`, repo, tag pattern | Guide §6.3, "Hardcoded in the POC" |
| 7.2 | ☐ | Change detection: skip import when the spec is identical; never re-index search services unnecessarily | |
| 7.3 | ☐ | Clear error messages and return codes for CI | |
| 7.4 | ☐ | Tests for the framework itself: a test agent, repeat-safety tests, rollback tests | Run `poc/sql/40_rollback_qa.sql` (not yet executed in the POC) |
| 7.5 | ☐ | Version the framework itself (its own repo or folder, deployed like code) | |
| 7.6 | ☐ | Behaviours still to confirm: alias move without `UNSET`, `DATA_AGENT_RUN('…!alias')`, `agent_spec` column in `DESCRIBE AGENT` | README "What to check", risks #3–5 |

## 8. People and process

| # | Status | Question | Decision / owner |
|---|---|---|---|
| 8.1 | ☐ | Who are the developers, reviewers and release managers for each agent? | |
| 8.2 | ☐ | Training: Git basics, `RELEASE_GUIDE.md`, the rollback runbook | |
| 8.3 | ☐ | Is the Deploy button allowed in DEV? (It creates a version on every click; `agent-save` is preferred) | |
| 8.4 | ☐ | How are urgent fixes handled (fast-track review, same tag rules)? | |

---

## Suggested order

1. **Architecture:** 1.1–1.3.
2. **Security:** 4.1, 4.2, 4.6.
3. **Quality gate and PRD approval:** 5.1–5.3.
4. **Tag and repo conventions:** 3.1–3.2, before a second agent is added.
5. **Semantic views:** 2.1, 2.3.
6. **Hardening and operations:** sections 6 and 7.
