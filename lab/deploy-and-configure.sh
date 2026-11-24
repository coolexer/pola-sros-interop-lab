#!/usr/bin/env bash
set -euo pipefail
: "${SRSIM_LICENSE:?Set SRSIM_LICENSE to the absolute path of your SR-SIM license}"
: "${SSHPASS:?Set SSHPASS to the admin password of your SR-SIM lab}"
out=$(cd "$(dirname "$0")" && pwd)
lab=/home/clab/pola-sr1-lab
archive="$lab/bin/gobgp-v4.0.0.tar.gz"
test -r "$SRSIM_LICENSE"
mkdir -p "$lab/bin"
cp "$out"/*.yaml "$out"/*.yml "$out"/*.partial.txt "$lab/"
if [[ ! -f $archive ]]; then
  curl --fail --location --output "$archive" https://github.com/osrg/gobgp/releases/download/v4.0.0/gobgp_4.0.0_linux_amd64.tar.gz
fi
containerlab deploy -t "$lab/pola-sr1.clab.yml"
for node in pe-a pe-b p1 p2; do
  for attempt in $(seq 1 45); do
    if printf 'logout\n' | bash "$out/.cli.sh" "$node" >/dev/null 2>&1; then break; fi
    if (( attempt == 45 )); then
      printf 'SR-SIM CLI did not become ready on %s\n' "$node" >&2
      exit 1
    fi
    sleep 2
  done
done
bash "$out/.initial.sh"
bash "$out/.srv6.sh"
bash "$out/.te.sh"
bash "$out/.rsvp-te.sh"
bash "$out/.te-legacy.sh"
bash "$out/.delay.sh"
bash "$out/.policies.sh"
bash "$out/.vpn.sh"
printf 'Lab %s is ready for test-dataplane.sh and test-topology.sh.\n' 'pola-sr1'
