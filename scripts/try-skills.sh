#!/usr/bin/env bash
# Start pi with this repo's skills instead of the installed ones. Installed skills and pi
# settings are untouched. Skills load live from the repo, so run /reload after an edit.
#
# Usage: scripts/try-skills.sh [skill ...] [-- pi-args ...]
#   scripts/try-skills.sh                           all repo skills
#   scripts/try-skills.sh caidan-mode how why       only these
#   scripts/try-skills.sh bro -- -p "..." --no-session
set -euo pipefail

skills_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills" && pwd)"
args=(--no-skills)
picked=0
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
	[ -f "$skills_dir/$1/SKILL.md" ] || { echo "no such skill: $1" >&2; exit 1; }
	args+=(--skill "$skills_dir/$1")
	picked=$((picked + 1))
	shift
done
[ "${1:-}" = "--" ] && shift
[ "$picked" -eq 0 ] && args+=(--skill "$skills_dir")

# Ponytail's always-on persona would mix with the skills under test.
PONYTAIL_DEFAULT_MODE=off exec pi "${args[@]}" "$@"
