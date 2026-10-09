#!/usr/bin/env bash
# For each container: the files the driver wrote, their size on disk, what the
# first bytes look like, and how many lines `docker logs` gives back.
source "$(dirname "$0")/lib.sh"

out="$RUN_DIR/02-measure.txt"
: > "$out"
printf '%-18s %-10s %12s %6s %12s %14s\n' container driver bytes_on_disk files lines_kept bytes_of_text | tee -a "$out"
for name in logs-json-default logs-json-capped logs-local; do
  dir=$(container_dir "$name")
  files=$(sudo find "$dir" -type f \( -name '*.log*' -o -path '*local-logs*' \) | sort)
  bytes=$(echo "$files" | xargs sudo stat -c %s | awk '{ s += $1 } END { print s }')
  count=$(echo "$files" | wc -l)
  # What `docker logs` can still give back, and how many bytes of plain text that is.
  lines=$($DOCKER logs "$name" 2>&1 | wc -l)
  text=$($DOCKER logs "$name" 2>&1 | wc -c)
  printf '%-18s %-10s %12s %6s %12s %14s\n' "$name" "$(log_type "$name")" "$bytes" "$count" "$lines" "$text" | tee -a "$out"
done
for name in logs-json-default logs-json-capped logs-local; do
  dir=$(container_dir "$name")
  {
    echo
    echo "== $name: files under the container directory"
    sudo find "$dir" -type f \( -name '*.log*' -o -path '*local-logs*' \) -printf '%P %s\n' | sort
    first=$(sudo find "$dir" -type f \( -name '*.log' -o -path '*local-logs/container.log' \) | head -1)
    echo "== $name: first 160 bytes of ${first#"$dir"/}"
    sudo head -c 160 "$first" | od -c | head -6
  } | tee -a "$out"
done
