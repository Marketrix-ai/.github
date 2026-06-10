# .github (org meta)

Meta repo for the Marketrix organization: the default issue/PR **templates** and the **public org
profile**. The GitHub-meaningful content lives in the **nested** `.github/.github/` dir
(`ISSUE_TEMPLATE/`, `PULL_REQUEST_TEMPLATE.md`). Part of the Marketrix workspace — root
`../CLAUDE.md` owns the dev workflow; read it. This file covers only what's specific to `.github/`.

**Default branch: `main`** (service repos branch from `dev`). No buildable code, no CI.

> **Issue/PR tracking lives in Linear, not GitHub.** Issues are created and tracked in Linear
> (generated directly into the affected repo), and Linear ties PRs to their issues. The former
> org-automation workflows — project-board sync, PR→issue auto-creation, issue routing, branch
> creation, label sync, and stale-close — have all been **retired** (and the GitHub project board
> deleted). There are no workflows in this repo anymore.

## Layout

```
.github/.github/
  ISSUE_TEMPLATE/       bug.yml, feature.yml, config.yml
  PULL_REQUEST_TEMPLATE.md
profile/README.md       public org profile (marketing landing page on github.com/Marketrix-ai)
```

No `workflows/`, no reusable workflows, no `CODEOWNERS`, no labels YAML, no composite actions.

## Issue/PR templates

All under `.github/.github/`. These apply only when an issue/PR is filed **directly on GitHub**;
most intake now comes from Linear.

- **ISSUE_TEMPLATE/bug.yml** "Bug Report" (auto-label `[bug]`): Description (req), Steps (optional),
  Expected (req), Actual (req), Priority dropdown P2/P1/P0 default P2 (req). Bugs are meant to be
  filed **directly in the affected repo**, not here.
- **ISSUE_TEMPLATE/feature.yml** "Feature Request" (auto-label `[feature]`): Description (req),
  Acceptance criteria (req, prefilled `- [ ]`), Priority dropdown default P2 (not required).
- **ISSUE_TEMPLATE/config.yml**: `blank_issues_enabled: true`; one contact link "File in a specific
  repo" → org repositories list.
- **PULL_REQUEST_TEMPLATE.md**: Summary; Related issue (`Closes/Fixes/Resolves #N` — links the PR to
  its issue, which Linear also reads); Test plan; Checklist (CI passes; shared contracts in sync if
  changed — `routes.ts`, `schema.ts`, `proto`).

## Notes

- **Public org profile** lives in `profile/README.md` (rendered at `github.com/Marketrix-ai`). The
  members-only profile is a separate repo, `.github-private`.
- **Labels** still exist per-repo on GitHub but are no longer auto-synced (the weekly label-sync
  workflow was retired). Apply them manually or let Linear manage issue metadata.
- **`INFRA_PAT`** (the org secret that powered the retired workflows) is now unused here — safe to
  revoke once nothing else in the org depends on it.
