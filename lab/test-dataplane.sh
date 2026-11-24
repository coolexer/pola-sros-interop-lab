#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
set_policies() {
  {
    printf 'environment more false\nconfigure exclusive\n'
    for name in MPLS101 FULL201 USID301; do
      printf '/configure router "Base" segment-routing sr-policies static-policy "%s" admin-state %s\n' "$name" "$1"
    done
    printf 'commit\nexit all\nshow router segment-routing sr-policies all\nlogout\n'
  } | bash "$out/.cli.sh" pe-a > "$out/dataplane-policy-$1.log" 2>&1
  if grep -Eq 'MINOR|MAJOR' "$out/dataplane-policy-$1.log"; then
    grep -E 'MINOR|MAJOR' "$out/dataplane-policy-$1.log"
    return 1
  fi
}
probe() {
  local label=$1 node pid capture=()
  for node in p1 p2; do
    pid=$(docker inspect --format '{{.State.Pid}}' "clab-pola-sr1-$node")
    nsenter -t "$pid" -n tcpdump -U -ni e1-1-c1-1 -w "$out/dataplane-$label-$node.pcap" 'ip6 or mpls' 2>"$out/dataplane-$label-$node.capture.log" &
    capture+=("$!")
  done
  sleep 1
  {
    docker exec clab-pola-sr1-host-a ping -i 0.3 -c 3 -W 1 203.0.113.66 || true
    docker exec clab-pola-sr1-host-a ping -6 -i 0.3 -c 3 -W 1 2001:db8:400:4::2 || true
    docker exec clab-pola-sr1-host-a ping -6 -i 0.3 -c 3 -W 1 2001:db8:500:4::2 || true
  } | tee "$out/dataplane-$label-pings.log"
  for pid in "${capture[@]}"; do
    kill -INT "$pid" 2>/dev/null || true
    wait "$pid" || true
  done
  [[ $(grep -c '3 packets transmitted, 3 packets received' "$out/dataplane-$label-pings.log") == 3 ]]
}
for attempt in $(seq 1 45); do
  if docker exec clab-pola-sr1-host-a ping -c 1 -W 1 203.0.113.66 >/dev/null 2>&1 &&
     docker exec clab-pola-sr1-host-a ping -6 -c 1 -W 1 2001:db8:400:4::2 >/dev/null 2>&1 &&
     docker exec clab-pola-sr1-host-a ping -6 -c 1 -W 1 2001:db8:500:4::2 >/dev/null 2>&1; then
    break
  fi
  if (( attempt == 45 )); then
    printf 'The three VPN paths did not converge before the timeout.\n' >&2
    exit 1
  fi
  sleep 2
done
set_policies disable
trap 'set_policies enable' EXIT
sleep 3
probe baseline
set_policies enable
trap - EXIT
sleep 3
probe steering
