# .github (org automation)

Org-level automation + meta repo for the Marketrix organization: default issue/PR templates, the org-automation workflows that drive issue routing / label sync / stale-close / project-board sync, and the public org profile. The GitHub-meaningful content lives in the **nested** `.github/.github/` dir (workflows, ISSUE_TEMPLATE, PULL_REQUEST_TEMPLATE). Part of the Marketrix workspace — root `../CLAUDE.md` owns the dev workflow this repo automates (issue→PR→worktree→board, labels, board statuses, release/deploy); read it. This file covers only what's specific to `.github/`.

**Default branch: `main`** (service repos branch from `dev`). No buildable code, no CI here — pure metadata/automation. This repo is also the **cross-cutting issue tracker**: issues opened here auto-get `cross-cutting` and represent multi-repo work.

## Layout

```
.github/.github/
  workflows/            6 automation workflows (see below)
  ISSUE_TEMPLATE/       bug.yml, feature.yml, config.yml
  PULL_REQUEST_TEMPLATE.md
profile/README.md       public org profile (marketing landing page on github.com/Marketrix-ai)
```

No top-level `workflows/` dir, no org-shared reusable workflows, no `CODEOWNERS`, no standalone labels YAML, no `actions/` composite actions. The only reusable workflow these consume lives in **infra** (`project-sync-service.yml`).

## Workflows

All under `.github/.github/workflows/`. Five use `secrets.INFRA_PAT`; one (`auto-label`) uses the default `github.token`.

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **issue-router.yml** "Issue Router" | `issues: [opened]` | Routes a newly-filed issue by its checked repo boxes (see below). `INFRA_PAT`. |
| **auto-label.yml** "Auto Label" | `issues: [opened, edited]` | Adds `cross-cutting` if absent — "all issues in .github are cross-cutting by convention". Idempotent, local repo only. Uses **`github.token`** (not `INFRA_PAT`). |
| **create-branch.yml** "Create Branch" | `issues: [assigned]` | Legacy. Empty branch + draft PR per assignment (see caveat). `INFRA_PAT`. |
| **project-sync.yml** "Project Sync" | `issues: [opened, assigned, closed]`, `pull_request: [opened, closed]` | Thin caller → infra's reusable board-sync workflow. `secrets: inherit`. |
| **label-sync.yml** "Label Sync" | cron `0 6 * * 1` (**Mon 06:00 UTC**) + `workflow_dispatch` | Upserts the canonical label set into **every org repo**. `INFRA_PAT`. |
| **stale.yml** "Stale Issues" | cron `0 7 * * *` (**daily 07:00 UTC**) + `workflow_dispatch` | Stale-labels then closes inactive issues across **every org repo**. `INFRA_PAT`. |

### issue-router (the routing logic)
Scans the issue body for checked repo checkboxes among the fixed list `api app agent widget infra docs website monitor` (regex `^\s*-\s*\[x\]\s*<repo>\s*$`, case-insensitive — these are the `feature.yml` "Affected repos" boxes):
- **0 checked** → leave as-is (`exit 0`).
- **1 checked** → `gh issue create` in `Marketrix-ai/<repo>` (labels `feature` + `<repo>`), then **close this `.github` issue** as `not_planned` with a "Moved to <url>" redirect comment.
- **2+ checked** → keep this issue as the **tracking issue**; create one issue per repo (body `Part of <issue_url>`, labels `feature` + `<repo>`) and comment listing the URLs.

> Gotcha: the 2+ case makes **plain text-referenced** sub-issues ("Part of <url>"), **not** native GitHub sub-issue links. The router does **not** add `cross-cutting` itself — `auto-label` does.

### create-branch (legacy / problematic)
On assignment of a non-`cross-cutting` issue: checks out `main`, slugifies the title (lowercase, non-alnum→`-`, `cut -c1-50`), creates branch `<num>-<slug>`, pushes an **empty commit**, opens a **draft PR** (`--base main`, body `Closes #N`, assigned to the issue assignee), and comments checkout instructions. `cross-cutting` issues are skipped.

> **Caveat (empty-draft problem):** it fires on every non-cross-cutting assignment and bases the PR on **`main`** (not `dev`). When the developer follows the canonical manual branch/PR flow (root `CLAUDE.md`), this leaves an orphaned empty `Closes #N` draft. Still active but legacy — prefer the manual flow and close/ignore the auto-draft.

### label-sync
Iterates all org repos (`gh api /orgs/Marketrix-ai/repos --paginate`); per canonical label tries `gh label edit`, falling back to `gh label create` (idempotent upsert). Does **not** delete non-canonical labels. The canonical set is defined **inline** (no separate labels file) — see root `CLAUDE.md` for the label taxonomy; colors: `bug` d73a4a, `feature` 0075ca, `enhancement` a2eeef, `chore` e4e669, `documentation` 0e8a16, `cross-cutting` 7057ff, all 8 scope labels (`api`/`app`/`agent`/`widget`/`infra`/`docs`/`website`/`monitor`) 1d76db, `P0` b60205, `P1` d93f0b, `P2` fbca04, `stale` ededed.

### stale
`STALE_DAYS=60`, `CLOSE_DAYS=90`, `EXEMPT_LABELS=P0,cross-cutting`. Iterates all org repos, paginates open issues sorted `updated` asc, **skips PRs**. Per issue (P0/cross-cutting skipped entirely):
- `>90d` inactive → if already `stale`-labeled, close with the 90d comment; **else add `stale` AND close in the same run**.
- `60–90d` inactive → if not yet `stale`, add the label + a "closed in 30 days" comment.

Relies on `updated_at`, so any bot comment/edit resets the clock.

