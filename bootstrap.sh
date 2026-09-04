#!/usr/bin/env bash
set -uo pipefail

WORKSPACE="${MARKETRIX_HOME:-$HOME/code/marketrix}"
ORG="Marketrix-ai"
CODE_REPOS=(agent api app widget meet personaos docs monitor infra)
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
need node      "api, app, widget, meet, personaos, docs, monitor (24+)" "node --version"
need npm       "same"                          "npm --version"
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

# Ambiguous dev/main states stay untouched.
retarget_main() {
  local dir="$1"
  git -C "$dir" show-ref -q --verify refs/heads/dev || return 0
  git -C "$dir" show-ref -q --verify refs/remotes/origin/main || return 0
  git -C "$dir" show-ref -q --verify refs/remotes/origin/dev && return 0
  if git -C "$dir" show-ref -q --verify refs/heads/main; then
    warn "$dir has both 'dev' and 'main' - reconcile them yourself, leaving both alone"
    return 0
  fi
  if git -C "$dir" branch -m dev main 2>/dev/null; then
    git -C "$dir" branch -q --set-upstream-to=origin/main main 2>/dev/null
    ok "$dir (local 'dev' renamed to 'main')"
  else
    warn "$dir - could not rename local 'dev'; run: git branch -m dev main"
  fi
}

clone_or_fetch() {
  local repo="$1" dir="${2:-$1}"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch origin --prune --quiet 2>/dev/null && ok "$dir (fetched)" || warn "$dir (fetch failed - offline?)"
    retarget_main "$dir"
  elif gh repo clone "$ORG/$repo" "$dir" -- --quiet 2>/dev/null; then
    ok "$dir (cloned)"
  else
    bad "$dir - clone failed. Private repo: do you have org access?"
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
link .claude           .agents
link .claude/CLAUDE.md CLAUDE.md
link .agents/AGENTS.md AGENTS.md

mkdir -p "$WORKSPACE/.work/worktrees" "$WORKSPACE/.work/plans" "$WORKSPACE/.work/specs"
ok ".work/{worktrees,plans,specs}"

echo
bold "Secret keys  $KEY_DIR"
if [ -d "$KEY_DIR" ]; then
  for f in keys.local.txt keys.dev.txt keys.prod.txt keys.platform.txt; do
    if [ -f "$KEY_DIR/$f" ]; then
      mode=$(stat -f '%Lp' "$KEY_DIR/$f" 2>/dev/null || stat -c '%a' "$KEY_DIR/$f" 2>/dev/null)
      [ "$mode" = "600" ] && ok "$f" || warn "$f is mode $mode, not 0600 - chmod 600 $KEY_DIR/$f"
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
  warn "no 'colima' context - run: colima start --kubernetes --k3s-arg='--disable=metrics-server'"
fi
if kubectl config get-contexts -o name 2>/dev/null | grep -qx marketrix-prod-aks; then
  ok "marketrix-prod-aks - the single cloud cluster (mtx-platform / mtx-dev / mtx-prod)"
else
  warn "no cloud context - az aks get-credentials, once you have Azure access"
fi

echo
bold "Next"
cat <<'NEXT'
  1  colima start --kubernetes --k3s-arg='--disable=metrics-server'
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
