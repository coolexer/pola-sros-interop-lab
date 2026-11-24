#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
probe=/home/clab/pola-sr1-lab/bin/sr1-lab-probe
pola=$(docker inspect --format '{{.State.Pid}}' clab-pola-sr1-pola)
set_port() {
  printf 'environment more false\nconfigure exclusive\n/configure port 1/1/c2/1 admin-state %s\ncommit\nexit all\nshow router isis adjacency\nlogout\n' "$1" |
    bash "$out/.cli.sh" p1 > "$out/topology-port-$1.log" 2>&1
  if grep -Eq 'MINOR|MAJOR' "$out/topology-port-$1.log"; then
    grep -E 'MINOR|MAJOR' "$out/topology-port-$1.log"
    return 1
  fi
}
snapshot() {
  local phase=$1 expected=$2 file="$out/ted-$1.json" actual=0
  for _ in $(seq 1 20); do
    docker exec clab-pola-sr1-pola pola -p 50052 -j ted > "$file"
    actual=$(python3 -c 'import json,sys; print(sum(len(x["links"]) for x in json.load(open(sys.argv[1]))))' "$file")
    [[ $actual == "$expected" ]] && break
    sleep 2
  done
  printf '%s expected=%s observed=%s\n' "$phase" "$expected" "$actual" | tee -a "$out/topology-events.log"
  if [[ -x $probe ]]; then
    nsenter -t "$pola" -n "$probe" | tee "$out/cspf-$phase.log"
  fi
  [[ $actual == "$expected" ]]
}
: > "$out/topology-events.log"
snapshot up 10
trap 'set_port enable' EXIT
set_port disable
snapshot down 8
set_port enable
trap - EXIT
snapshot restored 10
