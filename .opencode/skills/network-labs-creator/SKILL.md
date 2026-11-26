---
name: network-labs-creator
description: Create and maintain reproducible Docker Compose networking topologies, FRRouting/iproute2/bridge labs, and interactive POSIX break-and-fix troubleshooting drills under labs/ in learning-network-guides.
---

# Network Labs Creator

Author reproducible multi-container networking topologies (`labs/docker-compose.*.yml`), POSIX training scripts (`labs/*.sh`), and guided lab exercises (`labs/README.md`) for `learning-network-guides`.

## When to use

- Creating a new Docker Compose networking lab under `labs/`.
- Building or extending interactive troubleshooting trainers (`labs/break-and-fix.sh`).
- Updating `labs/README.md` with step-by-step verification and fault-injection drills.

## Hard rules for the author model

1. **Lightweight, fast-booting containers:** Use `alpine:3.20` (with `iproute2`, `bridge-utils`, `iptables`, `tcpdump`, `curl`, `conntrack-tools`) for hosts/switches/firewalls and `quay.io/frrouting/frr:10.1.0` for dynamic routing (`vtysh` Cisco-like CLI for OSPF/BGP/VRRP). Never require heavy VM images or proprietary licenses to run a baseline lab.
2. **Explicit kernel capabilities:** Every container that manipulates interfaces, VLAN bridges, routing tables, or firewall rules must declare `cap_add: [NET_ADMIN, NET_RAW]` and appropriate `sysctls` (`net.ipv4.ip_forward=1`).
3. **Self-contained startup:** Containers must come up pre-configured and functional via deterministic startup commands, keeping the container alive with `tail -f /dev/null`.
4. **POSIX shell portability:** Any helper or fault-injection script under `labs/*.sh` must use `#!/bin/sh` with `set -eu`, zero bashisms (`[[ ]]`, arrays, `<()`), and pass `shellcheck`.
5. **Mandatory template & catalog:** Follow [`assets/lab-template.md`](assets/lab-template.md) for documentation in `labs/README.md` and check [`references/catalog-and-standards.md`](references/catalog-and-standards.md) for topology standards and addressing.
6. **Markdownlint compliance:** Always specify a language on fenced code blocks (`yaml`, `bash`, `text`), surround headings and lists with blank lines, and run `pnpm validate` before finishing.

## Decision table

| Situation | Required action |
|---|---|
| Lab teaches Layer 2 VLANs, 802.1Q Trunks, PVID, or STP | Use `alpine:3.20` with `ip link add br0 type bridge vlan_filtering 1` and `bridge vlan add` commands. |
| Lab teaches OSPF, BGP, or Cisco-style routing CLI | Use `quay.io/frrouting/frr:10.1.0` with `vtysh -c "configure terminal" ...` so the student practices standard Cisco IOS / FRR syntax. |
| Lab teaches Stateful Firewall, DNAT, Hairpin NAT, or MTU/MSS | Use `alpine:3.20` with `iptables`, `conntrack-tools`, and `tcpdump` across separated LAN/WAN bridges. |
| Creating a Break & Fix mission | Implement `list`, `break <N>`, `hint <N>`, and `verify <N>` subcommands in POSIX `sh` without revealing the root cause during `break`. |

## Execution workflow

1. Read [`assets/lab-template.md`](assets/lab-template.md) and [`references/catalog-and-standards.md`](references/catalog-and-standards.md).
2. Create or update the `labs/docker-compose.<name>.yml` or `labs/<script>.sh` file.
3. Document the topology diagram, startup command, verification steps, and failure drill in `labs/README.md`.
4. Run `pnpm lint:md:fix && pnpm validate` and fix any errors before reporting completion.
