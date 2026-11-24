#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
pid=$(docker inspect --format '{{.State.Pid}}' clab-pola-sr1-pola)
docker exec clab-pola-sr1-gobgp gobgp -j neighbor 198.18.2.1 -a ls adj-in > "$out/gobgp-final.json" 2>"$out/gobgp-cli-final.log" || true
docker exec clab-pola-sr1-pola pola -p 50052 -j ted > "$out/ted-final.json"
docker exec clab-pola-sr1-pola pola -p 50052 sr-policy list > "$out/pola-stock-final-policies.log"
nsenter -t "$pid" -n /home/clab/pola-sr1-lab/bin/sr1-lab-probe | tee "$out/cspf-final.log"
