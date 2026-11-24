#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
pids=()
for n in pe-a pe-b p1 p2; do
    bash "$out/.cli.sh" "$n" < "$out/sr6-$n.cli" > "$out/sr6-$n.log" 2>&1 &
    pids+=("$!")
done
for pid in "${pids[@]}"; do wait "$pid"; done
for n in pe-a pe-b p1 p2; do
    printf '%s\n' "$n"
    grep -E 'No such|MINOR:|MAJOR:|PXC|SIDs :' "$out/sr6-$n.log" | tail -32 || true
done
docker exec clab-pola-sr1-pola pola -p 50052 --json ted > "$out/ted-sr6.json"
