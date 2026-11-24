# Test results and evidence

Captured on 24 November 2026 with Nokia SR-SIM 26.10.R1, Pola v1.4.0, and GoBGP v4.0.0.

| Case | Result | Evidence |
|---|---|---|
| TC01 PCEP and resync | **Pass on IPv4.** TCP/4189, OPEN, KEEPALIVE, and LSP database sync completed with stock Pola. The session recovered after a PCC restart. SR OS CLI rejected the IPv6 PCC local address on this release. | [Initial pcap](pcep-ipv4-open.pcap), [restored session](pola-stock-restored.log), [IPv6 CLI](pe-a-pcep-ipv6.log) |
| TC02 BGP-LS and topology changes | **Pass for topology and advertised SIDs.** Four nodes, ten directed links, IPv4 and IPv6 MPLS prefix SIDs, and SRv6 End.X/uA arrived in Pola. The directed link count went 10 → 8 → 10 when P1–PE-B was disabled and restored. | [TED](ted-final.json), [events](topology-events.log), [Nokia BGP export](pe-b-te-diagnostics.log) |
| TC03 SR-MPLS reporting | **Pass with the TLV 71 probe.** Pola showed colors 101 and 102, for IPv4 and IPv6 endpoints, with labels 16003 and 16004. Stock Pola showed zero policies. | [Stock CLI](pola-stock-policies.log), [probe CLI](pola-experiment-policies.log), [pcap](pcep-capability-probe.pcap) |
| TC04 SRv6 full-SID reporting | **Pass with the TLV 71 probe.** Color 201 reported SID `2001:db8:471:3:1::`. | [Probe CLI](pola-experiment-policies.log), [pcap](pcep-capability-probe.pcap) |
| TC05 SRv6 uSID reporting | **Pass with the TLV 71 probe.** Color 301 reported `fd47:4700:3::` with behavior uN. | [Probe CLI](pola-experiment-policies.log), [pcap](pcep-capability-probe.pcap) |
| TC06 CSPF metrics | **Pass for SR-MPLS IGP, TE, and hop count on IPv4 and IPv6.** The TE minimum uses PE-A → P2 → P1 → PE-B. The IGP minimum uses PE-A → P1 → PE-B. Pola had no delay metric in its TED. Nokia sent Min/Max Unidirectional Link Delay (TLV 1115) on the wire. SRv6 CSPF stopped at a missing node SID in the TED. The captured BGP-LS update set carried node, link, and prefix NLRIs. | [CSPF output](cspf-final.log), [TED](ted-final.json), [BGP-LS wire capture](bgp-ls-reconnect.pcap) |
| TC07 Waypoint and recalculation | **Pass for both SR-MPLS families.** An IGP waypoint forced P2. Without the waypoint, loss of P1–PE-B moved the result from P1 to P2. Restoring the link returned it to P1. SRv6 had the same node SID dependency as TC06. | [Up](cspf-up.log), [down](cspf-down.log), [restored](cspf-restored.log) |
| TC08 Delegated dynamic SR-MPLS policy | **Pass with the TLV 71 probe after sync.** Initial sync logs show that Pola rejected the delegated report with an empty segment list. Re-enabling color 103 after sync generated a delegated PCRpt, Pola PCUpd, and an active PCRpt with labels 16002 and 16004. | [PCEP pcap](pcep-capability-probe.pcap), [initial sync error](pola-experiment-protocol.log), [PCC state](pe-a-dynamic-post-sync.log) |
| TC09 Traffic steering | **Pass** for all three VLANs. Every run returned 3/3 echoes per service. The requests used P1 with the policies disabled and P2 with them enabled. The steering capture shows MPLS labels 16003 and 16004 plus the VPN label, SRv6 full SID `2001:db8:471:3:1::`, and uSID `fd47:4700:3::`. | [Baseline pings](dataplane-baseline-pings.log), [steering pings](dataplane-steering-pings.log), [P1 baseline pcap](dataplane-baseline-p1.pcap), [P2 steering pcap](dataplane-steering-p2.pcap) |

The CSPF probe uses the upstream Pola v1.4.0 library and obtains the TED through the active Pola gRPC API. The GoBGP v4.0.0 diagnostic CLI raised a nil pointer panic while printing the final BGP-LS RIB. The daemon stayed established and Pola returned the TED over gRPC. [GoBGP CLI log](gobgp-cli-final.log) The advertised delay values were static inputs. The ping RTT measures the lab hosts.

## Inspect the captures

| File | Wireshark display filter | What to look for |
| --- | --- | --- |
| [Stock PCEP](pcep-ipv4-open.pcap) | `pcep` | Frames 4 and 5 contain the OPEN from stock Pola and Nokia respectively. Check the raw payload for `00 47 00 04 00 00 00 00`. |
| [Experimental PCEP](pcep-capability-probe.pcap) | `pcep` | Frame 24 is the PCUpd for color 103. Frame 26 shows Nokia confirming the new label stack. |
| [BGP-LS](bgp-ls-reconnect.pcap) | `bgp.type == 2` | The updates carry TE Default Metric, Min/Max Unidirectional Link Delay, and SRv6 End.X. |
| [P1 baseline](dataplane-baseline-p1.pcap) / [P2 steering](dataplane-steering-p2.pcap) | `icmp.type == 8 || icmpv6.type == 128` | Inspect the label stack or outer IPv6 destination before and after enabling the policies. |

Some Wireshark builds flag the Nokia OPEN as malformed. The TLV comparison uses the raw TCP payload. The lab patch advertises TLV 71 with flags zero, without advertising stateless operation or the optional P, E, and I flags. At initial synchronization, the experimental Pola daemon logs an empty segment-list error for the delegated policy. The follow-up test re-enables the policy after synchronization.

## References

- Nokia supports local policy reporting and documents the SR-MPLS and SRv6 behavior. [PCEP policy initiation](https://documentation.nokia.com/sr/26-10/7x50-shared/segment-routing-pce-user/pcep.html#sr_policy_initiation), [SRv6 reporting](https://documentation.nokia.com/sr/26-10/7x50-shared/segment-routing-pce-user/segment-rout-with-ipv6-data-plane-srv6.html#concept_fjb_vz4_pjc), [BGP-LS attributes](https://documentation.nokia.com/sr/26-10/7x50-shared/unicast-routing-protocols/bgp.html)
- RFC 9862 defines the SR Policy capability and association exchange. [RFC 9862 §5.1](https://www.rfc-editor.org/rfc/rfc9862.html#section-5.1)
- The Pola version used in the tests. [Pola v1.4.0](https://github.com/nttcom/pola/tree/v1.4.0)
