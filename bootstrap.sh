#!/usr/bin/env bash
#
# Marketrix dev-environment bootstrap.
#
#   curl -fsSL https://raw.githubusercontent.com/Marketrix-ai/.github/main/bootstrap.sh | bash
#
# The script is public; the platform is not. Every repo it clones except `widget`
# is private, so without org access this exits at the first clone having changed
# nothing. Run `gh auth login` first.
#
# Idempotent — safe to re-run. Existing clones are fetched, never clobbered; no
# file is overwritten and no secret is ever written.
#
# What it deliberately does NOT do:
#   - install anything            : you own your machine; it reports what is missing
#   - write ~/.config/marketrix/  : those age keys come from a human, out of band
#   - start Colima or Tilt        : one `colima start` is a decision, not a side effect
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

# --- 1 . Prerequisites -------------------------------------------------------
# Reported, never installed. Only an absent binary blocks.
bold "Prerequisites"

need() { # need <binary> <why> [version-cmd]
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
need uv        "agent (Python 3.12+) - https://docs.astral.sh/uv/" "uv --version"
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

# --- 2 . Workspace + clones --------------------------------------------------
# The workspace root is deliberately NOT a git repo - it holds sibling clones, so
# nothing can leak between their histories.
echo
bold "Workspace  $WORKSPACE"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE" || exit 1

clone_or_fetch() { # clone_or_fetch <repo> [dir]
  local repo="$1" dir="${2:-$1}"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch origin --prune --quiet 2>/dev/null && ok "$dir (fetched)" || warn "$dir (fetch failed - offline?)"
  elif gh repo clone "$ORG/$repo" "$dir" -- --quiet 2>/dev/null; then
    ok "$dir (cloned)"
  else
    bad "$dir - clone failed. Private repo: do you have org access?"
    return 1
  fi
}

clone_or_fetch .claude .claude || exit 1
for r in "${CODE_REPOS[@]}"; do clone_or_fetch "$r"; done

# --- 3 . Constitution symlinks -----------------------------------------------
# All three resolve to the same file. `.claude/CLAUDE.md` alone is enough for
# Claude Code; the root spellings are what every OTHER tool rooted here looks for.
echo
bold "Constitution symlinks"
link() { # link <target> <name>
  if [ -e "$2" ] && [ ! -L "$2" ]; then warn "$2 exists and is not a symlink - leaving it alone"; return; fi
  ln -sfn "$1" "$2" && ok "$2 -> $1"
}
link .claude           .agents
link .claude/CLAUDE.md CLAUDE.md
link .agents/AGENTS.md AGENTS.md

# --- 4 . Scratch dirs --------------------------------------------------------
# .work/ is never committed and is not a git repo - that is the point: no plan,
# spec, or scratch checkout can leak into a service repo's history.
mkdir -p "$WORKSPACE/.work/worktrees" "$WORKSPACE/.work/plans" "$WORKSPACE/.work/specs"
ok ".work/{worktrees,plans,specs}"

# --- 5 . Secrets - reported, never fetched -----------------------------------
echo
bold "Secret keys  $KEY_DIR"
if [ -d "$KEY_DIR" ]; then
  for f in keys.local.txt keys.dev.txt keys.prod.txt keys.shared.txt; do
    if [ -f "$KEY_DIR/$f" ]; then
      # 0600 matters - these decrypt production.
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

# --- 6 . Cluster contexts ----------------------------------------------------
echo
bold "Clusters"
if kubectl config get-contexts -o name 2>/dev/null | grep -qx colima; then
  ok "colima context present"
else
  warn "no 'colima' context - run: colima start --kubernetes --k3s-arg='--disable=metrics-server'"
fi
if kubectl config get-contexts -o name 2>/dev/null | grep -qx marketrix-prod-aks; then
  ok "marketrix-prod-aks - the single cloud cluster (mtx-shared / mtx-dev / mtx-prod)"
else
  warn "no cloud context - az aks get-credentials, once you have Azure access"
fi

# --- 7 . Next steps ----------------------------------------------------------
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

  Never develop on dev directly: branch off origin/dev into a worktree at
  .work/worktrees/<repo>-<branch> - never inside a repo, never inside .claude/.
NEXT
echo
ok "Bootstrap complete."
