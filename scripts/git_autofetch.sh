#!/bin/sh
#
# git_autofetch.sh – auto-update all git repos under a given base dir
#

BASE="${1:-/root/scripts}"   # default to /root/scripts if not specified
INTERVAL="${2:-60}"          # default 60 seconds if not specified
LOG="/var/log/git_autofetch.log"

echo "[$(date '+%F %T')] git_autofetch started - BASE: $BASE, INTERVAL: ${INTERVAL}s" >> "$LOG"

while true; do
    echo "[$(date '+%F %T')] Starting git update cycle" >> "$LOG"
    
    if [ ! -d "$BASE" ]; then
        echo "[$(date '+%F %T')] Base directory $BASE does not exist, creating..." >> "$LOG"
        mkdir -p "$BASE"
    fi
    
    find "$BASE" -type d -name ".git" 2>/dev/null | while read -r gitdir; do
        repo="$(dirname "$gitdir")"
        echo "[$(date '+%F %T')] Updating $repo" >> "$LOG"
        (
            cd "$repo" || exit
            if [ -d ".git" ]; then
                git fetch origin >> "$LOG" 2>&1
                if git reset --hard origin/main >> "$LOG" 2>&1; then
                    echo "[$(date '+%F %T')] Successfully updated $repo (main branch)" >> "$LOG"
                elif git reset --hard origin/master >> "$LOG" 2>&1; then
                    echo "[$(date '+%F %T')] Successfully updated $repo (master branch)" >> "$LOG"
                else
                    echo "[$(date '+%F %T')] Failed to update $repo" >> "$LOG"
                fi
            fi
        )
    done
    
    echo "[$(date '+%F %T')] Update cycle completed, sleeping ${INTERVAL}s" >> "$LOG"
    sleep "$INTERVAL"
done
