# docker-log-driver-check

```bash
LINES=500000 ./scripts/01-write-logs.sh
./scripts/02-measure.sh
./scripts/03-collector.sh
./scripts/cleanup.sh
```

Docker Desktop 4.94 made `local` the default log driver for new Linux containers. Docker Engine on a server still defaults to `json-file`, with no rotation. These scripts write the same log lines through three setups and record what each one costs on disk, what `docker logs` can still return, and what a collector that tails the log files reads.

Companion repo for the DevOps Daily post on the change.

## What each script does

| Script | What it records |
| --- | --- |
| `00-default.sh` | The Engine version and its default log driver. |
| `01-write-logs.sh` | Starts `logs-json-default` (json-file, no options), `logs-json-capped` (json-file, `max-size=10m`, `max-file=3`) and `logs-local` (local, its defaults). Each writes `$LINES` lines of about 96 bytes. |
| `02-measure.sh` | Bytes on disk, the files each driver wrote, the first bytes of each file, and how many lines and bytes `docker logs` gives back. |
| `03-collector.sh` | Runs Fluent Bit's `tail` input with the docker parser on each container's `*.log` files, the usual Docker host setup, and counts the records. Then points it at the `local` driver's own file. |
| `04-default-change.sh` | `before`, then restart the daemon with `"log-driver": "local"`, then `after`. Shows that only containers created after the change get the new driver. |
| `cleanup.sh` | Removes the `logs-*` containers. |

The scripts read log files from the daemon's data root, so they call `sudo`. Set `DOCKER_HOST` to test another daemon, and `RUN_DIR` to keep a run. With the default 500,000 lines they write about 130 MB of logs; `cleanup.sh` removes them.

## Results

`runs/2026-10-09-engine-29.9.0/` is the recorded run: Docker Engine 29.9.0 on a Raspberry Pi 4 (arm64), Fluent Bit 5.1.3. `00-default.txt` comes from a second Engine 29.9.0 daemon with no logging settings, because the test daemon was restarted with `local` as its default for `04-default-change.sh`. These lines repeat a lot, so they compress well; how well your logs compress depends on their content.

| Setup | Size of the log files (bytes) | Lines `docker logs` still returns | Lines the `*.log` tail read |
| --- | ---: | ---: | ---: |
| json-file, no options | 83,833,258 | 500,000 | 500,000 |
| json-file, 10m x 3 | 23,833,155 | 142,146 | 22,860 |
| local, defaults | 24,134,700 | 500,000 | 0 |

The plain text of the 500,000 lines is 47,888,900 bytes.

Fluent Bit started after the containers had finished, so it read only the current `-json.log` file of the capped container. A collector that runs all the time reads lines before they rotate. The `local` driver's files are in `local-logs/`, which the usual glob does not match. Pointed at that file directly, Fluent Bit read 158,382 records and the docker parser could parse none of them (`03-local-raw-head.txt`).

## License

MIT
