---
name: network-guides-creator
description: >-
  Create and maintain multi-vendor network configuration, verification, and
  maintenance guides under guides/ in learning-network-guides, covering
  Cisco IOS, MikroTik RouterOS v7, Aruba/Ubiquiti/TP-Link managed switches,
  and Linux iproute2/bridge/FRRouting.
---

# Network Guides Creator

Author practical, multi-vendor networking configuration and operations guides in `guides/<domain>/<kebab-name>.md` for `learning-network-guides`.

## When to use

- Creating a new configuration or operational guide under `guides/`.
- Expanding, auditing, or refactoring an existing guide in `guides/`.
- Updating `guides/README.md` after adding a guide.

## Hard rules for the author model

1. **Standard first, multi-vendor implementation second:** Every guide starts by explaining what the protocol/feature does and its topology diagram, then shows the exact implementation in **Cisco IOS**, **MikroTik RouterOS (v7+)**, **Generic Managed Switch (Aruba / Ubiquiti / TP-Link Omada)**, and **Linux (`iproute2` / `bridge` / `FRRouting`)**.
2. **Mandatory template:** Follow [`assets/guide-template.md`](assets/guide-template.md) section by section. Never omit a required section.
3. **Catalog compliance:** Check [`references/catalog-and-standards.md`](references/catalog-and-standards.md) for the target domain folder, filename, and required subtopics.
4. **RouterOS v7+ modern syntax only:** For MikroTik, always use modern **Bridge VLAN Filtering** (`/interface bridge vlan` and `/interface bridge port` with `pvid` and `frame-types`) and RouterOS v7 syntax. Never teach deprecated pre-6.41 switch-chip/master-port hacks as primary practice.
5. **Every output interpreted:** Whenever you show a verification command (`show interfaces trunk`, `/interface bridge vlan print`, `show ip ospf neighbor`), include a realistic sample output block (`text`) and a table explaining what each column/flag means (`D`, `R`, `S`, `H`, `Full/DR`, `err-disabled`).
6. **Anti-lockout & rollback first:** Every configuration guide must include the pre-change safety step (`Safe Mode` / `Ctrl+X` in MikroTik, `reload in 10` or `archive` in Cisco) and how to persist or revert changes.
7. **File naming & language:** Filename in English ASCII `kebab-case.md` inside its domain subfolder. Content in clear, technical Spanish.
8. **Markdownlint compliance:** Always specify a language on fenced code blocks (`text`, `bash`, `cisco`), surround headings and lists with blank lines, and run `pnpm lint:md` before finishing.

## Decision table

| Situation | Required action |
|---|---|
| Guide covers a cross-vendor protocol (VLANs, RSTP, LACP, OSPF, NAT, WireGuard) | Place in the matching domain folder (`01-fundamentals` to `05-wireless-poe` or `08-operations`) and include all 4 vendor implementation blocks. |
| Guide covers a vendor-exclusive feature (MikroTik Mangle/PCC/Netwatch or Cisco ROMMON/IOS upgrade) | Place in `06-mikrotik/` or `07-cisco/`, focus on that vendor's depth, and note the conceptual equivalent in other ecosystems. |
| Verification command has cryptic flags (`H`, `D`, `X`, `I` in MikroTik or `P`, `I`, `w` in Cisco) | Add an explicit flag-decoding table in `## 🔑 Salida clave e interpretación`. |

## Execution workflow

1. Read [`assets/guide-template.md`](assets/guide-template.md) and [`references/catalog-and-standards.md`](references/catalog-and-standards.md).
2. Create `guides/<domain>/<kebab-name>.md` with a realistic lab topology (IPs, VLAN IDs, and interface names consistent across all vendor blocks).
3. Update `guides/README.md` turning the plain backtick entry into an active link.
4. Run `pnpm lint:md` and fix any errors before reporting completion.
