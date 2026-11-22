#!/usr/bin/env bash
# Installs the brain: AGENTS.md and CLAUDE.md entry points, git hooks, Claude Code settings.
# Safe to re-run: existing files are backed up, and anything already in place is skipped.
#
#   Separate repo, next to the project:   bash context-brain/setup/install.sh <project-folder> [options]
#   Inside the project repo:              bash brain/setup/install.sh [options]
#
# Options. Flags only: with no terminal nothing prompts, so scripts, CI and cloud agents are safe.
#   --commit-rules        also install the commit-msg hook and empty Claude Code's attribution setting
#   --hooks-only          install only the git hooks and AGENTS.md; skip every Claude Code file
#                         (CLAUDE.md, .claude/settings.local.json, ~/.claude/settings.json)
#   --agents-md-primary   AGENTS.md holds the shared text and CLAUDE.md only imports it and the brain
#                         index. Existing CLAUDE.md content moves into AGENTS.md (backup kept).
#
set -euo pipefail

BRAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRAIN_NAME="$(basename "$BRAIN_DIR")"
PARENT_DIR="$(dirname "$BRAIN_DIR")"

PROJECT=""
COMMIT_RULES=""
HOOKS_ONLY=0
AGENTS_PRIMARY=0
for arg in "$@"; do
    case "$arg" in
        --commit-rules) COMMIT_RULES=1 ;;
        --hooks-only) HOOKS_ONLY=1 ;;
        --agents-md-primary) AGENTS_PRIMARY=1 ;;
        --*) printf 'error: unknown option %s\n' "$arg" >&2; exit 1 ;;
        *) PROJECT="$(basename "$arg")" ;;
    esac
done
if [ "$HOOKS_ONLY" = 1 ] && [ "$AGENTS_PRIMARY" = 1 ]; then
    printf 'error: --agents-md-primary edits CLAUDE.md, which --hooks-only leaves alone\n' >&2
    exit 1
fi

ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; }
skip() { printf '  \033[33mskip\033[0m  %s\n' "$1"; }
die()  { printf '\n\033[31merror:\033[0m %s\n\n' "$1" >&2; exit 1; }

# Menus only when a person runs it in a terminal; flags and scripts never see a prompt.
# CONTEXT_BRAIN_TUI=1 forces them on, so the tests can drive the menus with piped keys.
TUI=0
if [ "${CONTEXT_BRAIN_TUI:-}" = 1 ] || { [ -t 0 ] && [ -t 1 ]; }; then TUI=1; fi

# menu "Question" "option" ... - arrow keys (or j/k) and Enter; the chosen index lands in CHOICE.
menu() {
    local title="$1"; shift
    local opts=("$@") sel=0 n=$# key i
    printf '\n  \033[1m%s\033[0m  \033[2m(arrows, Enter)\033[0m\n' "$title"
    printf '\033[?25l'
    while true; do
        for i in "${!opts[@]}"; do
            if [ "$i" -eq "$sel" ]; then printf '  \033[36m> %s\033[0m\033[K\n' "${opts[$i]}"
            else printf '    %s\033[K\n' "${opts[$i]}"; fi
        done
        IFS= read -rsn1 key || key=""
        case "$key" in
            $'\x1b') IFS= read -rsn2 key || true
                     case "$key" in '[A') sel=$(( (sel + n - 1) % n )) ;; '[B') sel=$(( (sel + 1) % n )) ;; esac ;;
            k) sel=$(( (sel + n - 1) % n )) ;;
            j) sel=$(( (sel + 1) % n )) ;;
            "") break ;;
        esac
        printf '\033[%dA' "$n"
    done
    printf '\033[?25h'
    CHOICE=$sel
}
[ "$TUI" = 1 ] && trap 'printf "\033[?25h"' EXIT
if [ "$TUI" = 1 ]; then
    printf '\n  \033[1;36mcontext-brain\033[0m setup\n  \033[2mverified context for AI agents and the team beside them\033[0m\n'
    printf '\n  \033[2mThis connects the brain to your project so every AI session starts by reading it.\n'
    printf '  You will get a summary to confirm before anything changes; existing files are backed up.\033[0m\n'
