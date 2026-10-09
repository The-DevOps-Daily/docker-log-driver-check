#!/usr/bin/env bash
# Show that a new daemon default only reaches containers created after it.
#   04-default-change.sh before   create logs-before with the daemon's current default
#   (restart the daemon with "log-driver": "local" in daemon.json, or --log-driver local)
#   04-default-change.sh after    create logs-after, restart logs-before, and compare
source "$(dirname "$0")/lib.sh"

phase=${1:?usage: 04-default-change.sh before|after}
out="$RUN_DIR/04-default-change.txt"
case $phase in
  before)
    $DOCKER rm -f logs-before >/dev/null 2>&1 || true
    $DOCKER run -d --name logs-before --network none "$IMAGE" sh -c 'echo written before the change' >/dev/null
    $DOCKER wait logs-before >/dev/null
    { echo "== before: daemon default is $($DOCKER info --format '{{.LoggingDriver}}')"
      echo "logs-before: $(log_type logs-before)"; } | tee "$out"
    ;;
  after)
    $DOCKER rm -f logs-after >/dev/null 2>&1 || true
    $DOCKER run -d --name logs-after --network none "$IMAGE" sh -c 'echo written after the change' >/dev/null
    $DOCKER wait logs-after >/dev/null
    $DOCKER start logs-before >/dev/null && $DOCKER wait logs-before >/dev/null
    { echo "== after: daemon default is $($DOCKER info --format '{{.LoggingDriver}}')"
      echo "logs-before (created before, started again now): $(log_type logs-before)"
      echo "logs-after  (created after): $(log_type logs-after)"; } | tee -a "$out"
    ;;
  *) echo "usage: $0 before|after" >&2; exit 2 ;;
esac
