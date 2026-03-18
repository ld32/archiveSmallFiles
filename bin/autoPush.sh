#!/usr/bin/env sh
set -eu

set -x 
 
# Watch the current repository by default; override with WATCH_DIR.
WATCH_DIR="${WATCH_DIR:-$(pwd)}"

if ! command -v inotifywait >/dev/null 2>&1; then
  echo "Error: inotifywait is not installed. Install inotify-tools first." >&2
  exit 1
fi
 
if ! git -C "$WATCH_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: WATCH_DIR is not inside a git repository: $WATCH_DIR" >&2
  exit 1
fi

branch="$(git -C "$WATCH_DIR" rev-parse --abbrev-ref HEAD)"

echo "Watching: $WATCH_DIR" 
echo "Auto-pushing to branch: $branch"

auto_push() {
  changed_file="$1"

  git -C "$WATCH_DIR" add -A 

  if git -C "$WATCH_DIR" diff --cached --quiet; then
    return 0  
  fi

  git -C "$WATCH_DIR" commit -m "Update ${changed_file} at $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null 2>&1 || true
  git -C "$WATCH_DIR" push origin "$branch"
} 
 
inotifywait -m -r -e close_write \
  --exclude '(vendor|\.git|\.vscode|node_modules|autoUpload\.sh|\.json)' \
  "$WATCH_DIR" | while read -r path action file; do
  if [ -n "$file" ]; then
    echo "[$(date '+%H:%M:%S')] ${action} ${path}${file}"
    auto_push "${file}"
  fi 
done 