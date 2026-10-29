#!/usr/bin/env bash
# Installs the brain into a throwaway sandbox and pipe-tests every hook. Touches nothing real.
#
#   bash context-brain/setup/tests/run-all.sh
#
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf '  \033[32mpass\033[0m  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m  %s\n' "$1"; }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

export HOME="$SANDBOX/home" GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig"
mkdir -p "$HOME"
git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main

BRAIN="$SANDBOX/context-brain"
APP="$SANDBOX/app"
mkdir -p "$BRAIN" "$APP"
(cd "$SRC" && tar --exclude=.git -cf - .) | (cd "$BRAIN" && tar -xf -)
git -C "$BRAIN" init -q && git -C "$BRAIN" add -A && git -C "$BRAIN" commit -qm "Initial brain"
git -C "$APP" init -q && echo "# app" > "$APP/README.md" && git -C "$APP" add -A && git -C "$APP" commit -qm "Initial app"

# Commits one staged file in the brain; returns the hook's verdict, but only after proving it was staged.
brain_commit() {
    local path="$1" body="$2"
    mkdir -p "$(dirname "$BRAIN/$path")"
    printf '%s\n' "$body" > "$BRAIN/$path"
    git -C "$BRAIN" add "$path"
    git -C "$BRAIN" diff --cached --quiet && { echo "nothing staged for $path" >&2; return 2; }
    git -C "$BRAIN" commit -qm "Test $path" >/dev/null 2>&1
    local rc=$?
    [ $rc -ne 0 ] && git -C "$BRAIN" reset -q --hard HEAD
    return $rc
}

# Passes only when the hook refused (exit 1), never when nothing was staged (exit 2).
blocked() { brain_commit "$@"; [ $? -eq 1 ]; }

