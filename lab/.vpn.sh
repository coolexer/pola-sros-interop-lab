#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
for node in pe-a pe-b; do
  bash "$out/.cli.sh" "$node" < "$out/$node-vpn.cli" > "$out/$node-vpn.log" 2>&1 &
done
wait
grep -Ei 'MINOR|MAJOR|router policy already|Established' "$out/"pe-?-vpn.log || true
for side in a b; do
  if [[ $side == a ]]; then id=1; far=4; local4=2; gw4=1; remote=64; else id=4; far=1; local4=66; gw4=65; remote=0; fi
  host=clab-pola-sr1-host-$side
  docker exec "$host" ip link set eth1 up
  for vlan in 300 400 500; do
    docker exec "$host" ip link add link eth1 name "eth1.$vlan" type vlan id "$vlan" 2>/dev/null || docker exec "$host" ip link show "eth1.$vlan"
    docker exec "$host" ip link set "eth1.$vlan" up
  done
  docker exec "$host" ip addr replace "203.0.113.$local4/26" dev eth1.300
  docker exec "$host" ip route replace "203.0.113.$remote/26" via "203.0.113.$gw4"
  for vlan in 400 500; do
    docker exec "$host" ip -6 addr replace "2001:db8:$vlan:$id::2/64" dev "eth1.$vlan"
    docker exec "$host" ip -6 route replace "2001:db8:$vlan:$far::/64" via "2001:db8:$vlan:$id::1" dev "eth1.$vlan"
  done
done
