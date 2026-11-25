#!/usr/bin/env bash
# Install / link / inspect the minecraft-mod-designer skill in ~/.claude/skills.
#
# The repo root is the skill payload (SKILL.md + references/).
#
#   install    copy repo -> ~/.claude/skills/minecraft-mod-designer (replaces what's there)
#   link       symlink repo -> that path instead (repo edits go live immediately)
#   diff       report drift between repo and the installed copy
#   pull       copy installed copy -> repo (capture edits made in ~/.claude)
#   uninstall  remove the installed copy/link
#   status     show what is currently installed
set -euo pipefail

SKILL_NAME="minecraft-mod-designer"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$HOME/.claude/skills/$SKILL_NAME"
PAYLOAD=(SKILL.md references)

remove_target() {
  if [ -L "$TARGET" ]; then rm "$TARGET"
  elif [ -e "$TARGET" ]; then rm -rf "$TARGET"
  fi
}

cmd_status() {
  if [ -L "$TARGET" ]; then echo "linked: $TARGET -> $(readlink "$TARGET")"
  elif [ -d "$TARGET" ]; then echo "copied: $TARGET"
  else echo "not installed: $TARGET"
  fi
}

cmd_install() {
  remove_target
  mkdir -p "$TARGET"
  for entry in "${PAYLOAD[@]}"; do cp -r "$REPO_ROOT/$entry" "$TARGET/"; done
  echo "installed (copy): $TARGET"
}

cmd_link() {
  remove_target
  mkdir -p "$(dirname "$TARGET")"
  # Git Bash on Windows needs MSYS=winsymlinks:nativestrict + Developer Mode for a real symlink.
  ln -s "$REPO_ROOT" "$TARGET"
  echo "linked: $TARGET -> $REPO_ROOT"
}

cmd_diff() {
  if [ -L "$TARGET" ]; then echo "linked to the repo - no drift possible"; return; fi
  if [ ! -d "$TARGET" ]; then echo "not installed: $TARGET"; return; fi
  local drift=0
  for entry in "${PAYLOAD[@]}"; do
    if diff -ru "$REPO_ROOT/$entry" "$TARGET/$entry"; then :; else drift=1; fi
  done
  [ "$drift" -eq 0 ] && echo "in sync"
  return 0
}

cmd_pull() {
  [ -d "$TARGET" ] || { echo "nothing installed at $TARGET" >&2; exit 1; }
  if [ -L "$TARGET" ]; then echo "linked to the repo - nothing to pull"; return; fi
  for entry in "${PAYLOAD[@]}"; do
    [ -e "$TARGET/$entry" ] || continue
    rm -rf "${REPO_ROOT:?}/$entry"
    cp -r "$TARGET/$entry" "$REPO_ROOT/"
  done
  echo "pulled into repo: $REPO_ROOT (review with git diff before committing)"
}

case "${1:-help}" in
  install)   cmd_install ;;
  link)      cmd_link ;;
  diff)      cmd_diff ;;
  pull)      cmd_pull ;;
  uninstall) remove_target; echo "removed: $TARGET" ;;
  status)    cmd_status ;;
  *)         sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
esac
