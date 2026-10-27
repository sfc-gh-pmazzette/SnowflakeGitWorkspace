# How to release a change to the Sales agent: a developer's guide

This guide walks you through the full journey of one change to the agent, from your first edit to the version testers use. No DevOps background is assumed. A short glossary is at the end.

---

## 1. The big picture

There are **three places**, each with a clear job:

| Place | What it is | Who changes it |
|---|---|---|
| **Your workspace** (`SnowflakeGitWorkspace` in Snowsight) | Your personal desk: where you edit the agent's file and try it out | You |
| **GitHub** (`github.com/sfc-gh-pmazzette/SnowflakeGitWorkspace`) | The shared, official archive of the agent's file, with its full history and approvals | You propose; a reviewer approves |
| **Snowflake environments** | Where the agent actually runs: **DEV** (your test copy) and **QA** (the copy testers use; later **PRD** for real users) | DEV: you. QA/PRD: **only** the release procedure |

The one rule to remember:

> **You only ever edit one file and test it in DEV. Everything else (QA, and later PRD) gets a copy of that file automatically, and only after the change has been reviewed and labelled.**

The file is `cortex_project/SALES_AGENT_POC.agent.yaml`. It describes the agent: its instructions, sample questions, and which data it uses. It's written for DEV and points at DEV data. When it's released, the DEV names are swapped for QA names automatically.

```
 Workspace (you)              GitHub                         Snowflake
 edit + test in DEV  ──push──► branch → PR → merge → tag ──► release procedure ──► QA frozen version
```

### 1.1 Workflow at a glance: actors and actions

```
 PHASE        ACTOR              ACTION                                         WHERE
 ─────────────────────────────────────────────────────────────────────────────────────────────
 1 AUTHOR     Developer          1.1 pull main → new branch                      Workspace (Changes tab)
              Developer          1.2 edit SALES_AGENT_POC.agent.yaml             Workspace
              Developer          1.3 agent-save → test → repeat                  DEV agent (LIVE)
 ─────────────────────────────────────────────────────────────────────────────────────────────
 2 REVIEW     Developer          2.1 commit + push branch                        Workspace → GitHub
              Developer          2.2 open pull request                           GitHub
              Reviewer           2.3 review diff → approve → merge into main     GitHub (rulesets enforce)
              Release manager    2.4 tag v1.2 on main                            GitHub (tag ruleset)
 ─────────────────────────────────────────────────────────────────────────────────────────────
 3 RELEASE    Release mgr / CI   3.1 CALL RELEASE_AGENT('SALES_AGENT','v1.2','QA',…)  Snowflake / GitHub Actions
              Release framework  3.2 fetch → read @tag → DEV→QA → stage file      Snowflake (OPS)
              Release framework  3.3 frozen VERSION$N 'git v1.2' → alias + default QA agent
              Release framework  3.4 grant + log                                 RELEASE_LOG
 ─────────────────────────────────────────────────────────────────────────────────────────────
 4 VALIDATE   Tester             4.1 smoke tests on alias qa                     QA agent
   ↳ issue    Release manager    4.2 re-release previous tag (rollback)          Snowflake
   ↳ OK       Release mgr / CI   4.3 same call with 'PRD', 'production'          Snowflake (PRD)
```

| Actor | Who or what |
|---|---|
| **Developer** | Writes and tests the change |
| **Workspace** | The Snowsight Git workspace (`SnowflakeGitWorkspace`): editor + Changes tab |
| **DEV agent** | `AGENT_POC_DEV.SALES.SALES_AGENT` (LIVE draft) |
| **Reviewer** | Approves pull requests (not the author) |
| **Release manager / CI** | Runs the release call (manually, or GitHub Actions on a tag) |
| **Release framework** | In Snowflake (`AGENT_POC_OPS.RELEASE`): `AGENTS_REPO` (read-only Git copy), `RELEASE_AGENT`, `ENV_MAPPING`, `RELEASE_STAGE`, `RELEASE_LOG` |
| **QA agent** | `AGENT_POC_QA.SALES.SALES_AGENT`: frozen versions only |
| **Tester** | `AGENT_POC_QA_ROLE`: can run the agent, never edit it |

#### Phase 1: Author (the developer works alone, in DEV)

