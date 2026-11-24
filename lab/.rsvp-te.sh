#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
for node in p1 p2 pe-a pe-b; do
  bash "$out/.cli.sh" "$node" < "$out/$node-rsvp-te.cli" > "$out/$node-rsvp-te.log" 2>&1 &
done
wait
grep -Ei 'MINOR|MAJOR' "$out/"*-rsvp-te.log || true
sleep 9
docker exec clab-pola-sr1-pola pola -p 50052 -j ted > "$out/ted-metrics.json"
