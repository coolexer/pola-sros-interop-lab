#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
bin=/home/clab/pola-sr1-lab/bin
printf '%s  %s\n' '07967e479b0c05c0702c70504b864adaa72e051847645044eb85969eda22090b' "$bin/gobgp-v4.0.0.tar.gz" | sha256sum -c
tar -xzf "$bin/gobgp-v4.0.0.tar.gz" -C "$bin" gobgp gobgpd
docker cp "$bin/gobgp" clab-pola-sr1-gobgp:/usr/local/bin/gobgp
docker cp "$bin/gobgpd" clab-pola-sr1-gobgp:/usr/local/bin/gobgpd
pola=$(docker inspect --format '{{.State.Pid}}' clab-pola-sr1-pola)
gobgp=$(docker inspect --format '{{.State.Pid}}' clab-pola-sr1-gobgp)
nsenter -t "$pola" -n ip addr replace 198.18.1.2/30 dev eth1
nsenter -t "$pola" -n ip -6 addr replace 2001:db8:47:10::2/64 dev eth1
nsenter -t "$gobgp" -n ip addr replace 198.18.2.2/30 dev eth1
docker exec -d clab-pola-sr1-gobgp gobgpd -f /lab/gobgpd.yaml --api-hosts 0.0.0.0:50051
timeout -s INT 14 nsenter -t "$pola" -n tcpdump -U -ni eth1 -w "$out/pcep-ipv4-open.pcap" tcp port 4189 2>/dev/null &
capture=$!
bash "$out/.cli.sh" pe-a < "$out/pcep-ipv4.cli" > "$out/pe-a-pcep-ipv4.log" 2>&1 &
pcc=$!
bash "$out/.cli.sh" pe-b < "$out/bgp-ls.cli" > "$out/pe-b-bgp-ls.log" 2>&1 &
bgpls=$!
wait "$pcc"
wait "$bgpls"
wait "$capture" || true
docker exec clab-pola-sr1-pola pola -p 50052 session | tee "$out/pola-session-ipv4.log"
docker exec clab-pola-sr1-gobgp gobgp neighbor | tee "$out/gobgp-neighbor.log"
docker exec clab-pola-sr1-pola pola -p 50052 --json ted > "$out/ted-before-srv6.json"
