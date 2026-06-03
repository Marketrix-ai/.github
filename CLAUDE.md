# .github

Org-level GitHub configuration for the Marketrix organization. Default issue/PR templates, org-automation workflows, and the public org profile. **Default branch: `main`.** No buildable code here — there is no CI (type-check/lint/build) workflow in this repo.

## Purpose

This repo is the **cross-cutting issue tracker**. Issues opened here auto-get the `cross-cutting` label and represent work spanning multiple repos. Single-repo bugs and features go directly in the affected repo (`issue-router` will move a single-repo feature filed here, see below).

## Development Workflow

### Issue as Design Spec
The issue body IS the design spec — what to build and why, not how. It must contain:
- **What**: the feature or change from a user/system perspective
- **Why**: motivation, constraints, dependencies
- **Acceptance criteria**: testable conditions that define done
- Implementation details are figured out by the developer in the worktree

### Automated Flow
```
Issue opened (here, in .github)
  → issue-router: counts checked repo boxes (api/app/agent/widget/infra/docs/website/monitor)
                  1 checked  → creates the issue in that repo (labels: feature + repo),
                               then closes this one as not_planned with a redirect comment
                  2+ checked → stays here as tracking issue, creates a sub-issue in EACH repo
                  0 checked  → left as-is
  → auto-label applies `cross-cutting` (here only)
  → project-sync → Backlog

Issue assigned
  → project-sync → Ready
  → create-branch ALSO fires on assign: pushes an empty {num}-{slug} commit/branch
    and opens a draft PR with "Closes #N" (skipped only for `cross-cutting` issues)

PR opened (in a service repo)
  → project-sync (via infra reusable workflow): adds Marketrix-ai/dev as reviewer,
    moves the `Closes #N` issue → In review; if the PR has no Closes/Fixes/Resolves
    reference it auto-creates a tracking issue and rewrites the PR body to link it

PR closed
  → merged   → project-sync moves linked issue → Done (GitHub also auto-closes via Closes #N)
  → unmerged → project-sync moves linked issue back → Ready
```

> **create-branch caveat.** `create-branch.yml` is still active and fires on every (non-cross-cutting) issue assignment. The canonical workflow (root `CLAUDE.md`) is for the developer to create their own branch + draft PR manually, which leaves create-branch's empty "Closes #N" draft orphaned. Prefer the manual flow and close/ignore the auto-draft, or unassign before assigning the real owner.

### Worktree Development
`create-branch` already pushed the `{num}-{slug}` branch on assignment, so check it out rather than creating a new one. Note this repo's base branch is `main`; service repos branch from `origin/dev`.
```bash
cd <repo>
git fetch origin
git worktree add ../repo-42 42-feature-slug   # existing branch, no -b
cd ../repo-42
# develop, commit, push → CI runs in the SERVICE repo (none here)
git push origin 42-feature-slug
# when done: mark PR ready, get review, merge
git worktree remove ../repo-42
```

## Structure

| Path | Purpose |
|------|---------|
| `.github/workflows/auto-label.yml` | On issue opened/edited: adds `cross-cutting` if absent (uses default `GITHUB_TOKEN`) |
| `.github/workflows/issue-router.yml` | On issue opened: 1 repo → recreate in that repo + close here; 2+ → sub-issue per repo |
| `.github/workflows/create-branch.yml` | On issue assigned: empty branch + draft PR `Closes #N` (skips `cross-cutting`) — see caveat above |
| `.github/workflows/label-sync.yml` | Mon 06:00 UTC (+ manual): create/update the canonical label set in every org repo |
| `.github/workflows/project-sync.yml` | Thin caller → `Marketrix-ai/infra/.github/workflows/project-sync-service.yml@dev` (board id `PVT_kwDOCO0iG84An17k`) |
| `.github/workflows/stale.yml` | Daily 07:00 UTC (+ manual): stale at 60d, close at 90d; exempts `P0`, `cross-cutting`; ignores PRs |
| `.github/ISSUE_TEMPLATE/` | `bug.yml`, `feature.yml` (repo checkboxes drive `issue-router`), `config.yml` |
| `.github/PULL_REQUEST_TEMPLATE.md` | Org-default PR template |
| `profile/README.md` | Org public profile displayed on GitHub |

> The actual project-board sync logic lives ONCE in infra's reusable `project-sync-service.yml`; every service repo's `project-sync.yml` is a ~15-line caller. Edit board behavior there, not here.

### Project board statuses
Single org Project (#1, "Marketrix"), `Status` single-select with options **Backlog / Ready / In review / Done** (resolved by name at runtime — renaming/recoloring the option is safe). There is no "In Progress" status.

| Status | Trigger |
|--------|---------|
| Backlog | issue opened |
| Ready | issue assigned; or PR closed unmerged (reverts) |
| In review | PR opened (also adds `Marketrix-ai/dev` as reviewer) |
| Done | issue closed; or linked PR merged |

## Conventions

### Issue Filing
- **All features can be filed in `.github`** — `issue-router` handles routing
- **Bugs** → file directly in the affected repo
- Cross-cutting issues are tracking issues — implementation happens in sub-issues

### Issue Body Format
Every issue must follow this structure:
```
## Description
What to build and why. User-facing behavior, system behavior, or architectural change.

## Context
Current state, constraints, dependencies, key decisions already made.

## Acceptance criteria
- [ ] Testable conditions that define done
```
Do NOT put implementation details (file paths, function signatures, code) in issues. That's for the developer to figure out in the worktree.

### Labels
Canonical set created/updated in every org repo by `label-sync.yml` (Mon 06:00 UTC). All scope labels share color `1d76db`:
- Type: `bug`, `feature`, `enhancement`, `chore`, `documentation`
- Scope: `cross-cutting`, `api`, `app`, `agent`, `widget`, `infra`, `docs`, `website`, `monitor`
- Priority: `P0` (critical), `P1` (high), `P2` (normal)
- Status: `stale` (also auto-applied by `stale.yml`)

### Automation Effects by Label
| Label | `create-branch` | `stale` |
|-------|-----------------|---------|
| `cross-cutting` | Skipped (no branch) | Exempt from auto-close |
| `P0` | Normal | Exempt from auto-close |
| (default) | Creates branch + draft PR | Stale at 60d, close at 90d |
