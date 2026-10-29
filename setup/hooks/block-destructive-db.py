import sys, json, re
# ponytail: a regex list, not a parser - catches the common forms, not every spelling. Add yours.
PATTERNS = [
    r"\bdrop\s+(database|schema)\b",
    r"\btruncate\s+table\b",
    r"artisan\s+(migrate:fresh|migrate:reset|db:wipe)",
    r"\brails\s+db:(drop|reset)",
    r"\bprisma\s+migrate\s+reset",
    r"\bdropdb\b",
]
try:
    c = json.load(sys.stdin).get("tool_input", {}).get("command", "") or ""
except Exception:
    sys.stderr.write("DB guard: unreadable hook input - blocking to fail safe\n")
    sys.exit(2)
if any(re.search(p, c, re.I) for p in PATTERNS):
    sys.stderr.write("BLOCKED by the destructive-database guard. Never run this on your own initiative. If the user explicitly asked for it, ask them to run it themselves.\n")
    sys.exit(2)