### project-sync (thin caller — has a latent bug)
Body is a `uses:` of the infra reusable workflow `Marketrix-ai/infra/.github/workflows/project-sync-service.yml@dev`, with `secrets: inherit`. The board logic lives in infra (see below).

> **Likely bug — flag if touching this.** Two problems vs. infra's own service-repo caller (`infra/.github/workflows/project-sync.yml`, the correct shape):
> 1. **Dead `with:` inputs.** This caller passes `project-id`, `event-name`, `event-action`, `item-node-id`, `pr-merged` — but the infra callee declares **only `secrets`** under `workflow_call` (no `inputs`) and resolves project #1 + the event context from `github.event.*` itself. The `with:` block is ignored.
> 2. **Missing `permissions:` block.** The infra caller includes an explicit `permissions: {contents: read, issues: write, pull-requests: write}` block (with a comment that a callee can't elevate the caller's perms). This caller omits it. The correct caller has the right triggers, the permissions block, `uses: …@dev`, `secrets: inherit`, and **no** `with:`.

## Issue/PR templates

All under `.github/.github/`:
- **ISSUE_TEMPLATE/bug.yml** "Bug Report" (auto-label `[bug]`): Description (req), Steps to reproduce (optional), Expected (req), Actual (req), Priority dropdown P2/P1/P0 default P2 (req) — note "P0 exempt from stale auto-close". Bugs are meant to be filed **directly in the affected repo**, not here.
- **ISSUE_TEMPLATE/feature.yml** "Feature Request" (auto-label `[feature]`): Description (req), Acceptance criteria (req, prefilled `- [ ]`), **Affected repos checkboxes** in order `api,app,agent,widget,infra,docs,website,monitor` (**these drive `issue-router`**), Sub-issues textarea (optional), Priority dropdown default P2 (not required).
- **ISSUE_TEMPLATE/config.yml**: `blank_issues_enabled: true`; one contact link "File in a specific repo" → org repositories list.
- **PULL_REQUEST_TEMPLATE.md**: Summary; Related issue (Closes/Fixes/Resolves guidance + note that project-sync moves the linked issue to *In review*, or auto-creates a tracking issue if omitted); Test plan; Checklist ("CI passes (type-check + lint + build)" + "Shared contracts in sync if changed (`routes.ts`, `schema.ts`, `proto`)").

## Project board model

The board **logic lives once in infra** (`infra/.github/workflows/project-sync-service.yml`); this repo's `project-sync.yml` and all 7 service-repo callers just `uses:` it. Org `Marketrix-ai`, **ProjectV2 number 1**, `Status` single-select. The callee resolves the project + Status-field + option IDs at runtime **by name** via one GraphQL query — renaming/recoloring options is safe, but the names must stay exactly **`Backlog` / `Ready` / `In review` / `Done`** (lowercase `r` in "In review"; there is no "In Progress"). Callee permissions: `contents:read`, `issues:write`, `pull-requests:write`; `GH_TOKEN=INFRA_PAT`.

Transitions (driven entirely by `github.event.*` in the callee):

| Status | Trigger |
|--------|---------|
| Backlog | `issues: opened` |
| Ready | `issues: assigned`; or `pull_request: closed` unmerged (revert) |
| In review | `pull_request: opened` — also adds `Marketrix-ai/dev` as reviewer (soft-fail) and links the issue |
| Done | `issues: closed`; or `pull_request: closed` merged |

On `pull_request: opened` the callee extracts `Closes/Fixes/Resolves #N` from the PR body (regex `(?:closes|fixes|resolves)\s+#\K\d+`, case-insensitive, first match); if none, it **auto-creates a tracking issue** and rewrites the PR body to `Closes #N\n\n<old>`. Repos with issues disabled (e.g. `website`) make that auto-create soft-fail with a `::warning::` and exit 0.

## Gotchas

- **`INFRA_PAT` is the critical secret.** Required by `issue-router`, `create-branch`, `label-sync`, `stale`, and (via `secrets: inherit`) the `project-sync` → infra callee. It needs **project-write + repo:write across the whole org** because label-sync/stale iterate ALL org repos and board sync writes the org ProjectV2. If it's missing / expired / under-scoped, routing, label-sync, stale, branch-creation, and board-sync all silently break. `auto-label` is the exception — it uses `github.token` and only touches the local repo.
- **`CONTRACTS_READ_TOKEN` is NOT here.** That belongs to app/widget contract-drift CI — don't conflate it with `INFRA_PAT`.
- **`project-sync.yml` latent bug** (dead `with:` inputs + missing `permissions:` block) — see the project-sync section.
- **`create-branch` empty-draft problem** — fires on every assignment, bases PRs on `main`; leaves orphaned empty drafts under the canonical manual flow. Legacy.
- **issue-router sub-issues aren't native** GitHub sub-issues — just a "Part of <url>" text reference.
- **`stale` can label-and-close in one pass** for issues `>90d` inactive that were never `stale`-labeled.
- **`label-sync` and `stale` enumerate every org repo each run** — no allowlist; adding a new repo to the org auto-includes it.
- **Three lists must stay in lockstep:** the hardcoded repo list in `issue-router`, the "Affected repos" checkboxes in `feature.yml`, and the scope labels in `label-sync` — all currently agree on the same 8 repos (`api app agent widget infra docs website monitor`).
- **Board option names are load-bearing** — renaming `Backlog`/`Ready`/`In review`/`Done` breaks status moves (the callee matches by name).
- **No CI in this repo** (pure metadata/automation), and the **default branch is `main`** while service repos branch from `dev` — don't base work here on `dev`.
