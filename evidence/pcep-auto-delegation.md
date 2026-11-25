# Automatic delegation after PCEP synchronization

The Pola PR branch was built from upstream `develop` and tested with Nokia SR-SIM 26.10.R1 on the 7750 SR-1 FP4 Containerlab topology on 25 November 2026.

The PCC started with color 103 configured and the PCEP peer disabled. The test enabled the peer and let database synchronization complete. Nokia confirmed the path without a policy change after the session came up.

| Frame | Direction | Evidence |
| ---: | --- | --- |
| 12, 14 | Nokia ↔ Pola | Both OPEN messages carry SR Policy Association Type 6 and SRPOLICY-CAPABILITY TLV 71. |
| 19 | Nokia → Pola | PCRpt reports the delegated color 103 with `PLSP-ID=16`, `S=1`, `D=1`, state `Down`, and an empty ERO. The same message includes the end-of-sync marker. |
| 21 | Pola → Nokia | PCUpd carries `PLSP-ID=16`, `SRP-ID=1`, and labels `16002 → 16004`. |
| 23 | Nokia → Pola | PCRpt acknowledges `SRP-ID=1` and reports `PLSP-ID=16` as `Active`. |

[Packet capture](pcep-auto-delegation.pcap) · [Pola policy list](pola-auto-delegation.log) · [Lab test matrix](README.md)
