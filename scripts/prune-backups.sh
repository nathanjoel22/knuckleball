#!/bin/bash
# A1 (Joel, Oct 14 2026): backups are kept 7 days (the privacy policy says a deleted account leaves the backups
# within 7 days). Deletes ~/knuckleball-backups/*.sql files older than 7 days -- top level only, .sql only;
# folders and anything else are never touched.
#   scripts/prune-backups.sh            list what would be deleted (changes nothing)
#   scripts/prune-backups.sh --delete   delete them (what the daily launchd job runs)
DIR="$HOME/knuckleball-backups"
[ -d "$DIR" ] || { echo "no $DIR"; exit 0; }
OLD=$(find "$DIR" -maxdepth 1 -type f -name '*.sql' -mtime +7 | sort)
[ -n "$OLD" ] || { echo "$(date '+%F %T') nothing older than 7 days"; exit 0; }
if [ "$1" = "--delete" ]; then
  echo "$OLD" | while IFS= read -r f; do rm -f -- "$f" && echo "$(date '+%F %T') deleted $(basename "$f")"; done
else
  echo "$OLD" | sed 's|.*/|would delete: |'; echo "$(echo "$OLD" | wc -l | tr -d ' ') file(s). Run with --delete to delete."
fi
