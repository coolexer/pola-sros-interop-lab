#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
for node in pe-a pe-b p1 p2; do
  printf 'environment more false\nconfigure exclusive\n/configure router "Base" rsvp interface "system" admin-state enable\n/configure router "Base" isis 0 traffic-engineering-options application-link-attributes legacy true\ncommit\nexit all\nshow router rsvp interface\nlogout\n' |
    bash "$out/.cli.sh" "$node" > "$out/$node-te-legacy.log" 2>&1 &
done
wait
grep -Ei 'MINOR|MAJOR' "$out/"*-te-legacy.log || true
sleep 7
pola=$(docker inspect --format '{{.State.Pid}}' clab-pola-sr1-pola)
docker exec clab-pola-sr1-pola pola -p 50052 -j ted > "$out/ted-te-legacy.json"
if [[ -x /home/clab/pola-sr1-lab/bin/sr1-lab-probe ]]; then
  nsenter -t "$pola" -n /home/clab/pola-sr1-lab/bin/sr1-lab-probe | tee "$out/cspf-te-legacy.log"
fi
