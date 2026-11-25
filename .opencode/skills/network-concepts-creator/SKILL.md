---
name: network-concepts-creator
description: >-
  Create and maintain professional networking mental-model documents under
  concepts/ in learning-network-guides, covering OSI, TCP/IP, Layer 1 physical
  media, switching, routing, NAT, firewalls, wireless, and daily NetOps
  maintenance with multi-vendor terminology mapping (Cisco, MikroTik, Aruba,
  Ubiquiti, Linux).
---

# Network Concepts Creator

Author conceptual mental-model documents in `concepts/<kebab-name>.md` for `learning-network-guides`.

## When to use

- Creating a new networking concept document in `concepts/`.
- Auditing, expanding, or normalizing an existing file in `concepts/`.
- Updating `concepts/README.md` after adding a concept.

## Hard rules for the author model

1. **Pure mental models, not CLI runbooks:** Explain *how the protocol or mechanism works internally*, *why it fails*, and *how vendors name the same thing*. Do not paste long step-by-step configuration scripts (those belong in `guides/` and `scenarios/`).
2. **Mandatory template & Gold Standards:** Follow [`assets/concept-template.md`](assets/concept-template.md) section by section and match the technical depth, clarity, and tone of the Gold Standard examples [`../../../concepts/how-to-think-like-network-engineer.md`](../../../concepts/how-to-think-like-network-engineer.md) and [`../../../concepts/osi-and-tcp-ip-models.md`](../../../concepts/osi-and-tcp-ip-models.md).
3. **Catalog compliance:** Check [`references/catalog-and-standards.md`](references/catalog-and-standards.md) for the target concept's required subtopics, OSI layer scope, and multi-vendor terms before writing.
4. **Multi-vendor terminology table:** Every concept must include a table mapping the standard IEEE/IETF term to **Cisco IOS**, **MikroTik RouterOS**, **Generic/Aruba/Ubiquiti/TP-Link**, and **Linux**.
5. **Visual ASCII diagram:** Include at least one fenced `text` block showing packet flow, frame headers, state transitions, or physical topology.
6. **Normal vs. Anomalous signals:** Include a diagnostic table contrasting healthy network behavior with failure symptoms and their root layer.
7. **30-second mental model:** The `## 🧠 Modelo mental` section must include the exact phrase `"Pensá en esto como..."` and explain the concept with a concrete physical analogy.
8. **File naming & language:** Filename in English ASCII `kebab-case.md` (no numbers, no accents, no emojis). Document content in clear, technical Spanish.
9. **Markdownlint compliance:** Always specify a language on fenced code blocks (`text`, `bash`, `cisco`), surround headings and lists with blank lines, and run `pnpm lint:md` before finishing.

## Decision table

| Situation | Required action |
|---|---|
| User asks for a concept from the catalog | Look up its required scope in [`references/catalog-and-standards.md`](references/catalog-and-standards.md), read [`../../../concepts/osi-and-tcp-ip-models.md`](../../../concepts/osi-and-tcp-ip-models.md) as quality benchmark, and instantiate [`assets/concept-template.md`](assets/concept-template.md). |
| User asks for a concept not in the catalog | Map it to the closest OSI layer, apply [`assets/concept-template.md`](assets/concept-template.md), and register it in `concepts/README.md`. |
| Concept mentions a vendor-specific feature | Explain the underlying IEEE/IETF standard first, then contrast vendor names in the equivalence table. |
| Target guide/scenario link does not exist yet | Link to related sibling files in `concepts/` without leaving empty `[]()` links. |

## Execution workflow

1. Read [`assets/concept-template.md`](assets/concept-template.md), [`references/catalog-and-standards.md`](references/catalog-and-standards.md), and one Gold Standard file in `concepts/`.
2. Draft `concepts/<kebab-name>.md` covering every required subtopic with technical depth (real header fields, timers, frame sizes, IEEE/RFC standards).
3. Update `concepts/README.md` changing the plain backtick entry `` `file.md` `` into an active link `` [`file.md`](file.md) ``.
4. Run `pnpm lint:md` and fix any formatting errors before reporting completion.
