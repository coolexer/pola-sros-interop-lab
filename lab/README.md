# Run the lab

The original run used WSL with Docker and Containerlab. Use an x86-64 Linux shell with `containerlab`, `docker`, `sshpass`, `tcpdump`, `python3`, `curl`, and `iptables` for the optional probe. Run the commands with root permissions. Keep WSL running while you use the lab. Provide your own SR-SIM license and the admin password for your image.

## Deploy and test stock Pola

From the repository root, enter `lab/` and set the inputs for the topology.

```bash
cd lab
export SRSIM_LICENSE=/absolute/path/to/your/srsim-license
read -rsp 'SR-SIM admin password: ' SSHPASS
printf '\n'
export SSHPASS

bash deploy-and-configure.sh
bash test-dataplane.sh
bash test-topology.sh
```

The script stages the Containerlab topology under `/home/clab/pola-sr1-lab`. It verifies the GoBGP archive checksum and configures the four routers, Pola, GoBGP, and the hosts. The verification scripts write new captures and logs under `lab/`. The checked-in captures remain under [`evidence/`](../evidence/README.md).

Use these commands to inspect the live session and TED.

```bash
docker exec clab-pola-sr1-pola pola -p 50052 session
docker exec clab-pola-sr1-pola pola -p 50052 -j ted
```

## Build the probes

Use Go 1.27.2. The CSPF probe links against the upstream Pola library. The experimental daemon adds TLV 71 to the Pola OPEN.

```bash
lab_dir="$PWD"
pola_src=$(mktemp -d)
git clone --depth 1 --branch v1.4.0 https://github.com/nttcom/pola.git "$pola_src"
cp "$lab_dir/cspf-probe.go" "$pola_src/cspf-probe.go"
cd "$pola_src"
go build -o /home/clab/pola-sr1-lab/bin/sr1-lab-probe cspf-probe.go
git apply "$lab_dir/pola-tlv71-probe.patch"
go build -o /home/clab/pola-sr1-lab/bin/polad-sr1-capability-probe ./cmd/polad
cd "$lab_dir"
```

Run the probes against the deployed lab.

```bash
bash test-bgp-ls-capture.sh
bash verify-final.sh
bash test-topology.sh
bash test-pcep-capability.sh
```

The PCEP test redirects the lab PCC connection to the experimental daemon, captures the exchange, and restores the stock listener on exit. In the final PCRpt, check the active state and computed labels. For the IPv6 source-address probe, run `bash .ipv6.sh` as the final test, then restore the IPv4 peer.

```bash
sed '/^commit$/i /configure router "Base" pcep pcc peer 2001:db8:47:10::2 admin-state disable' pcep-ipv4.cli |
  bash .cli.sh pe-a
```

## Stop the lab

```bash
containerlab destroy -t /home/clab/pola-sr1-lab/pola-sr1.clab.yml
```