**1.1 Pull `main`, then create a new branch.**
`main` is the official, approved version of the agent's file. *Pull* downloads the latest approved version into your workspace, so you start from what everyone else has. Then create a **branch**, a private working copy named after your change (e.g. `feature/v1.2-mom-growth`). Anything you do on it stays out of the official version until it's approved.
*Where:* Snowsight workspace → **Changes** tab → **Pull**, then branch dropdown → **+ New**.

**1.2 Edit `SALES_AGENT_POC.agent.yaml`.**
This is the **only** file you ever change. It describes the agent: its instructions, sample questions, and which data it uses. It's written for DEV, so it refers to `AGENT_POC_DEV…` objects. Leave those names as they are: the release step converts them for QA and PRD automatically.
*Where:* the workspace editor. Save when done.

**1.3 Run `agent-save`, test, repeat.**
`agent-save` copies your file into the **DEV agent's draft** (its LIVE version), so you can try the change for real. Ask it a few questions and check the answers. If something's off, edit, save and test again, as many times as you like; DEV is your sandbox, and nobody else depends on it.
*Where:* the CoCo chat (`! cortex agent-studio agent-save …`, `! cortex agents run …`), or **AI & ML » Agents**.

#### Phase 2: Review (the change becomes official, in GitHub)

**2.1 Commit and push the branch.**
A **commit** is a permanent snapshot of your change, with a short message explaining it. **Pushing** uploads your branch and its commits to GitHub, where others can see them. Until you push, your work exists only in your workspace and is invisible to everyone, including Snowflake's release process.
*Where:* Changes tab → tick the file → message → **Commit** → **Push**.

**2.2 Open a pull request.**
A **pull request** (PR) asks for your branch to be added to `main`. GitHub shows exactly which lines changed. In the description, explain what you changed and how you tested it in DEV.
*Where:* GitHub → **Compare & pull request**.

**2.3 Review the diff, approve, merge into `main`.**
A **reviewer**, someone other than the author, checks that:

- only the intended file changed;
- it still points at DEV names;
- nothing sensitive was added.

They then approve and **merge**, which makes the change part of `main`. GitHub **rulesets** (section 5) guarantee this is the only way to change `main`: direct pushes, including from Snowsight, are rejected.
*Where:* GitHub, on the PR page.

**2.4 Tag `v1.2` on `main`.**
`main` keeps changing as new PRs are merged. A **tag** is a permanent label on this exact approved version, and it's what the release reads. Only release managers can create `v*` tags, and a tag can never be moved or deleted, so `v1.2` always means the same file.
*Where:* GitHub → **Releases → Draft a new release** → new tag `v1.2`, target `main`.

#### Phase 3: Release (Snowflake builds the QA version)

**3.1 Call `RELEASE_AGENT`.**
The release manager, or an automatic CI job triggered by the new tag, runs **one** command naming the agent, the tag, the target environment and the label to move:

```sql
CALL AGENT_POC_OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', 'v1.2', 'QA', 'qa', TRUE);
```

This is the **only** way anything gets into QA (or PRD). Nobody edits those agents by hand.
*Where:* a Snowflake worksheet (`poc/sql/20_release_to_qa.sql`), or GitHub Actions (`poc/ci/release-qa.yml`).

**3.2 Fetch, read at the tag, convert DEV → QA, write to the stage.**
Inside the procedure:

1. It refreshes Snowflake's **read-only copy** of GitHub, so the new tag is visible.
2. It opens the agent's file **as it was at `v1.2`**.
3. It replaces every DEV name with its QA equivalent, using the `ENV_MAPPING` table, and refuses to continue if any DEV reference is left.
4. It saves the result as `agent_spec.yaml` in `RELEASE_STAGE`, a file folder inside Snowflake, so you can always inspect exactly what was released.

**3.3 Create the frozen `VERSION$N`, labelled `git v1.2`, and move the alias and default.**
The procedure turns that file into a **version** of the QA agent, e.g. `VERSION$3`. A version is **frozen**: it can never be edited, only pointed at. The version's note `git v1.2` permanently links it to the GitHub tag. The procedure then moves:

- the **`qa` alias**, the label testers and apps use;
- the **default version**, what you get when you don't name a version, e.g. in CoWork.

Both now point to the new version, and older versions stay available. If the tag was already released, nothing new is built: the existing version is reused. That's what makes rollback instant.

**3.4 Grant access and log.**
The procedure gives the tester role permission to run the agent, and writes a row to `RELEASE_LOG`: who released it, when, which tag, which version, and whether it worked. On failure, the error message is stored there too.

