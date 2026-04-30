#!/usr/bin/env bash
# check-conventional-commits.sh — validate commit subjects against the Conventional Commits regex.
#
# Reads `<sha> <subject>` lines from stdin (e.g., the output of
# `git log <target>..HEAD --format='%H %s'`) and prints one JSON finding
# per non-conforming commit to stdout. Conforming commits produce no output.
#
# The recognized types default to the set listed in this repo's CLAUDE.md
# (feat fix docs refactor chore test style perf build ci revert). Override
# with the env var CC_TYPES (space-separated list) for repos with a
# different vocabulary.
#
# Requires: jq (used for safe JSON encoding).
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "check-conventional-commits.sh: requires 'jq' on PATH" >&2
  exit 1
fi

CC_TYPES="${CC_TYPES:-feat fix docs refactor chore test style perf build ci revert}"
TYPES_PIPE="$(printf '%s\n' $CC_TYPES | tr '\n' '|' | sed 's/|$//')"
REGEX="^(${TYPES_PIPE})(\([^)]+\))?!?: .+$"
RULE_QUOTE='<type>(<scope>): <short summary in imperative mood>'

while IFS= read -r line; do
  [ -n "$line" ] || continue
  sha="${line%% *}"
  subject="${line#* }"
  if [[ ! "$subject" =~ $REGEX ]]; then
    jq -nc \
      --arg sha "$sha" \
      --arg subject "$subject" \
      --arg regex "$REGEX" \
      --arg quote "$RULE_QUOTE" \
      '{
        tier: "hard_block",
        file: null,
        line: null,
        rule_quote: $quote,
        source_file: "CLAUDE.md",
        confidence: "high",
        message: "Commit \($sha) has subject \"\($subject)\" that does not match Conventional Commits regex \($regex)"
      }'
  fi
done
