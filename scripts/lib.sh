#!/usr/bin/env bash
# Shared settings. Point DOCKER_HOST at the daemon you want to test; the scripts
# read log files from that daemon's data root, which needs sudo.
set -euo pipefail

DOCKER=${DOCKER:-docker}
LINES=${LINES:-500000}
RUN_DIR=${RUN_DIR:-runs/latest}
IMAGE=${IMAGE:-alpine:3.22}
mkdir -p "$RUN_DIR"

root_dir() { $DOCKER info --format '{{.DockerRootDir}}'; }
container_dir() { echo "$(root_dir)/containers/$($DOCKER inspect --format '{{.Id}}' "$1")"; }
log_type() { $DOCKER inspect --format '{{.HostConfig.LogConfig.Type}}' "$1"; }
log_opts() { $DOCKER inspect --format '{{json .HostConfig.LogConfig.Config}}' "$1"; }