#### Phase 4: Validate (testers check QA)

**4.1 Smoke tests on the `qa` alias.**
Testers run a few known questions against the version the `qa` label points to (`poc/sql/30_test_qa.sql`, or chat with the agent) and compare the answers with the expected ones. They can run the agent but **can't change it**.

**4.2 If there's a problem: re-release the previous tag (rollback).**
The release manager makes the **same call** with the last good tag:

```sql
CALL AGENT_POC_OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', 'v1.1', 'QA', 'qa', TRUE);
```

The procedure finds the existing `v1.1` version by its note and moves the `qa` label and the default back to it. It takes seconds and rebuilds nothing. The developer then fixes the issue through the normal cycle with a new tag, e.g. `v1.2.1`.

**4.3 If everything is OK: promote to PRD.**
The same tag is released to production with the same procedure, behind an approval gate:

```sql
CALL AGENT_POC_OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', 'v1.2', 'PRD', 'production', TRUE);
```

PRD gets exactly the file that was reviewed and tested in QA, converted to PRD names. If PRD is a separate account with identical names, no conversion is needed (section 6.4).

#### In one sentence per phase

- **Author:** the developer changes one file and tests it in DEV.
- **Review:** a second person approves it in GitHub, and a release manager labels the approved version with a tag.
- **Release:** one procedure call turns that tag into a frozen, labelled version in QA, and records it.
- **Validate:** testers check it; problems are fixed by moving the label back; success means the same call is made for PRD.

The detailed, click-by-click version of phases 1–3 for developers is in section 3.

### 1.2 Scope: what this process covers, and what it doesn't

**Covered**

| Item | How |
|---|---|
| The **agent specification** (`SALES_AGENT_POC.agent.yaml`): instructions, sample questions, model, tools and their resource references | Authored in DEV, reviewed in GitHub, released from a tag by `RELEASE_AGENT` |
| **Environment-specific names inside the spec** (databases, warehouse) | Translated automatically from `ENV_MAPPING` |
| **Agent versions, aliases and the default** in QA (and later PRD) | Created and moved only by `RELEASE_AGENT` |
| **Rollback** of the agent | Re-release an older tag: instant, nothing rebuilt |
| **Access for the environment's consumer role** (`USAGE` on the agent) | Granted by `RELEASE_AGENT` |
| **Audit trail** | `RELEASE_LOG` in Snowflake, plus PR, commit and tag history in GitHub |

**Not covered (today)**

| Item | How it's handled today | Could it be added? |
|---|---|---|
| **Semantic views** (e.g. `SALES_SV`) | Created separately in each environment by `poc/sql/03_semantic_views.sql` | **Yes, with little effort.** The definition can be kept as a YAML file in Git, next to the agent spec. The `cortex agent-studio sv-*` commands already support reading, saving, validating and deploying semantic-view YAML for authoring and testing in DEV. For QA and PRD, the release procedure would read the YAML at the tag, apply `ENV_MAPPING`, and deploy it with `SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML`, **before** the agent |
| **Cortex Search services** | Not part of the POC; created and maintained manually in each environment | **Possible, but harder; not recommended as a first step.** The definition can be kept in Git as a SQL file and deployed from the tag (e.g. `EXECUTE IMMEDIATE FROM @repo/tags/<tag>/…` with placeholders). However: **(1)** `cortex agent-studio` has no commands for search services, so developers author and test them with plain SQL; **(2)** recreating a service **re-indexes its data**, which costs compute and time, and the service may not answer queries until indexing finishes, so it should only be redeployed when its definition changes; **(3)** each environment needs its own source data to index |
| Custom tools (procedures/UDFs), MCP servers | Managed separately | Same idea as Cortex Search: SQL files in Git, deployed from the tag |
| Warehouses, databases, roles and grants (other than agent `USAGE`) | One-time setup scripts (`01`–`04`) | Usually kept as infrastructure setup rather than per-release changes |
| Agent display name, avatar, color (`PROFILE`) | Not set by the release | A small addition (`ALTER AGENT … SET PROFILE`) |
| Automated quality gate (block a release if tests fail) | Manual smoke tests (`30_test_qa.sql`) | A CI step or native agent evaluation before moving the alias |
| Approval before PRD | Outside the procedure | A CI or GitHub "environment" approval step |
| Deleting old agent versions | Not done | A periodic cleanup, if needed |

