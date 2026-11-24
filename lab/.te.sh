#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
for node in p1 p2 pe-a pe-b; do
  bash "$out/.cli.sh" "$node" < "$out/$node-te.cli" > "$out/$node-te.log" 2>&1 &
done
wait
grep -Ei 'MINOR|MAJOR|Unknown' "$out/"*-te.log || true
