#!/usr/bin/env bash
# Idempotent workspace bootstrap for the Marketrix multi-repo monorepo. Checks local tool
# prerequisites and gh auth; clones or fetches .claude plus every CODE_REPOS entry into
# MARKETRIX_HOME (default ~/code/marketrix); creates the .agents/AGENTS.md/CLAUDE.md/NOMENCLATURE.md
# constitution symlinks (skipping any that already exist as a real file, never overwriting one);
# creates .work/{worktrees,plans,specs}; audits SOPS/age key file presence and permissions under
# ~/.config/marketrix without ever creating or committing them; and checks for the local colima and
# cloud marketrix-prod-aks kubectl contexts. Safe to re-run any time — every step no-ops cleanly on
# a workspace that's already set up.
set -uo pipefail

WORKSPACE="${MARKETRIX_HOME:-$HOME/code/marketrix}"
ORG="Marketrix-ai"
CODE_REPOS=(agent api app widget meet personaos docs monitor infra website)
KEY_DIR="$HOME/.config/marketrix"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m/\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31mx\033[0m %s\n' "$*"; }

MISSING=0

bold "Prerequisites"

need() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1${3:+ - $(eval "$3" 2>/dev/null | head -1)}"
  else
    bad "$1 missing - $2"
    MISSING=1
  fi
}

need git       "everything"                    "git --version"
need gh        "cloning the private repos"     "gh --version"
need node      "api, app, widget, meet, personaos, docs, monitor, website (24+)" "node --version"
need bun       "every Node repo's install, gate and release" "bun --version"
need uv        "agent (Python 3.14+) - https://docs.astral.sh/uv/" "uv --version"
need kubectl   "local + cloud clusters"        "kubectl version --client 2>/dev/null | head -1"
need colima    "local k3s AND the docker daemon Tilt builds into" "colima version 2>/dev/null | head -1"
need tilt      "the local stack"               "tilt version"
need sops      "secret decryption"             "sops --version 2>/dev/null | head -1"
need age       "the SOPS backend"              "age --version"
need helm      "infra"                         "helm version --short"
need terraform "infra"                         "terraform version | head -1"

if gh auth status >/dev/null 2>&1; then
  ok "gh authenticated as $(gh api user -q .login 2>/dev/null || echo '?')"
else
  bad "gh is not authenticated - run: gh auth login"
  MISSING=1
fi

if [ "$MISSING" -ne 0 ]; then
  echo
  warn "Install what is missing above, then re-run. Nothing has been changed."
  exit 1
fi

echo
bold "Workspace  $WORKSPACE"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE" || exit 1

clone_or_fetch() {
  local repo="$1" dir="${2:-$1}" err
  if [ -d "$dir/.git" ]; then
    if err="$(git -C "$dir" fetch origin --prune --quiet 2>&1)"; then ok "$dir (fetched)"; else warn "$dir (fetch failed): $err"; fi
  elif err="$(gh repo clone "$ORG/$repo" "$dir" -- --quiet 2>&1)"; then
    ok "$dir (cloned)"
  else
    bad "$dir - clone failed: $err"
    return 1
  fi
  git -C "$dir" remote set-head origin -a >/dev/null 2>&1
}

clone_or_fetch .claude .claude || exit 1
for r in "${CODE_REPOS[@]}"; do clone_or_fetch "$r"; done

echo
bold "Constitution symlinks"
link() {
  if [ -e "$2" ] && [ ! -L "$2" ]; then warn "$2 exists and is not a symlink - leaving it alone"; return; fi
  ln -sfn "$1" "$2" && ok "$2 -> $1"
}
link .claude                 .agents
link .claude/CLAUDE.md       CLAUDE.md
link .agents/AGENTS.md       AGENTS.md
link .claude/NOMENCLATURE.md NOMENCLATURE.md

mkdir -p "$WORKSPACE/.work/worktrees" "$WORKSPACE/.work/plans" "$WORKSPACE/.work/specs"
ok ".work/{worktrees,plans,specs}"

echo
bold "Secret keys  $KEY_DIR"
if [ -d "$KEY_DIR" ]; then
  for f in keys.local.txt keys.prod.txt keys.platform.txt; do
    if [ -f "$KEY_DIR/$f" ]; then
      mode=$(stat -f '%Lp' "$KEY_DIR/$f" 2>/dev/null || stat -c '%a' "$KEY_DIR/$f" 2>/dev/null)
      if [ "$mode" = "600" ]; then ok "$f"; else warn "$f is mode $mode, not 0600 - chmod 600 $KEY_DIR/$f"; fi
    else
      warn "$f absent - ask a maintainer (never commit these)"
    fi
  done
else
  warn "$KEY_DIR absent. Keys are handed over out of band, never by this script."
  warn "Without keys.local.txt the Tiltfile cannot decrypt local secrets."
fi

echo
bold "Clusters"
if kubectl config get-contexts -o name 2>/dev/null | grep -qx colima; then
  ok "colima context present"
else
  warn "no 'colima' context - run: colima start --cpus 8 --memory 24 --disk 100 --kubernetes --k3s-arg='\"--disable=metrics-server,traefik\"'"
fi
if kubectl config get-contexts -o name 2>/dev/null | grep -qx marketrix-prod-aks; then
  ok "marketrix-prod-aks - the single cloud cluster (mtx-platform / mtx-prod)"
else
  warn "no cloud context - az aks get-credentials, once you have Azure access"
fi

echo
bold "Next"
cat <<'NEXT'
  1  colima start --cpus 8 --memory 24 --disk 100 --kubernetes --k3s-arg='"--disable=metrics-server,traefik"'
     kubectl config use-context colima
  2  cd infra && tilt up          # builds + deploys everything with hot reload;
                                  # local workloads land in mtx-local
  3  http://app.marketrix.localhost   (api :8080/:8081 . monitor :9004 . meet :9005)

  Read .claude/CLAUDE.md first - it is the constitution. Each repo's own
  CLAUDE.md is the source of truth for that repo.

  Never develop on main directly: branch off origin/main into a worktree at
  .work/worktrees/<repo>-<branch> - never inside a repo, never inside .claude/.
NEXT
echo
ok "Bootstrap complete."