> **Important: only agents have versions.** Agents keep frozen versions side by side, so rollback just moves a pointer. Semantic views and Cortex Search services keep **one current definition**: deploying a new one replaces it, and rolling back means redeploying the old tag's definition. Releasing them would also mean that an older agent version could point at a newer semantic view. Keep their changes **backward-compatible** (add, don't rename or remove), or give breaking changes a **new object name**.

---

## 2. Before you start (one-time, done by an admin)

You don't need to do these yourself, but they must exist:

- the DEV and QA environments, with their data (`poc/sql/01_setup_infra.sql`, `03_semantic_views.sql`);
- the connection that lets Snowflake **read** GitHub (`02_setup_git.sql`);
- the release procedure `RELEASE_AGENT` and its log (`04_release_framework.sql`);
- protection rules on GitHub so nobody can change `main` directly (section 5).

---

## 3. The release cycle: 8 steps for every change

Example change: *"When showing revenue over time, include the month-over-month % change."* The version name in this example is **v1.2**.

### Step 1: Start a separate working copy (a branch)

**Why:** your changes stay out of the official version until they're approved.

**Where:** Snowsight → **Projects » Workspaces** → `SnowflakeGitWorkspace` → **Changes** tab.

1. **Get up to date:** make sure you're on `main` (the official line), then click **Pull** to download the latest approved files.
2. **Create the branch:** open the branch dropdown, click **+ New**, and name it after what you're doing, e.g. `feature/v1.2-mom-growth`. Click **Create**.

**You'll see:** the branch name at the top of the Changes tab is now your new branch.

### Step 2: Edit the agent's file

**Where:** the workspace file explorer → `cortex_project/SALES_AGENT_POC.agent.yaml`.

- Change what you need. Here, add a line under `response:`:

  ```yaml
      When showing revenue over time, include month-over-month % change.
  ```

- **Save** the file.

Keep the DEV names (`AGENT_POC_DEV...`) as they are; the release swaps them automatically. **Don't** create a separate file for QA.

At this point only the file has changed; nothing in Snowflake has.

### Step 3: Try it in DEV

**Why:** to see that the change behaves as you expect before asking anyone to review it.

1. **Update the DEV agent with your file.** In the CoCo chat, type:

   ```
   ! cortex agent-studio agent-save --file-path cortex_project/SALES_AGENT_POC.agent.yaml
   ```

   This updates only the **draft** of the DEV agent. Avoid the editor's **Deploy** button for this: it also creates a numbered version every time you click.

2. **Ask the DEV agent a question:**

   ```
   ! cortex agents run AGENT_POC_DEV.SALES.SALES_AGENT "Revenue by month for the first half of 1997"
   ```

   You can also chat with it under **AI & ML » Agents**.

3. **Not right?** Go back to Step 2, adjust, save, and repeat. You can do this as many times as you like; DEV is your sandbox.

**You'll see:** the answer now includes a month-over-month % change.

### Step 4: Save your change in Git (commit) and send it to GitHub (push)

**Why:** a **commit** is a permanent, labelled snapshot of your change. **Pushing** uploads it to GitHub so it can be reviewed.

**Where:** the **Changes** tab.

1. **Choose the files:** tick **only** the files you meant to change, here `SALES_AGENT_POC.agent.yaml`.
2. **Describe the change:** write a short message, e.g. `SALES_AGENT v1.2 - add month-over-month % change`.
3. **Commit,** then **Push**.

**You'll see:** on GitHub, under **Branches**, your branch with your commit.

If you're on `main` by mistake, GitHub rejects the push (see section 5). Create a branch and push that instead.

### Step 5: Ask for approval (open a pull request)

**Why:** a **pull request** (PR) is a request to add your change to the official version. It shows a reviewer exactly what changed, line by line.

**Where:** GitHub, in your repo.

1. **Open the PR:** click the yellow **Compare & pull request** banner (or **Pull requests → New**). Check the base is `main` and compare is your branch.
2. **Explain it:** give it a title (`SALES_AGENT v1.2`) and a short description: what you changed, and how you tested it in DEV.
3. **Ask for a review:** assign a reviewer, who must be someone other than you.

**The reviewer checks:**

- only the intended file changed;
- it still points at DEV names;
- nothing sensitive is in it.

