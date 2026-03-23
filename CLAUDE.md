# .github

Org-level GitHub configuration for the Marketrix organization. Provides default templates, shared workflows, and org profile.

## Purpose

This repo is the **cross-cutting issue tracker**. Issues created here automatically get the `cross-cutting` label and represent work spanning multiple repos. Single-repo bugs and features should be filed directly in the affected repo.

## Development Workflow

### Issue as Design Spec
The issue body IS the design spec — what to build and why, not how. It must contain:
- **What**: the feature or change from a user/system perspective
- **Why**: motivation, constraints, dependencies
- **Acceptance criteria**: testable conditions that define done
- Implementation details are figured out by the developer in the worktree

### Automated Flow
```
Issue created in .github
  → issue-router: 1 repo checked → moves to that repo
                  2+ repos checked → stays here, sub-issues created in each repo
  → auto-label applies `cross-cutting`
  → project-sync → Backlog

Issue assigned
  → create-branch creates {num}-{slug} branch + draft PR with "Closes #N"
  → project-sync → Ready

Developer creates worktree, develops, pushes
  → CI runs on PR branch (type-check + lint + build)

PR marked ready for review
  → project-sync moves linked issue → In Review

PR merged
  → project-sync → Done
  → GitHub auto-closes the linked issue

PR opened without linked issue
  → project-sync auto-creates a tracking issue and links it
```

### Worktree Development
```bash
cd <repo>
git fetch origin
git worktree add ../repo-42 42-feature-slug
cd ../repo-42
# develop, commit, push
git push origin 42-feature-slug
# when done: mark PR ready, get review, merge
git worktree remove ../repo-42
```

## Structure

| Path | Purpose |
|------|---------|
| `.github/ISSUE_TEMPLATE/` | Org-default issue templates (bug, feature) |
| `.github/PULL_REQUEST_TEMPLATE.md` | Org-default PR template |
| `.github/workflows/auto-label.yml` | Auto-applies `cross-cutting` label to all `.github` issues |
| `.github/workflows/issue-router.yml` | Routes issues: 1 repo → moves to that repo; 2+ repos → creates sub-issues |
| `.github/workflows/create-branch.yml` | Creates feature branch + draft PR on issue assign (skips `cross-cutting`) |
| `.github/workflows/label-sync.yml` | Syncs label set across all org repos (weekly) |
| `.github/workflows/project-sync.yml` | Syncs issues to GitHub Project board; PRs move linked issues through statuses |
| `.github/workflows/stale.yml` | Marks issues stale at 60d, closes at 90d (exempts `P0`, `cross-cutting`) |
| `profile/README.md` | Org profile displayed on GitHub |

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
Synced across all repos by `label-sync.yml`:
- Type: `bug`, `feature`, `enhancement`, `chore`, `documentation`
- Scope: `cross-cutting`, `api`, `app`, `agent`, `widget`, `infra`, `docs`, `website`, `monitor`
- Priority: `P0` (critical), `P1` (high), `P2` (normal)
- Status: `stale` (auto-applied by stale workflow)

### Automation Effects by Label
| Label | `create-branch` | `stale` |
|-------|-----------------|---------|
| `cross-cutting` | Skipped (no branch) | Exempt from auto-close |
| `P0` | Normal | Exempt from auto-close |
| (default) | Creates branch + draft PR | Stale at 60d, close at 90d |
