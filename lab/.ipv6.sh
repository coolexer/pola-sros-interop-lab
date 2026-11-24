#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
pola=$(docker inspect --format '{{.State.Pid}}' clab-pola-sr1-pola)
timeout -s INT 38 nsenter -t "$pola" -n tcpdump -U -ni eth1 -w "$out/pcep-ipv6-open.pcap" 'ip6 and tcp port 4189' 2>/dev/null &
capture=$!
sleep 1
bash "$out/.cli.sh" pe-a < "$out/pcep-ipv6.cli" > "$out/pe-a-pcep-ipv6.log" 2>&1
for n in $(seq 1 10); do
  docker exec clab-pola-sr1-pola pola -p 50052 session > "$out/pola-session-ipv6.log"
  grep -q '2001:db8:47:10::1' "$out/pola-session-ipv6.log" && break
  sleep 2
done
wait "$capture" || true
cat "$out/pola-session-ipv6.log"
grep -Ei 'MINOR|MAJOR|Sync State|Session State' "$out/pe-a-pcep-ipv6.log" || true
