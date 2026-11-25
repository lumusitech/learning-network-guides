---
name: network-reference-creator
description: >-
  Create and maintain high-density multi-vendor networking quick-reference
  tables and cheatsheets under reference/ in learning-network-guides (CLI
  Rosetta Stone Cisco/MikroTik/Aruba/Linux, CIDR/VLSM, IEEE/RFC standards,
  optical dBm/PoE pinouts, and symptom-to-layer diagnostic maps).
---

# Network Reference Creator

Author high-density quick-reference cheatsheets in `reference/<kebab-name>.md` for `learning-network-guides`.

## When to use

- Creating a new quick-reference table or cheatsheet in `reference/`.
- Updating or expanding an existing reference file in `reference/`.
- Updating `reference/README.md` after adding a reference document.

## Hard rules for the author model

1. **Zero fluff, 100% lookup density:** Files in `reference/` are field cheatsheets for an engineer during an incident or configuration session. Prioritize scannable Markdown tables, exact values, flag meanings, and side-by-side command translations over long narrative prose.
2. **Mandatory template & Gold Standard:** Follow [`assets/reference-template.md`](assets/reference-template.md) and match the structure and precision of [`../../../reference/multivendor-cli-rosetta-stone.md`](../../../reference/multivendor-cli-rosetta-stone.md).
3. **Catalog compliance:** Check [`references/catalog-and-standards.md`](references/catalog-and-standards.md) for the exact filename and required tables.
4. **Actionable interpretation column:** Every table of codes, states, dBm levels, or flags must include an interpretation/action column (*"Qué significa / Qué revisar"*).
5. **File naming & language:** Filename in English ASCII `kebab-name.md` (no numbers, no accents, no emojis). Content in clear, technical Spanish.
6. **Markdownlint compliance:** Always specify a language on fenced code blocks (`text`, `bash`, `cisco`), surround headings, lists, and tables with blank lines, and run `pnpm lint:md` before finishing.

## Decision table

| Situation | Required action |
|---|---|
| Reference compares commands across vendors | Include columns for **Tarea**, **Cisco IOS**, **MikroTik RouterOS v7**, **Aruba / Ubiquiti / Genérico**, and **Linux (`iproute2`/`bridge`/`FRR`)**. |
| Reference covers physical or numeric values (CIDR, PoE, SFP dBm, timers) | Include exact IEEE/RFC standard numbers, min/typical/max thresholds, and alarm thresholds. |

## Execution workflow

1. Read [`assets/reference-template.md`](assets/reference-template.md) and [`references/catalog-and-standards.md`](references/catalog-and-standards.md).
2. Create `reference/<kebab-name>.md` with complete, accurate tables verified against IEEE/IETF and vendor standards.
3. Update `reference/README.md` turning the plain backtick entry into an active link.
4. Run `pnpm lint:md` and fix any errors before reporting completion.
