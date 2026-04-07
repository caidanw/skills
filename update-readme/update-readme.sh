#!/usr/bin/env bash
# Regenerates the Available Skills table in README.md from SKILL.md frontmatters.
# Usage: bash update-readme/update-readme.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT/README.md"

skills_file=$(mktemp)
table_file=$(mktemp)
trap 'rm -f "$skills_file" "$table_file"' EXIT

# Parse name and description from a SKILL.md file.
# Handles inline values (quoted or unquoted) and block scalars (> and >-).
# Outputs: <name><TAB><description>
parse_skill() {
    awk '
    BEGIN { cnt=0; name=""; desc=""; in_desc=0 }
    /^---[[:space:]]*$/ {
        cnt++
        if (cnt == 2) exit
        next
    }
    cnt != 1 { next }
    /^description:[[:space:]]*[>|]/ { in_desc=1; next }
    /^description:[[:space:]]/ {
        in_desc=0
        val=$0; sub(/^description:[[:space:]]*/, "", val)
        gsub(/^[[:space:]"]+|[[:space:]"]+$/, "", val)
        desc=val
        next
    }
    /^name:[[:space:]]/ {
        in_desc=0
        val=$0; sub(/^name:[[:space:]]*/, "", val)
        gsub(/^[[:space:]"]+|[[:space:]"]+$/, "", val)
        name=val
        next
    }
    /^[a-zA-Z]/ { in_desc=0; next }
    in_desc && /^[[:space:]]/ {
        line=$0; sub(/^[[:space:]]+/, "", line)
        desc=(desc=="" ? line : desc " " line)
        next
    }
    END { printf "%s\t%s\n", name, desc }
    ' "$1"
}

# Return the first sentence of a string (up to the first .!?).
first_sentence() {
    awk '{
        if (match($0, /^[^.!?]+[.!?]/))
            print substr($0, RSTART, RLENGTH)
        else
            print $0
        exit
    }' <<< "$1"
}

# Collect one tab-separated line per skill: name <TAB> dir <TAB> description
for dir in "$ROOT"/*/; do
    skill_file="$dir/SKILL.md"
    [ -f "$skill_file" ] || continue

    result=$(parse_skill "$skill_file")
    name=$(printf '%s' "$result" | cut -f1)
    desc=$(printf '%s' "$result" | cut -f2-)

    if [ -z "$name" ] || [ -z "$desc" ]; then
        continue
    fi

    short=$(first_sentence "$desc")
    dirname=$(basename "$dir")
    printf '%s\t%s\t%s\n' "$name" "$dirname" "$short" >> "$skills_file"
done

# Sort case-insensitively by skill name
sort -f -o "$skills_file" "$skills_file"

# Build the Markdown table
printf '| Skill | Description |\n| --- | --- |\n' > "$table_file"
while IFS=$'\t' read -r name dirname desc; do
    printf '| [`%s`](./%s/) | %s |\n' "$name" "$dirname" "$desc" >> "$table_file"
done < "$skills_file"

# Replace the region between <!-- skills-start --> and <!-- skills-end --> in README.md
awk -v table="$table_file" '
    /<!-- skills-start -->/ { print; while ((getline line < table) > 0) print line; skip=1; next }
    /<!-- skills-end -->/ { skip=0 }
    !skip { print }
' "$README" > "$README.tmp" && mv "$README.tmp" "$README"

count=$(wc -l < "$skills_file" | tr -d ' ')
echo "✓ Updated README.md with $count skills"