fi

# ---------------------------------------------------------------- prerequisites
command -v git >/dev/null || die "git is not installed."
# Windows often has a python3 that is only a Microsoft Store stub, so test that it really runs.
PY=""
for candidate in python3 python; do
    if "$candidate" -c "import sys; sys.exit(sys.version_info < (3, 8))" >/dev/null 2>&1; then
        PY="$(command -v "$candidate")"
        break
    fi
done
[ -n "$PY" ] || die "Python 3.8+ is not installed (the hooks parse JSON with it)."

# A brain folder that is not its own repo but sits inside one is installed in-repo.
if [ ! -e "$BRAIN_DIR/.git" ] && git -C "$BRAIN_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    MODE=in-repo
    REL="$(git -C "$BRAIN_DIR" rev-parse --show-prefix)"
    REL="${REL%/}"
    PROJECT_DIR="$(cd "$BRAIN_DIR/$(git -C "$BRAIN_DIR" rev-parse --show-cdup)" && pwd)"
    [ -z "$PROJECT" ] || die "the brain is inside a repo, so no project folder is needed: bash $REL/setup/install.sh"
else
    MODE=separate
    if [ -z "$PROJECT" ] && [ "$TUI" = 1 ]; then
        CANDIDATES=()
        for d in "$PARENT_DIR"/*/; do
            d="$(basename "$d")"
            if [ "$d" != "$BRAIN_NAME" ] && [ -d "$PARENT_DIR/$d/.git" ]; then CANDIDATES+=("$d"); fi
        done
        [ ${#CANDIDATES[@]} -gt 0 ] || die "no git repository next to the brain in $PARENT_DIR. Clone your project there, or put the brain inside it."
        printf '\n  \033[2mThese are the git repositories next to the brain. The one you pick gets an entry file\n'
        printf '  that points the AI agents at this brain, plus the git hooks that keep the brain current.\033[0m\n'
        menu "Which project should this brain serve?" "${CANDIDATES[@]}"
        PROJECT="${CANDIDATES[$CHOICE]}"
    fi
    [ -n "$PROJECT" ] || die "usage: bash $BRAIN_NAME/setup/install.sh <project-folder> [--commit-rules] [--hooks-only] [--agents-md-primary]
(or put the brain folder inside your project repo and run it with no project folder)"
    PROJECT_DIR="$PARENT_DIR/$PROJECT"
    [ -d "$PROJECT_DIR" ] || die "No '$PROJECT' folder next to the brain. The two must be siblings:
  $PARENT_DIR/$PROJECT/
  $PARENT_DIR/$BRAIN_NAME/"
    [ -d "$PROJECT_DIR/.git" ] || die "$PROJECT_DIR is not a git repository."
    [ -d "$BRAIN_DIR/.git" ]   || die "$BRAIN_DIR is not a git repository (git init it first)."
fi

# How the project's files refer to the brain: the folder inside the repo, or the sibling folder.
if [ "$MODE" = in-repo ]; then BRAIN_REF="$REL"; else BRAIN_REF="../$BRAIN_NAME"; fi

if [ -z "$COMMIT_RULES" ] && [ "$TUI" = 1 ]; then
    printf '\n  \033[2mOptional commit-message rules. When on, a commit is refused if its message:\n'
    printf '    - is longer than one summary line (one short extra line is fine), or\n'
    printf '    - carries AI attribution: the "Co-Authored-By: Claude" or "Generated with Claude Code"\n'
    printf '      lines that AI tools add to commits and PRs to credit themselves.\n'
    if [ "$HOOKS_ONLY" = 1 ]; then
        printf '  Claude Code settings are left alone (--hooks-only).\033[0m\n'
        menu "Turn on the commit-message rules?" \
            "No, leave commit messages alone" "Yes, enforce them"
    else
        printf '  Claude Code adds those lines by default, so "Yes" also turns that off in\n'
        printf '  ~/.claude/settings.json (your settings for every project). Otherwise the two would\n'
        printf '  fight and every commit Claude makes would be refused. Choose "No" to keep both as they are.\033[0m\n'
        menu "Turn on the commit-message rules?" \
            "No, leave commit messages alone" "Yes, enforce them (and stop Claude Code adding attribution)"
    fi
    COMMIT_RULES=$CHOICE
fi
COMMIT_RULES="${COMMIT_RULES:-0}"

if [ "$TUI" = 1 ]; then
    if [ "$MODE" = separate ]; then WHERE="separate repo next to $PROJECT"; else WHERE="inside the project, as $REL/"; fi
    if [ "$COMMIT_RULES" = 1 ]; then RULES="yes"; else RULES="no"; fi
    printf '\n  \033[1mReady to install\033[0m\n'
    printf '    brain     %s\n    mode      %s\n    project   %s\n    commit rules  %s\n' \
        "$BRAIN_DIR" "$WHERE" "$PROJECT_DIR" "$RULES"
    if [ "$HOOKS_ONLY" = 1 ]; then printf '    claude code   skipped (--hooks-only)\n'; fi
    menu "Go ahead?" "Install" "Cancel"
    [ "$CHOICE" = 0 ] || { printf '\n  Cancelled. Nothing was changed.\n\n'; exit 0; }
fi

echo ""
echo "brain setup ($MODE)"
echo "  brain:    $BRAIN_DIR"
echo "  project:  $PROJECT_DIR"
echo ""
echo "prerequisites"
ok "git and $(basename "$PY") present"
if [ "$MODE" = separate ]; then ok "$PROJECT and $BRAIN_NAME are siblings"; else ok "brain is $REL/ inside the project repo"; fi
echo ""

# ------------------------------------------------------------------ brain paths
# Paths in the brain are written from the project root, where every agent works. Brain-internal,
# so it runs with --hooks-only too: Codex reads the same index as Claude Code.
echo "brain paths"
if [ "$MODE" = in-repo ]; then
    "$PY" - "$BRAIN_DIR" "$REL" <<'PYEOF'
import pathlib, sys
brain, rel = pathlib.Path(sys.argv[1]), sys.argv[2]
old = {"../context-brain/", f"../{brain.name}/"}
changed = 0
for f in brain.rglob("*.md"):
    text = f.read_text(encoding="utf-8")
    new = text
    for o in old:
        new = new.replace(o, f"{rel}/")
    if new != text:
        with open(f, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(new)
        changed += 1
print(f"  \033[32mok\033[0m    rewrote brain paths to {rel}/ in {changed} file(s)" if changed
      else f"  \033[33mskip\033[0m  brain paths already written as {rel}/")
PYEOF
else
    skip "separate repo: brain paths are already $BRAIN_REF/"
fi
[ -f "$BRAIN_DIR/CLAUDE.md" ] || die "the brain has no CLAUDE.md - check the folder layout."
echo ""

# --------------------------------------------- AGENTS.md (Codex and other agents)
# Codex reads AGENTS.md at the repo root and ignores @imports, so the pointer is written as plain text.
echo "AGENTS.md (Codex and other agents)"
"$PY" - "$PROJECT_DIR" "$BRAIN_REF" "$AGENTS_PRIMARY" <<'PYEOF'
import datetime, pathlib, sys

project, ref, primary = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3] == "1"
agents, claude = project / "AGENTS.md", project / "CLAUDE.md"
imp = f"@{ref}/CLAUDE.md"
BEGIN, END = "<!-- context-brain:begin -->", "<!-- context-brain:end -->"
BLOCK = f"""{BEGIN}
## Context brain

This project keeps its verified context in a brain. Before a task, open its index, `{ref}/CLAUDE.md`,
and read the topic files for the area you are touching. When you learn a verified fact, make a
decision or fix a documented bug, write it back into the brain, following
`{ref}/rules/brain-maintenance/overview.md`.
{END}
"""
OK = "  \033[32mok\033[0m    %s"
SKIP = "  \033[33mskip\033[0m  %s"


def backup(path):
    dst = path.with_name(path.name + ".backup." + datetime.datetime.now().strftime("%Y%m%d%H%M%S"))
    dst.write_bytes(path.read_bytes())
    return dst


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def join(a, b):
    a = a.rstrip()
    return (a + "\n\n" if a else "") + b


# 1. CLAUDE.md, only with --agents-md-primary: AGENTS.md holds the text, CLAUDE.md just imports it.
moved = ""
claude_action = None
if primary:
    stub = ["@AGENTS.md", imp]
    real_file = claude.is_file() and not claude.is_symlink()
    if real_file and [l.strip() for l in claude.read_text(encoding="utf-8").splitlines() if l.strip()] == stub:
        print(SKIP % "CLAUDE.md already imports AGENTS.md and the brain index")
    else:
        if claude.is_symlink():
            claude.unlink()  # the link itself only: the brain index it pointed at is never copied
            claude_action = "replaced the CLAUDE.md link"
        elif real_file:
            text = claude.read_text(encoding="utf-8")
            moved = "\n".join(l for l in text.splitlines() if l.strip() != imp).strip()
            backup_path = backup(claude)
            claude.unlink()
            claude_action = "moved the existing CLAUDE.md into AGENTS.md (backup: %s)" % backup_path.name
        else:
            claude_action = "created CLAUDE.md"

# 2. AGENTS.md: keep what is there, add the marked block once.
old_agents = agents.read_text(encoding="utf-8") if agents.is_file() else ""
new_agents = old_agents
if moved:
    new_agents = join(new_agents, moved + "\n")
if BEGIN not in new_agents:
    new_agents = join(new_agents, BLOCK)
if new_agents != old_agents:
    if agents.is_file():
        backup_path = backup(agents)
        print(OK % "backed up AGENTS.md to %s" % backup_path.name)
    write(agents, new_agents + ("" if new_agents.endswith("\n") else "\n"))
    if old_agents:
        print(OK % "added the brain pointer to AGENTS.md")
    else:
        print(OK % "created AGENTS.md with the brain pointer")
else:
    print(SKIP % "AGENTS.md already points at the brain")

if claude_action:
    if primary:
        write(claude, "@AGENTS.md\n" + imp + "\n")
    print(OK % ("%s; it now imports AGENTS.md and %s" % (claude_action, imp)))
PYEOF
echo ""

# ------------------------------------------------------------------- CLAUDE.md
if [ "$HOOKS_ONLY" = 0 ] && [ "$AGENTS_PRIMARY" = 0 ]; then
    echo "CLAUDE.md"
    LINK="$PROJECT_DIR/CLAUDE.md"
    if [ "$MODE" = in-repo ]; then
        IMPORT="@$REL/CLAUDE.md"
        if [ -f "$LINK" ] && grep -qxF "$IMPORT" "$LINK"; then
            skip "CLAUDE.md already imports $REL/CLAUDE.md"
        elif [ -f "$LINK" ]; then
            cp "$LINK" "$LINK.backup.$(date +%Y%m%d%H%M%S)"
            printf '\n%s\n' "$IMPORT" >> "$LINK"
            ok "added '$IMPORT' to the existing CLAUDE.md (backup kept)"
        else
            printf '%s\n' "$IMPORT" > "$LINK"
            ok "created CLAUDE.md importing $REL/CLAUDE.md"
        fi
    else
        TARGET="../$BRAIN_NAME/CLAUDE.md"
        STUB="@$TARGET"
        if [ -L "$LINK" ] && [ "$(readlink "$LINK")" = "$TARGET" ]; then
            skip "already linked -> $TARGET"
        elif [ -f "$LINK" ] && [ ! -L "$LINK" ] && [ "$(cat "$LINK")" = "$STUB" ]; then
            skip "already imports $TARGET"
        else
            if [ -e "$LINK" ] && [ ! -L "$LINK" ]; then
                mv "$LINK" "$LINK.backup.$(date +%Y%m%d%H%M%S)"
                ok "backed up the existing CLAUDE.md"
            fi
            # Git Bash silently copies on a plain ln -s; nativestrict makes it a real link or a clear failure.
            if MSYS=winsymlinks:nativestrict ln -sfn "$TARGET" "$LINK" 2>/dev/null && [ -L "$LINK" ]; then
                ok "linked $PROJECT/CLAUDE.md -> $TARGET"
            else
                rm -f "$LINK"
                printf '%s\n' "$STUB" > "$LINK"
                ok "symlinks unavailable (Windows without Developer Mode): $PROJECT/CLAUDE.md imports $TARGET"
            fi
        fi
    fi
    echo ""
fi

# -------------------------------------------------------------------- git hooks
echo "git hooks"
install_hook() {
    local src="$1" dest="$2" label="$3"
    if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
        skip "$label already current"
        return
    fi
    if [ -f "$dest" ]; then
        cp "$dest" "$dest.backup.$(date +%Y%m%d%H%M%S)"
        ok "backed up existing $label"
    fi
    cp "$src" "$dest"
    chmod +x "$dest"
    ok "installed $label"
}

PROJECT_HOOKS="$(git -C "$PROJECT_DIR" rev-parse --git-path hooks)"
case "$PROJECT_HOOKS" in /*|?:*) ;; *) PROJECT_HOOKS="$PROJECT_DIR/$PROJECT_HOOKS" ;; esac
mkdir -p "$PROJECT_HOOKS"
PROJECT_HOOK="$(mktemp)"
if [ "$MODE" = in-repo ]; then
    # Calls the tracked scripts, so a pulled hook change applies without re-installing.
    cat > "$PROJECT_HOOK" <<HOOK
#!/usr/bin/env bash
# Installed by $REL/setup/install.sh: brain rules, then "source changes come with a brain change".
REPO_DIR="\$(git rev-parse --show-toplevel)"
export BRAIN_DIR="\$REPO_DIR/$REL"
bash "\$BRAIN_DIR/setup/hooks/pre-commit-brain" || exit 1
bash "\$BRAIN_DIR/setup/hooks/pre-commit-same-commit" || exit 1
HOOK
    install_hook "$PROJECT_HOOK" "$PROJECT_HOOKS/pre-commit" "project pre-commit (brain rules + same-commit check)"
else
    sed "s/__BRAIN_NAME__/$BRAIN_NAME/g" "$BRAIN_DIR/setup/hooks/pre-commit-project" > "$PROJECT_HOOK"
    install_hook "$BRAIN_DIR/setup/hooks/pre-commit-brain" "$BRAIN_DIR/.git/hooks/pre-commit" "brain pre-commit (structural rules)"
    install_hook "$PROJECT_HOOK" "$PROJECT_HOOKS/pre-commit" "project pre-commit (brain staleness)"
fi
rm -f "$PROJECT_HOOK"
if [ "$COMMIT_RULES" -eq 1 ]; then
    install_hook "$BRAIN_DIR/setup/hooks/commit-msg" "$PROJECT_HOOKS/commit-msg" "project commit-msg"
    if [ "$MODE" = separate ]; then
        install_hook "$BRAIN_DIR/setup/hooks/commit-msg" "$BRAIN_DIR/.git/hooks/commit-msg" "brain commit-msg"
    fi
fi
echo ""

if [ "$HOOKS_ONLY" = 0 ]; then
# ------------------------------------------------------- Claude Code settings
echo "Claude Code settings (.claude/settings.local.json)"
mkdir -p "$PROJECT_DIR/.claude"
"$PY" - "$PY" "$PROJECT_DIR" "$BRAIN_DIR" "$MODE" <<'PYEOF'
import json, pathlib, shlex, sys

py, project, brain, mode = shlex.quote(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]), sys.argv[4]
hooks_dir = brain / "setup" / "hooks"
p = project / ".claude" / "settings.local.json"
try:
    cfg = json.loads(p.read_text())
except Exception:
    cfg = {}

hooks = cfg.setdefault("hooks", {})

def replace(event, marker, entry):
    entries = hooks.setdefault(event, [])
    entries[:] = [e for e in entries
                  if not any(marker in h.get("command", "") for h in e.get("hooks", []))]
    entries.append(entry)

# In-repo the brain travels with the code: it is already in the project and needs no sync hooks.
if mode == "separate":
    cfg.setdefault("env", {})["CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD"] = "1"
    dirs = cfg.setdefault("permissions", {}).setdefault("additionalDirectories", [])
    if f"../{brain.name}" not in dirs:
        dirs.append(f"../{brain.name}")
    # Machine-local file, so absolute paths are fine here.
    for event, script, msg in [
        ("SessionStart", "brain-staleness-check.py", "Checking the brain is up to date"),
        ("Stop", "brain-unpushed-check.py", "Pushing brain commits"),
    ]:
        replace(event, script, {"hooks": [{
            "type": "command",
            "command": py + " " + shlex.quote(hooks_dir.joinpath(script).as_posix()),
            "timeout": 20,
            "statusMessage": msg,
        }]})

# Inlined so a moved or missing brain can never turn into "every Bash command is blocked".
guard = (hooks_dir / "block-destructive-db.py").read_text()
replace("PreToolUse", "destructive-database guard", {
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": py + " -c " + shlex.quote(guard), "timeout": 10,
               "statusMessage": "Checking for destructive database commands"}],
})

p.write_text(json.dumps(cfg, indent=2) + "\n")
print("  \033[32mok\033[0m    " + ("brain on the agent's path, sync hooks, destructive-database guard"
                                 if mode == "separate" else "destructive-database guard"))
PYEOF
echo ""
fi

# ------------------------------------------- attribution (only with --commit-rules)
if [ "$COMMIT_RULES" -eq 1 ] && [ "$HOOKS_ONLY" = 0 ]; then
    echo "attribution setting (~/.claude/settings.json)"
    mkdir -p "$HOME/.claude"
    "$PY" - "$HOME/.claude/settings.json" <<'PYEOF'
import json, pathlib, shutil, sys, datetime

p = pathlib.Path(sys.argv[1])
try:
    cfg = json.loads(p.read_text())
except Exception:
    cfg = {}
want = {"commit": "", "pr": "", "sessionUrl": False}
current = cfg.get("attribution")
if current == want:
    print("  \033[33mskip\033[0m  attribution already empty")
elif isinstance(current, dict) and current:
    print("  \033[33mskip\033[0m  you customised 'attribution' - left untouched: " + json.dumps(current))
else:
    if p.exists():
        shutil.copy(p, p.with_suffix(".json.backup." + datetime.datetime.now().strftime("%Y%m%d%H%M%S")))
    cfg["attribution"] = want
    p.write_text(json.dumps(cfg, indent=2) + "\n")
    print("  \033[32mok\033[0m    attribution emptied (commit, pr, sessionUrl)")
PYEOF
    echo ""
fi

# ------------------------------------------------------------------ verification
if [ "$HOOKS_ONLY" = 0 ]; then
    echo "verification"
    GUARD="$BRAIN_DIR/setup/hooks/block-destructive-db.py"
    printf '{"tool_input":{"command":"psql -c \\"drop database app\\""}}' | "$PY" "$GUARD" >/dev/null 2>&1 \
        && die "DB guard did NOT block a destructive command." || ok "DB guard blocks destructive commands"
    printf '{"tool_input":{"command":"git status"}}' | "$PY" "$GUARD" >/dev/null 2>&1 \
        && ok "DB guard allows normal commands" || die "DB guard wrongly blocked a safe command."
    echo ""
fi

INDEX="$BRAIN_NAME/CLAUDE.md"; [ "$MODE" = in-repo ] && INDEX="$REL/CLAUDE.md"
cat <<DONE
Done. Start here:
  $INDEX     the index every agent reads (pointers only)
  AGENTS.md  the entry point Codex and other agents read; it points at the index
DONE
