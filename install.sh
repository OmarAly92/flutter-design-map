#!/usr/bin/env bash
#
# Universal installer: symlink this repo's skills into the agent skills dir.
# Works for any agent that reads SKILL.md files from ~/.claude/skills/.
# Override the target with CLAUDE_SKILLS_DIR=/some/path ./install.sh
#
# The link is a symlink on purpose: flutter-map shells out to the Dart parser at
# <repo>/packages/flutter_map_parser, and SKILL.md finds it by resolving its own
# directory back through the symlink. Copying the skill instead would break that.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
PARSER="$REPO_DIR/packages/flutter_map_parser"

mkdir -p "$TARGET"

count=0
for dir in "$REPO_DIR"/skills/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  link="$TARGET/$name"
  rm -rf "$link"
  ln -s "${dir%/}" "$link"
  echo "linked $name -> $link"
  count=$((count + 1))
done

echo "Installed $count skill(s) into $TARGET."

if [ ! -d "$PARSER" ]; then
  echo "warning: parser package not found at $PARSER" >&2
elif ! command -v dart >/dev/null 2>&1; then
  echo "warning: 'dart' is not on PATH — the skill needs it to run the parser." >&2
else
  echo "Fetching parser dependencies..."
  (cd "$PARSER" && dart pub get >/dev/null) && echo "parser ready at $PARSER"
fi

echo "Restart your agent to pick them up."
