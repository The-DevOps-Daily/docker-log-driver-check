#!/usr/bin/env bash
# Point Fluent Bit's tail input at each container's log directory, the way a
# Docker host config usually does (/var/lib/docker/containers/*/*.log with the
# docker parser), and count the records it reads. Then point it straight at the
# local driver's own file, to show what a file reader gets from that format.
source "$(dirname "$0")/lib.sh"

FLUENT_BIT=${FLUENT_BIT:-fluent/fluent-bit:5.1.3}
root=$(root_dir)
$DOCKER pull -q "$FLUENT_BIT" >/dev/null

# tail <path inside the collector> <output plugin> -> collector output on stdout
tail_with() {
  cat > "$RUN_DIR/fluent-bit.yaml" <<YAML
service:
  flush: 1
  log_level: warn
parsers:
  - name: docker
    format: json
    time_key: time
    time_format: "%Y-%m-%dT%H:%M:%S.%L"
pipeline:
  inputs:
    - name: tail
      path: $1
      parser: docker
      read_from_head: true
      exit_on_eof: true
      buffer_max_size: 1M
  outputs:
    - name: $2
      match: '*'
YAML
  $DOCKER rm -f logs-fluent-bit >/dev/null 2>&1 || true
  # The image's entrypoint is fluent-bit itself; it has no shell.
  $DOCKER run -d --name logs-fluent-bit --network none --log-driver local \
    -v "$root/containers:/var/lib/docker/containers:ro" \
    -v "$PWD/$RUN_DIR/fluent-bit.yaml:/fluent-bit.yaml:ro" \
    --entrypoint /fluent-bit/bin/fluent-bit "$FLUENT_BIT" -c /fluent-bit.yaml >/dev/null
  timeout 600 $DOCKER wait logs-fluent-bit >/dev/null || true
  $DOCKER logs logs-fluent-bit 2>&1
  $DOCKER rm -f logs-fluent-bit >/dev/null
}

{
  echo "Fluent Bit: $($DOCKER run --rm --network none "$FLUENT_BIT" /fluent-bit/bin/fluent-bit --version | head -1)"
  echo
  echo "== the usual Docker host pattern: <container dir>/*.log, docker parser"
  for name in logs-json-default logs-json-capped logs-local; do
    id=$($DOCKER inspect --format '{{.Id}}' "$name")
    # The counter output prints one JSON line per flush with that flush's log_records.
    total=$(tail_with "/var/lib/docker/containers/$id/*.log" counter | sed -n 's/.*"log_records":\([0-9]*\).*/\1/p' | awk '{ s += $1 } END { print s + 0 }')
    printf '%-18s records read: %s\n' "$name" "${total:-0}"
  done
  echo
  echo "== aimed at the local driver's own file: local-logs/container.log"
  id=$($DOCKER inspect --format '{{.Id}}' logs-local)
  tail_with "/var/lib/docker/containers/$id/local-logs/container.log" stdout > "$RUN_DIR/03-local-raw.out"
  echo "records read: $(grep -ac '^\[[0-9]*\] tail' "$RUN_DIR/03-local-raw.out" || true)"
  # A record the docker parser understood has a stream field; a failed parse keeps only the raw "log" text.
  echo "records the docker parser could parse: $(grep -ac '"stream"=>' "$RUN_DIR/03-local-raw.out" || true)"
  echo "records 2 and 3, control bytes shown with cat -v:"
  grep -a '^\[[0-9]*\] tail' "$RUN_DIR/03-local-raw.out" | sed -n '2,3p' | cut -c1-200 | cat -v
  # Keep the first 20 records; the whole output is tens of megabytes.
  grep -a '^\[[0-9]*\] tail' "$RUN_DIR/03-local-raw.out" | head -20 | cat -v > "$RUN_DIR/03-local-raw-head.txt"
  rm -f "$RUN_DIR/03-local-raw.out"
} | tee "$RUN_DIR/03-collector.txt"
