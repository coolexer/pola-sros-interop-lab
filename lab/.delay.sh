#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
for node in p1 p2 pe-a pe-b; do
  bash "$out/.cli.sh" "$node" < "$out/$node-delay.cli" > "$out/$node-delay.log" 2>&1 &
done
wait
grep -Ei 'MINOR|MAJOR' "$out/"*-delay.log || true
sleep 7
docker exec clab-pola-sr1-pola pola -p 50052 -j ted > "$out/ted-metrics.json"
