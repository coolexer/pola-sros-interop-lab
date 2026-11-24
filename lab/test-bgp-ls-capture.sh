#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
go=$(docker inspect --format '{{.State.Pid}}' clab-pola-sr1-gobgp)
nsenter -t "$go" -n tcpdump -U -ni eth1 -w "$out/bgp-ls-reconnect.pcap" 'tcp port 179' 2>"$out/bgp-ls-reconnect.capture.log" &
capture=$!
trap 'kill -INT "$capture" 2>/dev/null || true; wait "$capture" || true' EXIT
sleep 1
printf 'environment more false\nconfigure exclusive\n/configure router "Base" bgp neighbor 198.18.2.2 admin-state disable\ncommit\n/configure router "Base" bgp neighbor 198.18.2.2 admin-state enable\ncommit\nexit all\nshow router bgp summary\nlogout\n' |
  bash "$out/.cli.sh" pe-b > "$out/pe-b-bgp-ls-reconnect.log" 2>&1
for n in $(seq 1 45); do
  docker exec clab-pola-sr1-pola pola -p 50052 -j ted > "$out/ted-after-bgp-reconnect.json"
  if python3 -c 'import json,sys; links=[l for n in json.load(sys.stdin) for l in n["links"]]; sys.exit(not (len(links) == 10 and all(any(m["type"] == "te" for m in l["metrics"]) for l in links)))' < "$out/ted-after-bgp-reconnect.json"; then
    printf 'Pola has ten directed links with TE metrics.\n'
    exit 0
  fi
  sleep 2
done
printf 'Pola TED did not converge before the timeout.\n' >&2
exit 1