### Step 6: Accept the change (merge)

**Why:** merging makes your change part of the official version (`main`).

**Where:** the PR page on GitHub, once it's approved.

1. Click **Merge pull request**, then **Confirm merge**.
2. Optionally, click **Delete branch**; you no longer need it.
3. Back in the workspace: on the Changes tab, switch to `main` and click **Pull**, so your desk matches the official version again.

### Step 7: Label the approved version (tag)

**Why:** `main` keeps moving as others merge changes. A **tag** is a permanent label on this exact approved version, and it's the only thing the release procedure reads.

**Who:** a release manager (see the tag rules in section 5).

**Where:** GitHub → **Releases** → **Draft a new release**.

1. **Name the tag:** under **Choose a tag**, type `v1.2` and choose **Create new tag on publish**.
2. **Point it at `main`:** set **Target** to `main`. Never use your branch.
3. **Publish:** title it `SALES_AGENT v1.2` and click **Publish release**.

**Rules for tags:**

- **Never reuse or move a tag.** If something needs fixing, make a new one, e.g. `v1.2.1`.
- Use a higher number for each release: `v1.0`, `v1.1`, `v1.2`, …

### Step 8: Release to QA

**Why:** this copies the approved, labelled file into QA as a version that can never be edited.

**Who:** whoever has the release role (`AGENT_POC_RELEASE_ROLE`), or later an automatic job (CI) that does this as soon as a tag is created (`poc/ci/release-qa.yml`).

**Where:** a Snowsight worksheet, `poc/sql/20_release_to_qa.sql`.

1. **Set the tag:** `SET RELEASE_TAG = 'v1.2';`
2. **Run the script.** It makes a single call:

   ```sql
   CALL AGENT_POC_OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', 'v1.2', 'QA', 'qa', TRUE);
   ```

**What happens behind the scenes:**

1. Snowflake refreshes its read-only copy of GitHub.
2. It reads the file exactly as it was at tag `v1.2`.
3. It replaces DEV names with QA names, and checks that no DEV name is left.
4. It creates a **frozen version** of the QA agent, e.g. `VERSION$3`, with the note `git v1.2`.
5. It moves the **`qa` label** and the **default** to that version, so testers get it automatically.
6. It records the release in `AGENT_POC_OPS.RELEASE.RELEASE_LOG`.

**You'll see:** a result like `v1.2 -> VERSION$3 (IMPORTED), alias=qa, default=True`.

**Afterwards:** testers run `poc/sql/30_test_qa.sql` (or chat with the QA agent) to confirm it works.

---

## 4. If something goes wrong in QA: roll back

Release the **previous** tag again:

```sql
CALL AGENT_POC_OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', 'v1.1', 'QA', 'qa', TRUE);
```

- **What it does:** nothing is rebuilt. The procedure finds the existing v1.1 version and moves the `qa` label back to it, which takes seconds.
- **Then fix the problem properly:** start again at Step 1 with a new version, e.g. `v1.2.1`.

---

## 5. Protecting `main` and release tags (GitHub)

You enforce this **on GitHub**, not in Snowsight. When the workspace pushes, it does so as **your GitHub user**, so any rule GitHub enforces on `main` also applies to pushes from Snowsight.

### 5.1 Protect `main` with a branch ruleset

**Where:** GitHub → your repo → **Settings** → **Rules** → **Rulesets** → **New ruleset** → **New branch ruleset**. Older repos have this under *Settings → Branches → Add branch protection rule*.

