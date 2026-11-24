#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
lab=/home/clab/pola-sr1-lab
pid=$(docker inspect --format '{{.State.Pid}}' clab-pola-sr1-pola)
patch_config="$lab/polad-capability-probe.yaml"
rule=(-i eth1 -d 198.18.1.2/32 -p tcp --dport 4189 -j REDIRECT --to-ports 14189)
sed -e 's/port: 4189/port: 14189/' -e 's/port: 50052/port: 50053/' -e 's#"/var/log/pola/"#"/home/clab/pola-sr1-lab/"#' -e 's/polad.log/polad-capability-probe.log/' "$out/polad.yaml" > "$patch_config"
bounce() {
  printf 'environment more false\nconfigure exclusive\n/configure router "Base" pcep pcc peer 198.18.1.2 admin-state disable\ncommit\n/configure router "Base" pcep pcc peer 198.18.1.2 admin-state enable\ncommit\nexit all\nshow router pcep pcc peer\nshow router segment-routing sr-policies all\nlogout\n' |
    bash "$out/.cli.sh" pe-a
}
truncate -s 0 "$lab/polad-capability-probe.log"
nsenter -t "$pid" -n "$lab/bin/polad-sr1-capability-probe" -f "$patch_config" >"$out/pola-experiment-daemon.log" 2>&1 &
daemon=$!
capture= redirect=0
cleanup() {
  if [[ -n $capture ]]; then kill -INT "$capture" 2>/dev/null || true; wait "$capture" || true; fi
  if [[ $redirect == 1 ]]; then
    nsenter -t "$pid" -n iptables -t nat -D PREROUTING "${rule[@]}"
    kill -TERM "$daemon" 2>/dev/null || true
    bounce > "$out/pe-a-pcep-stock-restored.log" 2>&1 || true
    docker exec clab-pola-sr1-pola pola -p 50052 session > "$out/pola-stock-restored.log" || true
  else
    kill -TERM "$daemon" 2>/dev/null || true
  fi
}
trap cleanup EXIT
for _ in $(seq 1 15); do
  if nsenter -t "$pid" -n ss -ltn | grep -q ':14189 '; then break; fi
  kill -0 "$daemon"
  sleep 1
done
nsenter -t "$pid" -n ss -ltn | grep -q ':14189 '
nsenter -t "$pid" -n iptables -t nat -A PREROUTING "${rule[@]}"
redirect=1
nsenter -t "$pid" -n tcpdump -U -ni eth1 -w "$out/pcep-capability-probe.pcap" tcp port 4189 2>"$out/pcep-capability-probe.capture.log" &
capture=$!
sleep 1
bounce > "$out/pe-a-pcep-experiment.log" 2>&1
for _ in $(seq 1 12); do
  docker exec clab-pola-sr1-pola pola -p 50053 sr-policy list > "$out/pola-experiment-policies.log" || true
  if grep -Eqi 'MPLS101|FULL201|USID301|PLSP ID' "$out/pola-experiment-policies.log"; then break; fi
  sleep 2
done
{
  printf 'environment more false\nconfigure exclusive\n'
  for state in disable enable; do
    printf '/configure router "Base" segment-routing sr-policies static-policy "DYNAMIC103" admin-state %s\ncommit\n' "$state"
  done
  printf 'exit all\nshow router segment-routing sr-policies all\nlogout\n'
} | bash "$out/.cli.sh" pe-a > "$out/pe-a-dynamic-post-sync.log" 2>&1
sleep 4
docker exec clab-pola-sr1-pola pola -p 50053 sr-policy list > "$out/pola-experiment-policies.log"
docker exec clab-pola-sr1-pola pola -p 50053 session 198.18.1.1 detail > "$out/pola-experiment-session.log" || true
cp "$lab/polad-capability-probe.log" "$out/pola-experiment-protocol.log" || true
cat "$out/pola-experiment-policies.log"
