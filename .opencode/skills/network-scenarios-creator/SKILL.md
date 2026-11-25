---
name: network-scenarios-creator
description: >-
  Create and maintain real-world networking incident runbooks and maintenance
  scenarios under scenarios/ in learning-network-guides, with layer-by-layer
  diagnosis, multi-vendor triage commands (Cisco, MikroTik, Aruba/Ubiquiti,
  Linux), safe mitigation, and rollback steps.
---

# Network Scenarios Creator

Author practical incident-response and maintenance runbooks in `scenarios/<domain>/NN-<kebab-name>.md` for `learning-network-guides`.

## When to use

- Creating a new troubleshooting or maintenance scenario under `scenarios/`.
- Auditing, expanding, or normalizing an existing file in `scenarios/`.
- Updating `scenarios/README.md` after adding a scenario.

## Hard rules for the author model

1. **Actionable NetOps runbooks:** Every scenario starts from a concrete symptom reported in production (e.g., *"Broadcast storm drops the floor"*, *"VLAN 20 cannot reach the server after switch replacement"*, *"PPPoE/WireGuard clients load pings and Google search, but heavy HTTPS pages freeze"*).
2. **Mandatory template:** Follow [`assets/scenario-template.md`](assets/scenario-template.md) section by section. Never omit a required section.
3. **Catalog compliance:** Check [`references/catalog-and-standards.md`](references/catalog-and-standards.md) for the target domain folder (`l1-l2`, `l3-routing`, `security-vpn`, `wireless`, `maintenance`), sequential numbering `NN-`, and required root cause.
4. **Multi-vendor Quick Triage:** The `## ⚡ Quick command (NetOps Triage)` section must show the immediate 30-second diagnostic commands in **Cisco IOS**, **MikroTik RouterOS v7**, and **Linux/Generic Switch**.
5. **No destructive first actions:** Never tell the operator to reboot a core router, flush all firewall rules, or factory-reset an appliance as the first step. Always observe → isolate layer → verify → mitigate with rollback ready.
6. **Verify / Action / Rollback mitigation:** The `## 🧯 Mitigación y Rollback` section must explicitly separate `Verificar antes de tocar`, `Acción correctiva` (per vendor), and `Rollback inmediato`.
7. **File naming & language:** Filename in English ASCII `NN-kebab-name.md` (two-digit sequential prefix per domain, no accents, no emojis). Content in clear, technical Spanish.
8. **Markdownlint compliance:** Always specify a language on fenced code blocks (`text`, `bash`, `cisco`), surround headings and lists with blank lines, and run `pnpm lint:md` before finishing.

## Decision table

| Situation | Required action |
|---|---|
| Scenario is an unplanned outage or degradation | Place in `l1-l2/`, `l3-routing/`, `security-vpn/`, or `wireless/` and structure the diagnosis from lowest suspect OSI layer upward. |
| Scenario is a planned change (firmware upgrade, switch swap, VLAN migration) | Place in `maintenance/` and structure the runbook into `Pre-checks & Backup` → `Ventana de cambio con Safe Mode/Reload` → `Post-checks & Rollback`. |
| Fix involves changing trunk/firewall on a remote device | Explicitly remind the operator to enable `Safe Mode` (`Ctrl+X`) or `reload in 10` before executing the command. |

## Execution workflow

1. Read [`assets/scenario-template.md`](assets/scenario-template.md) and [`references/catalog-and-standards.md`](references/catalog-and-standards.md).
2. Create `scenarios/<domain>/NN-<kebab-name>.md` with a realistic topology diagram, authentic anomalous CLI outputs, and step-by-step vendor remediation.
3. Update `scenarios/README.md` turning the plain backtick entry into an active link.
4. Run `pnpm lint:md` and fix any errors before reporting completion.