1. **Name:** `protect-main`. **Enforcement status:** **Active**.
2. **Target branches:** **Add target** → **Include default branch** (that's `main`).
3. **Bypass list:** leave it empty. Otherwise, admins can still push directly.
4. **Rules to enable:**

   | Rule | Effect |
   |---|---|
   | **Require a pull request before merging** | Nobody can push commits straight to `main`; changes arrive only through a PR |
   |   ↳ *Required approvals: 1* | Someone must approve the PR |
   |   ↳ *Dismiss stale approvals when new commits are pushed* | Changing the PR after approval needs a new approval |
   |   ↳ *Require approval of the most recent push by someone other than the author* (optional) | Authors can't approve their own changes |
   | **Block force pushes** | History on `main` can't be rewritten |
   | **Restrict deletions** | `main` can't be deleted |
   | **Require status checks to pass** (optional, later) | e.g. a CI check that validates the YAML before merging |

5. Click **Create**.

**From then on**, if you commit while on `main` in the workspace and click **Push**, GitHub rejects it with an error along the lines of *"protected branch… changes must be made through a pull request"*. Your commit stays in the workspace; create a branch from it and push that instead.

### 5.2 Protect release tags with a tag ruleset

The release procedure reads only **tags**, so protect those as well.

**Where:** **Settings → Rules → Rulesets → New ruleset → New tag ruleset**.

- **Target:** tag pattern `v*`.
- **Rules:** **Restrict creations** (only the release managers on the bypass list can create `v*` tags), **Restrict updates** and **Restrict deletions** (a published tag can't be moved or removed).
- **Bypass list:** a "release managers" team, or the account of your automated release job.

That way nobody can move or re-create `v1.1` after it's been released, so the QA comment `git v1.1` always matches what the tag points to.

### 5.3 Supporting measures

- **Limit who has write access:** **Settings → Collaborators and teams**. Developers get **Write**, so they can push branches and open PRs; only admins or release owners get **Maintain/Admin**.
- **GitHub App permissions:** the Snowflake app needs *Read and write* on code to push branches. That's fine, because rulesets still block `main`. Don't grant it admin rights.
- **Routine in the workspace:** always create the branch *before* editing (Step 1). If you forget, the rejected push tells you, and nothing reaches `main`.
- **Already in place on the Snowflake side:** releases read **only tags**, and only the release role can create QA versions. So even an unreviewed commit on `main` wouldn't reach QA until someone tagged it, and with the tag ruleset, only approved people can do that.

### 5.4 Quick test

After creating the ruleset, try to push a small commit while on `main` in the workspace. It should be rejected. Then push the same change on a branch and open a PR; that should work.

> **Note:** branch and tag rulesets are free for **public** repos. For **private** repos they need a paid GitHub plan (Team/Pro or above). Check your plan before relying on them once the repo is private again.

---

## 6. Behind the scenes: the release framework (for release managers and admins)

Developers don't need this section to follow the cycle above. It explains what the release step relies on, so release managers and admins can run, troubleshoot and adapt it.

### 6.1 The only thing a release manager runs

```sql
CALL AGENT_POC_OPS.RELEASE.RELEASE_AGENT('<AGENT>', '<tag>', '<ENV>', '<alias>', <set_default>);
-- e.g. CALL AGENT_POC_OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', 'v1.2', 'QA', 'qa', TRUE);
```

- The same call does a **release**, a **promotion** and a **rollback**; a rollback is just an older tag.
- A CI job (`poc/ci/release-qa.yml`) runs exactly this call.
- Nobody runs `CREATE AGENT`, `ADD VERSION`, `SET ALIAS` or `SET DEFAULT_VERSION` by hand on QA or PRD.

| Parameter | Meaning | Example |
|---|---|---|
| `AGENT_NAME` | Agent to release | `SALES_AGENT` |
| `GIT_TAG` | Approved version in GitHub | `v1.2` |
| `TARGET_ENV` | Environment (a row in `ENVIRONMENTS`) | `QA` |
| `ALIAS_NAME` | Label to move to the released version | `qa`, `production` |
| `SET_DEFAULT` | Also make it the default version (what CoWork uses) | `TRUE` |
| `SPEC_PATH` (optional) | Path of the spec file in the repo | `cortex_project/SALES_AGENT_POC.agent.yaml` |

### 6.2 Framework objects

**Custom objects** (built for this process), all in `AGENT_POC_OPS.RELEASE`:

| Object | Type | Purpose |
|---|---|---|
| `RELEASE_AGENT` | Stored procedure (Python) | The release logic (see 6.3) |
| `ENVIRONMENTS` | Table | For each environment: the database and schema where agents live, and the role that may run them (`DEV`, `QA`, later `PRD`) |
| `ENV_MAPPING` | Table | Text replacements applied to the DEV spec for each environment (e.g. `AGENT_POC_DEV.` → `AGENT_POC_QA.`, warehouse names) |
| `RELEASE_STAGE` | Internal stage (a file folder inside Snowflake) | The rendered spec for each release: `<AGENT>/<ENV>/<tag>/agent_spec.yaml` |
| `RELEASE_LOG` | Table | Audit trail: who released what, when, which tag, which version, result |

**Standard Snowflake objects** the process uses (created by the setup scripts, not custom code):

| Object | Purpose |
|---|---|
| `AGENT_POC_GIT_API` (API integration) | Allows Snowflake to talk to `github.com/sfc-gh-pmazzette/` |
| `AGENT_POC_OPS.RELEASE.AGENTS_REPO` (Git repository) | Snowflake's **read-only** copy of the GitHub repo; updated with `FETCH` |
| `AGENT_POC_DEV_ROLE`, `AGENT_POC_QA_ROLE`, `AGENT_POC_RELEASE_ROLE` | Build in DEV / run the agent in QA / create QA versions |
| Databases `AGENT_POC_DEV`, `AGENT_POC_QA`, `AGENT_POC_OPS`, semantic views, agents | The environments themselves |

**Outside Snowflake:** the GitHub rulesets (section 5) and, optionally, the CI workflow.

### 6.3 What `RELEASE_AGENT` does, step by step

1. **Refresh:** `ALTER GIT REPOSITORY … FETCH` makes new tags visible.
2. **Read:** opens `<SPEC_PATH>` **as it was at the tag**, from `@AGENTS_REPO/tags/<tag>/…`.
3. **Translate:** applies the `ENV_MAPPING` rows for the target environment, then fails if any DEV reference remains.
4. **Store:** writes the result to `@RELEASE_STAGE/<AGENT>/<ENV>/<tag>/agent_spec.yaml`.
5. **Create, import or reuse a version:**

   | Situation | What happens | `ACTION` in the log |
   |---|---|---|
   | Agent doesn't exist yet | `CREATE AGENT … FROM @stage` → `VERSION$1`, with comment `git <tag>` | `CREATED` |
   | New tag, and the agent still has a LIVE draft (always true right after creation) | Copy the spec into LIVE, then `COMMIT COMMENT = 'git <tag>'` | `IMPORTED_VIA_LIVE` |
   | New tag, no LIVE draft | `ADD VERSION FROM @stage COMMENT = 'git <tag>'` | `IMPORTED` |
   | Tag already released | Nothing imported; the existing version is found by its comment | `REUSED` |

6. **Promote:** moves `<alias>` to that version, and with `SET_DEFAULT = TRUE` also sets `DEFAULT_VERSION`.
7. **Grant:** gives `USAGE` on the agent to the environment's consumer role (from `ENVIRONMENTS`).
8. **Log:** writes a `SUCCESS` or `FAILED` row to `RELEASE_LOG`. On failure, the error is in `DETAILS`.

**Design choices:**

- **No hardcoded `VERSION$N`:** each version's comment `git <tag>` is the permanent link between GitHub and Snowflake.
- **Safe to re-run:** releasing the same tag twice creates no duplicate.
- **QA is never edited by hand:** only `RELEASE_ROLE` can create versions, and only from tags.
- **Why the LIVE step exists:** Snowflake rejects `ADD VERSION FROM` while an agent has a LIVE draft (error `099106`), and `CREATE AGENT` always leaves one. The first import after creation therefore goes through LIVE and commits it, which removes the draft.

**Hardcoded in the POC** (adapt for a real setup):

- The location of the framework itself: the constants `OPS`, `REPO`, `STAGE` (`AGENT_POC_OPS.RELEASE…`).
- The safety check for the text `AGENT_POC_DEV`. It's better derived from `ENV_MAPPING`.
- A single Git repo for all agents.
- Tag format: letters, digits, `.`, `_`, `-`. A per-agent convention like `sales_agent/v1.2` would need `/` allowed.

### 6.4 Simpler variant: one Snowflake account per environment, with the same names

If DEV, QA and PRD are **separate Snowflake accounts** with **identical** database, schema, warehouse and role names, the file in Git works unchanged in every account, so there's nothing to translate.

```
            GitHub tag v1.2
           /       |       \
   DEV account  QA account  PRD account      (each with its own AGENTS_REPO + RELEASE_AGENT)
   SALES.SALES  SALES.SALES SALES.SALES      (same names everywhere)
```

| | Single account (POC) | One account per environment |
|---|---|---|
| `ENV_MAPPING` + translate-and-check step | Needed | **Not needed** |
| `ENVIRONMENTS` table, `TARGET_ENV` parameter | Needed | **Not needed** (or a single row): the account you connect to *is* the environment |
| Git repo object, read at tag | Needed | Needed (one per account) |
| `RELEASE_STAGE` | Needed | Recommended (see note below) |
| Version lookup by `git <tag>` comment | Needed | Needed |
| LIVE workaround after first `CREATE` | Needed | Needed |
| Alias, default, grant, log | Needed | Needed (log per account) |
| CI | One connection | One connection per account |

**The simplified procedure:**

1. Fetch.
2. Read the spec at the tag.
3. Write it to the stage as `agent_spec.yaml`.
4. Create, import or reuse the version.
5. Set the alias and default.
6. Grant.
7. Log.

That's roughly half the current code. The call becomes, run in each account:

```sql
CALL OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', 'v1.2', 'qa', TRUE);          -- in the QA account
CALL OPS.RELEASE.RELEASE_AGENT('SALES_AGENT', 'v1.2', 'production', TRUE);  -- in the PRD account
```

**Note on the stage:** in principle you could import straight from Git (`ADD VERSION FROM @AGENTS_REPO/tags/v1.2/<folder>`) without a stage. What has been verified is a folder containing a file named **`agent_spec.yaml`**. The workspace tooling names files `<NAME>.agent.yaml`, and other file names haven't been verified. Keeping the small "copy to stage as `agent_spec.yaml`" step lets you keep the workspace naming.

**Trade-offs:**

- **Pro:** no translation, so less can go wrong, and the spec reads the same in every environment.
- **Con:** the framework (Git integration, repo object, procedure, log) must be set up in **every** account, and CI needs a separate connection for each one.
- **Watch out:** object names don't reveal the environment. Tell environments apart by the account name and by aliases (`qa`, `production`).

### 6.5 Moving to PRD

**Single-account model:**

- Add a `PRD` row to `ENVIRONMENTS`, plus its `ENV_MAPPING` rows.
- Run `RELEASE_AGENT('SALES_AGENT', '<tag>', 'PRD', 'production', TRUE)` from CI, using a service user with the release role.

**Account-per-environment model:** deploy the simplified framework in the PRD account and run the same call there.

**In both models:**

- **Git access:** use a **private** repo with a **read-only token** (Option B in `02_setup_git.sql`).
- **Approval gate:** allow only tags already validated in QA, behind an approval step (e.g. a GitHub "environment" with required reviewers).

---

## 7. Do and don't

| ✅ Do | ❌ Don't |
|---|---|
| Edit only `SALES_AGENT_POC.agent.yaml` | Create QA- or PRD-specific copies of the file |
| Test every change in DEV first | Edit the QA (or PRD) agent directly: in Snowsight, with SQL, or with Deploy |
| Use a new branch for each change | Commit directly to `main` |
| Write a clear commit message and PR description | Tag your branch instead of `main` |
| Create a new tag for every release | Reuse or move an existing tag |
| Pull `main` after merging | Forget to push: GitHub and Snowflake can't see unpushed work |

---

## 8. Glossary

| Term | Plain meaning |
|---|---|
| **Git** | A tool that keeps the full history of changes to files |
| **GitHub** | A website that stores a Git repository online for a team |
| **Repository (repo)** | The project folder tracked by Git, here containing the agent's file |
| **Branch** | A separate working copy where you can change things without affecting the official version |
| **`main`** | The official, approved branch |
| **Commit** | A saved, permanent snapshot of your changes, with a message |
| **Push / Pull** | Upload your commits to GitHub / download others' commits |
| **Pull request (PR)** | A request, shown on GitHub, to add your branch's changes to `main`; where review happens |
| **Merge** | Accepting a PR: the changes become part of `main` |
| **Tag** | A permanent label (e.g. `v1.2`) on one exact approved version |
| **Ruleset** | A GitHub setting that enforces rules on branches or tags (e.g. "no direct pushes to `main`") |
| **DEV / QA / PRD** | Development (you test), quality assurance (testers check), production (real users) |
| **LIVE (draft)** | The editable state of an agent; used only in DEV |
| **Version (`VERSION$N`)** | A frozen, uneditable snapshot of an agent, created at each release |
| **Alias** | A movable label (e.g. `qa`, `production`) pointing to one version |
| **Default version** | The version used when nobody specifies one (e.g. in CoWork) |
| **Release / promote** | Making a tagged version available in an environment |
| **Rollback** | Moving the label back to a previous version |
| **CI (continuous integration)** | An automatic job, e.g. on GitHub, that runs the release step when a tag is created |
