#!/usr/bin/env bash
# Remove every container these scripts created. Images stay.
source "$(dirname "$0")/lib.sh"
$DOCKER ps -aq --filter name='^logs-' | xargs -r $DOCKER rm -f >/dev/null
echo "removed the logs-* containers"
