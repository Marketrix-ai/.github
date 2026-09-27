#!/usr/bin/env bash
# Idempotent workspace bootstrap for the Marketrix multi-repo workspace: checks tool prerequisites and gh
# auth, clones or fetches .claude (fast-forwarding a clean main) plus every CODE_REPOS entry into MARKETRIX_HOME (default ~/code/marketrix),
# creates the constitution symlinks and .work/{worktrees,plans,specs}, and audits the SOPS/age key files and
# kubectl contexts. It installs nothing and never writes a secret; it exits 1 if any repo failed to sync.
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

check() {
  local required="$1"; shift
  if command -v "$1" >/dev/null; then
    ok "$1 - $("$1" "${@:3}" 2>&1 | head -1)"
  elif [ "$required" = 1 ]; then
    bad "$1 missing - $2"
    MISSING=1
  else
    warn "$1 missing - $2"
  fi
}

check 1 git       "everything"                                        --version
check 1 gh        "cloning the private repos"                         --version
check 1 bun       "every TS repo's install, gate and release"         --version
check 1 uv        "agent (Python 3.14+) - https://docs.astral.sh/uv/" --version
check 1 python3   "infra's gate and deploy scripts"                   --version
check 1 jq        "the WorktreeCreate hook"                          --version
check 1 kubectl   "local + cloud clusters"                            version --client
check 1 colima    "local k3s AND the docker daemon Tilt builds into"  version
check 1 tilt      "the local stack"                                   version
check 1 sops      "secret decryption"                                 --version
check 1 age       "the SOPS backend"                                  --version
check 0 helm      "only for infra ops (render, bootstrap-cluster)"    version --short
check 0 terraform "only for infra ops (terraform/azure)"             version
check 0 az        "only for infra ops and releases"                  version --query '"azure-cli"' --output tsv

if gh_err="$(gh auth status 2>&1)"; then
  ok "gh authenticated as $(gh api user -q .login 2>&1)"
else
  bad "gh is not authenticated - run: gh auth login ($gh_err)"
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
    if err="$(git -C "$dir" fetch origin --prune --quiet 2>&1)"; then ok "$dir (fetched)"; else bad "$dir - fetch failed: $err"; return 1; fi
  elif [ -d "$dir" ]; then
    local tmp; tmp="$(mktemp -d)"
    if err="$(gh repo clone "$ORG/$repo" "$tmp/r" -- --quiet --no-checkout 2>&1 && mv "$tmp/r/.git" "$dir/.git" \
      && git -C "$dir" reset -q 2>&1 && git -C "$dir" ls-files -dz | xargs -0 git -C "$dir" checkout -- 2>&1)"; then
      ok "$dir (repaired: adopted the plain directory as a checkout, local files kept)"
    else
      bad "$dir - repair failed: $err"
      rm -rf "$tmp"
      return 1
    fi
    rm -rf "$tmp"
  elif err="$(gh repo clone "$ORG/$repo" "$dir" -- --quiet 2>&1)"; then
    ok "$dir (cloned)"
  else
    bad "$dir - clone failed: $err"
    return 1
  fi
  if ! err="$(git -C "$dir" remote set-head origin -a 2>&1)"; then warn "$dir (set-head failed): $err"; fi
}

FAILED=0
clone_or_fetch .claude .claude || { [ -d .claude/.git ] || exit 1; FAILED=1; }
if [ -n "$(git -C .claude status --porcelain)" ] || [ "$(git -C .claude branch --show-current)" != main ]; then
  warn ".claude is not a clean main - the constitution may be stale; pull it yourself"
elif err="$(git -C .claude merge --ff-only --quiet origin/main 2>&1)"; then ok ".claude fast-forwarded to origin/main"
else warn ".claude fast-forward failed: $err"; fi
for r in "${CODE_REPOS[@]}"; do clone_or_fetch "$r" || FAILED=$((FAILED + 1)); done

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
      if [ "$(uname)" = Darwin ]; then mode=$(stat -f '%Lp' "$KEY_DIR/$f"); else mode=$(stat -c '%a' "$KEY_DIR/$f"); fi
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
contexts="$(kubectl config get-contexts -o name 2>&1)" || warn "kubectl config get-contexts failed: $contexts"
if grep -qx colima <<<"$contexts"; then
  ok "colima context present"
else
  warn "no 'colima' context - start it with step 1 under Next"
fi
if grep -qx marketrix-prod-aks <<<"$contexts"; then
  ok "marketrix-prod-aks - the single cloud cluster (mtx-platform / mtx-prod)"
else
  warn "no cloud context - az aks get-credentials, once you have Azure access"
fi

echo
bold "Next"
cat <<'NEXT'
  1  colima start --cpus 8 --memory 24 --disk 100 --kubernetes --k3s-arg='"--disable=metrics-server,traefik"'
     kubectl config use-context colima
  2  cd infra && tilt up    (builds and deploys everything into mtx-local with hot reload)
  3  http://<svc>.marketrix.localhost, e.g. app.marketrix.localhost, api.marketrix.localhost

  Read .claude/CLAUDE.md first - it is the constitution. Each repo's own
  CLAUDE.md is the source of truth for that repo.

  Never develop on main directly: branch off origin/main into a worktree at
  .work/worktrees/<repo>-<issue> - never inside a repo, never inside .claude/.
NEXT
echo
if [ "$FAILED" -ne 0 ]; then
  bad "Bootstrap incomplete: $FAILED repo(s) failed to sync - see above."
  exit 1
fi
ok "Bootstrap complete."
