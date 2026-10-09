#!/usr/bin/env bash
# Start three containers that each write the same $LINES log lines, about 100
# bytes each, and wait for them to finish:
#   logs-json-default  json-file with no options (what Docker Engine does out of the box)
#   logs-json-capped   json-file with max-size=10m and max-file=3
#   logs-local         the local driver with its defaults (what Docker Desktop 4.94 now uses)
source "$(dirname "$0")/lib.sh"

writer='awk -v n="$LINES" "BEGIN { for (i = 1; i <= n; i++) printf \"2026-10-09T10:00:00.%06dZ level=info msg=\\\"GET /api/v1/orders 200\\\" req_id=%08d bytes=%d\\n\", i % 1000000, i, (i * 7919) % 50000 }"'

$DOCKER pull -q "$IMAGE" >/dev/null
for spec in "logs-json-default|--log-driver json-file" \
            "logs-json-capped|--log-driver json-file --log-opt max-size=10m --log-opt max-file=3" \
            "logs-local|--log-driver local"; do
  name=${spec%%|*}; flags=${spec#*|}
  $DOCKER rm -f "$name" >/dev/null 2>&1 || true
  # shellcheck disable=SC2086
  $DOCKER run -d --name "$name" --network none -e LINES="$LINES" $flags "$IMAGE" sh -c "$writer" >/dev/null
done
for name in logs-json-default logs-json-capped logs-local; do
  $DOCKER wait "$name" >/dev/null
  echo "$name: driver=$(log_type "$name") options=$(log_opts "$name")"
done | tee "$RUN_DIR/01-write-logs.txt"
