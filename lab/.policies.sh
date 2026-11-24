#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
for node in p1 p2; do
    other=p1
    test "$node" = p1 && other=p2
    printf 'environment more false\nconfigure exclusive\n/configure router "Base" isis 0 interface "to-%s" level 2 metric 40\ncommit\nexit all\nlogout\n' "$other" | bash "$out/.cli.sh" "$node" > "$out/igp-$node.log" 2>&1
done
pola=$(docker inspect --format '{{.State.Pid}}' clab-pola-sr1-pola)
timeout -s INT 19 nsenter -t "$pola" -n tcpdump -U -ni eth1 -w "$out/pcep-stock-policies.pcap" tcp port 4189 2>/dev/null &
capture=$!
sleep 1
bash "$out/.cli.sh" pe-a < "$out/policies.cli" > "$out/policies-stock-sr1.log" 2>&1
wait "$capture" || true
docker exec clab-pola-sr1-pola pola -p 50052 sr-policy list | tee "$out/pola-stock-policies.log"
docker exec clab-pola-sr1-pola pola -p 50052 -j ted > "$out/ted-sr6.json"
grep -Ei 'MINOR|MAJOR|Color|Active|resolved|pending' "$out/policies-stock-sr1.log" | tail -35
