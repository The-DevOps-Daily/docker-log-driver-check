#!/usr/bin/env bash
# The Engine version and its default log driver, on a daemon with no logging settings.
source "$(dirname "$0")/lib.sh"
{
  echo "\$ docker version --format 'docker client {{.Client.Version}}, engine {{.Server.Version}}'"
  $DOCKER version --format 'docker client {{.Client.Version}}, engine {{.Server.Version}}'
  echo "\$ docker info --format '{{.LoggingDriver}}'"
  $DOCKER info --format '{{.LoggingDriver}}'
} | tee "$RUN_DIR/00-default.txt"