echo "install"
check "installer succeeds" 'bash "$BRAIN/setup/install.sh" app --commit-rules >/dev/null 2>&1'
check "CLAUDE.md links or imports the brain index" '{ [ -L "$APP/CLAUDE.md" ] && grep -q "Project Index" "$APP/CLAUDE.md"; } || [ "$(cat "$APP/CLAUDE.md")" = "@../context-brain/CLAUDE.md" ]'
check "re-run is idempotent" 'bash "$BRAIN/setup/install.sh" app --commit-rules >/dev/null 2>&1'
check "re-run adds no duplicate hooks" 'python3 -c "
import json,sys; h=json.load(open(sys.argv[1]))[\"hooks\"]
sys.exit(0 if all(len(h[e])==1 for e in (\"SessionStart\",\"Stop\",\"PreToolUse\")) else 1)" "$APP/.claude/settings.local.json"'
check "attribution emptied" 'grep -q "\"commit\": \"\"" "$HOME/.claude/settings.json"'

echo "brain pre-commit"
check "blocks a bare category file" 'blocked rules/loose.md "text"'
check "blocks a dead cross-reference" 'blocked rules/team-workflow/notes.md "see ../context-brain/rules/missing/overview.md"'
check "blocks a Git Bash Windows path" 'blocked rules/team-workflow/notes.md "lives in /c/$(echo Users)/alice/work"'
check "blocks a hard-coded home path" 'blocked rules/team-workflow/notes.md "lives in /$(echo home)/alice/work"'
check "blocks a dated changelog heading" 'blocked rules/team-workflow/notes.md "## Fixed 2026-01-01"'
check "blocks a new topic with no index pointer" 'blocked decisions/orphan/overview.md "text"'
check "allows a valid sibling file" 'brain_commit rules/team-workflow/notes.md "see ../context-brain/rules/brain-maintenance/overview.md"'
check "allows a new topic once indexed" 'printf "%s\n" "- Billing: \`../context-brain/decisions/billing/overview.md\`" >> "$BRAIN/CLAUDE.md" && git -C "$BRAIN" add CLAUDE.md && brain_commit decisions/billing/overview.md "text"'

echo "project pre-commit"
mkdir -p "$APP/src"
echo "a" > "$APP/src/a.txt"; git -C "$APP" add src/a.txt
GIT_COMMITTER_DATE="2030-01-01T00:00:00" git -C "$APP" commit -qm "Newer than the brain" --no-verify
echo "b" > "$APP/src/b.txt"; git -C "$APP" add src/b.txt
check "blocks a source commit when the brain is older" '! git -C "$APP" commit -qm "Source change" >/dev/null 2>&1'
echo "x" > "$BRAIN/rules/team-workflow/later.md"; git -C "$BRAIN" add -A
GIT_COMMITTER_DATE="2030-01-02T00:00:00" git -C "$BRAIN" commit -qm "Brain update" >/dev/null 2>&1
check "allows it after the brain is committed" 'GIT_COMMITTER_DATE="2031-01-01T00:00:00" git -C "$APP" commit -qm "Source change" >/dev/null 2>&1'
echo "doc" >> "$APP/README.md"; git -C "$APP" add README.md
check "ignores non-source paths" 'git -C "$APP" commit -qm "Docs only" >/dev/null 2>&1'

echo "commit-msg"
MSG="$SANDBOX/msg"
printf 'Fix the thing\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' > "$MSG"
check "rejects AI attribution" '! "$APP/.git/hooks/commit-msg" "$MSG" >/dev/null'
printf 'One\n\nTwo\n\nThree\n' > "$MSG"
check "rejects a multi-paragraph message" '! "$APP/.git/hooks/commit-msg" "$MSG" >/dev/null'
printf 'Fix the thing\n' > "$MSG"
check "accepts a one-liner" '"$APP/.git/hooks/commit-msg" "$MSG" >/dev/null'

echo "destructive-database guard"
GUARD="$BRAIN/setup/hooks/block-destructive-db.py"
for cmd in "php artisan migrate:fresh" "psql -c 'DROP DATABASE app'" "npx prisma migrate reset" "rails db:drop"; do
    check "blocks: $cmd" '! python3 -c "import json,sys; print(json.dumps({\"tool_input\":{\"command\":sys.argv[1]}}))" "$cmd" | python3 "$GUARD" 2>/dev/null'
done
check "allows: git status" 'printf "{\"tool_input\":{\"command\":\"git status\"}}" | python3 "$GUARD"'
check "blocks unreadable input (fail safe)" '! printf "not json" | python3 "$GUARD" 2>/dev/null'

echo "sync hooks"
REMOTE="$SANDBOX/remote.git"
git init -q --bare "$REMOTE"
git -C "$BRAIN" remote add origin "$REMOTE" && git -C "$BRAIN" push -q -u origin main 2>/dev/null
git clone -q "$REMOTE" "$SANDBOX/teammate" 2>/dev/null
echo "teammate fact" > "$SANDBOX/teammate/rules/team-workflow/teammate.md"
git -C "$SANDBOX/teammate" add -A && git -C "$SANDBOX/teammate" commit -qm "Teammate fact" && git -C "$SANDBOX/teammate" push -q 2>/dev/null
check "SessionStart fast-forwards a clean, behind brain" 'python3 "$BRAIN/setup/hooks/brain-staleness-check.py" | grep -q "fast-forwarded" && [ -f "$BRAIN/rules/team-workflow/teammate.md" ]'
echo "mine" > "$BRAIN/rules/team-workflow/mine.md"; git -C "$BRAIN" add -A; git -C "$BRAIN" commit -qm "My fact" >/dev/null 2>&1
echo "more" > "$SANDBOX/teammate/rules/team-workflow/more.md"
git -C "$SANDBOX/teammate" add -A && git -C "$SANDBOX/teammate" commit -qm "More" && git -C "$SANDBOX/teammate" push -q 2>/dev/null
check "Stop rebases onto a moved remote and pushes" 'python3 "$BRAIN/setup/hooks/brain-unpushed-check.py" | grep -q "rebased on top and pushed" && [ "$(git -C "$BRAIN" rev-list --count @{u}..HEAD)" = 0 ]'
echo "mine v2" > "$BRAIN/rules/team-workflow/teammate.md"; git -C "$BRAIN" add -A; git -C "$BRAIN" commit -qm "Mine conflicts" >/dev/null 2>&1
git -C "$SANDBOX/teammate" pull -q --rebase 2>/dev/null
echo "theirs v2" > "$SANDBOX/teammate/rules/team-workflow/teammate.md"
git -C "$SANDBOX/teammate" add -A && git -C "$SANDBOX/teammate" commit -qm "Theirs conflicts" && git -C "$SANDBOX/teammate" push -q 2>/dev/null
check "Stop aborts a conflicting rebase and leaves the repo as it was" 'python3 "$BRAIN/setup/hooks/brain-unpushed-check.py" | grep -q "NOT pushed" && [ ! -d "$BRAIN/.git/rebase-merge" ] && grep -q "mine v2" "$BRAIN/rules/team-workflow/teammate.md"'

echo "in-repo mode"
MONO="$SANDBOX/mono"
mkdir -p "$MONO/brain" "$MONO/src"
(cd "$SRC" && tar --exclude=.git -cf - .) | (cd "$MONO/brain" && tar -xf -)
git -C "$MONO" init -q
printf '# App rules\n' > "$MONO/CLAUDE.md"
echo "a" > "$MONO/src/a.txt"
git -C "$MONO" add -A && git -C "$MONO" commit -qm "Initial mono" --no-verify

# Commits one staged file in the project; exit 1 only when a hook refused, 2 when nothing was staged.
mono_commit() {
    local path="$1" body="$2"
    mkdir -p "$(dirname "$MONO/$path")"
    printf '%s\n' "$body" > "$MONO/$path"
    git -C "$MONO" add "$path"
    git -C "$MONO" diff --cached --quiet && { echo "nothing staged for $path" >&2; return 2; }
    git -C "$MONO" commit -qm "Test $path" >/dev/null 2>&1
    local rc=$?
    [ $rc -ne 0 ] && git -C "$MONO" reset -q --hard HEAD
    return $rc
}
mono_blocked() { mono_commit "$@"; [ $? -eq 1 ]; }

check "installer succeeds with no project folder" 'bash "$MONO/brain/setup/install.sh" >/dev/null 2>&1'
check "refuses a project folder argument" '! bash "$MONO/brain/setup/install.sh" app >/dev/null 2>&1'
check "keeps the existing CLAUDE.md and adds the import" 'grep -q "# App rules" "$MONO/CLAUDE.md" && grep -qx "@brain/CLAUDE.md" "$MONO/CLAUDE.md"'
check "rewrites brain paths to brain/" 'grep -q "brain/rules/brain-maintenance/overview.md" "$MONO/brain/CLAUDE.md" && ! grep -rq "\.\./context-brain/" "$MONO/brain" --include=*.md'
check "re-run is idempotent" 'bash "$MONO/brain/setup/install.sh" >/dev/null 2>&1 && [ "$(grep -cx "@brain/CLAUDE.md" "$MONO/CLAUDE.md")" = 1 ]'
check "installs the guard but no sync hooks" 'python3 -c "
import json,sys; h=json.load(open(sys.argv[1]))[\"hooks\"]
sys.exit(0 if len(h.get(\"PreToolUse\",[]))==1 and \"Stop\" not in h and \"SessionStart\" not in h else 1)" "$MONO/.claude/settings.local.json"'
git -C "$MONO" add -A && git -C "$MONO" commit -qm "Install brain" --no-verify
check "blocks a bare brain category file" 'mono_blocked brain/rules/loose.md "text"'
check "blocks a dead brain reference" 'mono_blocked brain/rules/team-workflow/notes.md "see brain/rules/missing/overview.md"'
check "blocks a new brain topic with no index pointer" 'mono_blocked brain/decisions/orphan/overview.md "text"'
check "allows a valid brain file" 'mono_commit brain/rules/team-workflow/notes.md "see brain/rules/brain-maintenance/overview.md"'
check "blocks a source change with no brain change" 'mono_blocked src/b.txt "b"'
check "allows a source change with a brain change" 'echo "fact" > "$MONO/brain/rules/team-workflow/fact.md" && git -C "$MONO" add brain/rules/team-workflow/fact.md && mono_commit src/b.txt "b"'
check "ignores non-source paths" 'mono_commit README.md "docs"'
check "ignores a bare file outside the brain" 'mono_commit rules/loose.md "not the brain"'

echo "setup menus"
MENUS="$SANDBOX/menus"
mkdir -p "$MENUS/context-brain"
(cd "$SRC" && tar --exclude=.git -cf - .) | (cd "$MENUS/context-brain" && tar -xf -)
git -C "$MENUS/context-brain" init -q
for r in alpha beta; do git init -q "$MENUS/$r"; done
DOWN=$'\x1b[B'
check "Cancel changes nothing" 'printf "\n\n%s\n" "$DOWN" | CONTEXT_BRAIN_TUI=1 bash "$MENUS/context-brain/setup/install.sh" >/dev/null 2>&1 && [ ! -e "$MENUS/alpha/CLAUDE.md" ] && [ ! -e "$MENUS/beta/CLAUDE.md" ]'
check "arrow keys pick the second project and install" 'printf "%s\n\n\n" "$DOWN" | CONTEXT_BRAIN_TUI=1 bash "$MENUS/context-brain/setup/install.sh" >/dev/null 2>&1 && [ -e "$MENUS/beta/CLAUDE.md" ] && [ ! -e "$MENUS/alpha/CLAUDE.md" ] && [ ! -e "$MENUS/beta/.git/hooks/commit-msg" ]'
check "choosing Yes installs the commit rules" 'printf "\n%s\n\n" "$DOWN" | CONTEXT_BRAIN_TUI=1 bash "$MENUS/context-brain/setup/install.sh" >/dev/null 2>&1 && [ -e "$MENUS/alpha/.git/hooks/commit-msg" ]'
check "no menus without a terminal" 'out=$(bash "$MENUS/context-brain/setup/install.sh" </dev/null 2>&1); [ $? -ne 0 ] && printf "%s" "$out" | grep -q "usage:"'

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
