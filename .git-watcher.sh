#!/bin/bash
# Auto-commit and push every 60 seconds if there are changes
cd /Users/jeaneast/Documents/projects/ClipCourt
while true; do
  sleep 60
  if [ -n "$(git status --porcelain)" ]; then
    git add -A
    CHANGES=$(git diff --cached --stat | tail -1)
    git commit -m "🤖 Auto-commit: $CHANGES"
    git push origin main 2>/dev/null
  fi
done
