#!/usr/bin/env bash
set -euo pipefail
: "${SSHPASS:?Set SSHPASS to the SR-SIM admin password}"
export SSHPASS
case "$1" in
    pe-a) node=11 ;;
    pe-b) node=12 ;;
    p1) node=13 ;;
    p2) node=14 ;;
    *) printf 'Unknown lab node: %s\n' "$1" >&2; exit 2 ;;
esac
sshpass -e ssh -tt -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@172.30.47.$node"
