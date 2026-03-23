# .github

Org-level GitHub configuration for the Marketrix organization. Provides default templates, shared workflows, and org profile.

## Purpose

This repo is the **cross-cutting issue tracker**. Issues created here automatically get the `cross-cutting` label and represent work spanning multiple repos. Single-repo bugs and features should be filed directly in the affected repo.

## Issue Lifecycle

```
Feature created in .github with 1 repo checked
  → issue-router moves it to that repo, closes the .github issue
  → (continues as single-repo issue below)

Feature created in .github with 2+ repos checked
  → auto-label applies `cross-cutting`
  → issue-router creates sub-issues in each checked repo
  → project-sync → Backlog

Sub-issue assigned in repo
  → create-branch creates feature branch
  → project-sync → Ready

PR opened with "Closes #N"
  → project-sync → PR: In Review, Issue: In Progress

PR merged → Done
```

## Structure

| Path | Purpose |
|------|---------|
| `.github/ISSUE_TEMPLATE/` | Org-default issue templates (bug, feature) |
| `.github/PULL_REQUEST_TEMPLATE.md` | Org-default PR template |
| `.github/workflows/auto-label.yml` | Auto-applies `cross-cutting` label to all `.github` issues |
| `.github/workflows/issue-router.yml` | Routes issues: 1 repo → moves to that repo; 2+ repos → creates sub-issues |
| `.github/workflows/create-branch.yml` | Creates feature branch on issue assign (skips `cross-cutting`) |
| `.github/workflows/label-sync.yml` | Syncs label set across all org repos (weekly) |
| `.github/workflows/project-sync.yml` | Syncs issues/PRs to GitHub Project board |
| `.github/workflows/stale.yml` | Marks issues stale at 60d, closes at 90d (exempts `P0`, `cross-cutting`) |
| `profile/README.md` | Org profile displayed on GitHub |

## Conventions

### Issue Filing
- **All features can be filed in `.github`** — the `issue-router` workflow handles routing:
  - 1 repo checked → auto-moved to that repo
  - 2+ repos checked → stays in `.github` as tracking issue, sub-issues auto-created in each repo
- **Bugs** → file directly in the affected repo
- Cross-cutting issues here are tracking issues — implementation happens in sub-issues

### Labels
Synced across all repos by `label-sync.yml`:
- Type: `bug`, `feature`, `enhancement`, `chore`, `documentation`
- Scope: `cross-cutting`, `api`, `app`, `agent`, `widget`, `infra`, `docs`, `website`, `monitor`
- Priority: `P0` (critical), `P1` (high), `P2` (normal)
- Status: `stale` (auto-applied by stale workflow)

### PR Linking
PRs must use `Closes #N` / `Fixes #N` / `Resolves #N` to link to issues. `project-sync` parses this to move the linked issue to In Progress on the project board.

### Automation Effects by Label
| Label | `create-branch` | `stale` |
|-------|-----------------|---------|
| `cross-cutting` | Skipped (no branch) | Exempt from auto-close |
| `P0` | Normal | Exempt from auto-close |
| (default) | Creates branch | Stale at 60d, close at 90d |
