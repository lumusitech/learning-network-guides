# AGENTS.md — Directivas y Arquitectura Pedagógica de `learning-network-guides`

## 🎯 Propósito del proyecto

Sistema de aprendizaje profesional para **ingeniería, administración y operación de redes (NetOps)**. No es un volcado de comandos sueltos de un único fabricante: es un framework de entrenamiento progresivo desde la Capa 1 (física) y los modelos **OSI / TCP-IP** hasta la configuración multi-vendor (**Cisco IOS, MikroTik RouterOS v7, Aruba/Ubiquiti/TP-Link y Linux**), el mantenimiento preventivo del día a día y la respuesta a incidentes reales.

**Frase guía:**
> No memorizamos menús de una sola marca. Dominamos los protocolos estándar (IEEE / IETF) y sabemos traducirlos, mantenerlos y diagnosticarlos en cualquier fabricante.

---

## 📁 Estructura del repositorio

```text
.
├── concepts/          # 🧠 Modelos mentales y funcionamiento interno de protocolos (Capas 1 a 7)
├── guides/            # 🛠️ Configuración, verificación y mantenimiento multi-vendor
│   ├── 01-fundamentals/     # Consola serie, SSH/OOB, LLDP/CDP/MNDP, captura de paquetes
│   ├── 02-switching-l2/     # VLANs (802.1Q), Trunks/PVID, RSTP, LACP, SPAN, DHCP Snooping
│   ├── 03-routing-l3/       # Inter-VLAN (ROAS/SVI), rutas estáticas, OSPF, VRRP/HSRP, Dual-WAN
│   ├── 04-firewalls-nat-vpn/# Firewall Stateful, NAT/Hairpin NAT, WireGuard, IPsec IKEv2
│   ├── 05-wireless-poe/     # WiFi corporativo, roaming, PoE budget, diagnóstico físico SFP/TDR
│   ├── 06-mikrotik/         # Especialización RouterOS v7 (Bridge VLAN Filtering, QoS/PCQ, Mangle)
│   ├── 07-cisco/            # Especialización Cisco IOS (CLI hardening, ROMMON, upgrades)
│   └── 08-operations/       # Día a día: backups en Git, upgrades sin corte, SNMP/Syslog/NetFlow
├── labs/              # 🧪 Topologías reproducibles (Docker / FRRouting / Open vSwitch / Containerlab)
├── scenarios/         # 🚨 Incidentes y ventanas de mantenimiento reales paso a paso (Runbooks)
│   ├── l1-l2/               # Cable/CRC, bucles STP, mismatch de Native VLAN/PVID, PoE, LACP, SFP
│   ├── l3-routing/          # Blackhole de MTU/MSS, rutas asimétricas, OSPF trabado, failover WAN, VRRP
│   ├── security-vpn/        # Rogue DHCP, Hairpin NAT, VPN sin tráfico por NAT, gestión expuesta
│   ├── wireless/            # Clientes pegados (roaming), timeout DHCP en VLAN de SSID
│   └── maintenance/         # Migración a VLANs sin corte, reemplazo de switch core, upgrade remoto
├── reference/         # 📚 Tablas de alta densidad (Piedra Rosetta CLI, CIDR, Fibra/PoE, IEEE/RFC)
├── .github/workflows/ # ⚙️ Validación automática en CI (Markdownlint)
└── .opencode/skills/  # 🧩 Skills especializadas para guiar a cualquier modelo de IA
```

**Flujo pedagógico:**

```text
concepts → guides → labs → scenarios ↔ reference
entender → configurar → practicar → diagnosticar y mantener
```

---

## 🧩 Skills del proyecto (Obligatorias al crear o editar contenido)

Cualquier modelo (grande o pequeño) que trabaje en este repositorio **DEBE invocar primero la skill correspondiente** con `skill("<nombre>")` y seguir su plantilla en `assets/` y su catálogo técnico en `references/`:

| Skill | Carpeta objetivo | Qué garantiza |
|-------|------------------|---------------|
| `network-concepts-creator` | `concepts/*.md` | Explicación profunda de protocolos IEEE/IETF, diagrama ASCII byte a byte, diccionario multi-vendor, señales normales vs anómalas, caso real y analogía `"Pensá en esto como..."` |
| `network-guides-creator` | `guides/<dominio>/*.md` | Topología de referencia unificada, configuración comparada en Cisco IOS, MikroTik RouterOS v7 (`Bridge VLAN Filtering`), Switches Gestionables (`Tagged/Untagged/PVID`) y Linux, con interpretación de flags y rollback |
| `network-scenarios-creator` | `scenarios/<dominio>/NN-*.md` | Runbooks de guardia e intervenciones de mantenimiento con Quick Triage multi-vendor, diagnóstico por capas OSI y mitigación con Verificar / Acción / Rollback |
| `network-reference-creator` | `reference/*.md` | Tablas de consulta rápida de alta densidad con columna de interpretación y acción en campo |
| `network-labs-creator` | `labs/docker-compose.*.yml` / `labs/*.sh` | Topologías reproducibles con Alpine (`iproute2`/`bridge`/`iptables`) y FRRouting (`vtysh`), scripts POSIX de entrenamiento ciego (`break-and-fix.sh`) y ejercicios paso a paso |

### Ejemplos Gold Standard de referencia en el repositorio

Antes de redactar un documento nuevo, cualquier agente debe tomar como referencia de calidad y profundidad estos archivos ya publicados:

- Concepto transversal: [`concepts/how-to-think-like-network-engineer.md`](concepts/how-to-think-like-network-engineer.md)
- Concepto de arquitectura y protocolos: [`concepts/osi-and-tcp-ip-models.md`](concepts/osi-and-tcp-ip-models.md)
- Referencia rápida multi-vendor: [`reference/multivendor-cli-rosetta-stone.md`](reference/multivendor-cli-rosetta-stone.md)

---

## 🔒 Reglas de Gobernanza Git y Pull Requests (INQUEBRANTABLES)

1. **PROHIBIDO hacer push directo a `main`:** La rama `main` está reservada exclusivamente para código revisado. Ningún agente ni script puede hacer `git push origin main`.
2. **PROHIBIDO que el agente haga merge de las Pull Requests:** El agente **NUNCA** debe ejecutar `merge_pull_request` ni `gh pr merge`.
3. **Flujo obligatorio para todo cambio:**
   - Crear una rama auxiliar descriptiva desde `main` actualizado:
     - `feat/concepts-<nombre>`
     - `feat/guides-<nombre>`
     - `feat/scenarios-<nombre>`
     - `feat/reference-<nombre>`
     - `feat/labs-<nombre>`
     - `fix/<alcance>-<descripcion>`
   - Validar localmente que no existan errores de formato ejecutando:

     ```bash
     pnpm validate
     ```

   - Hacer commit con mensaje descriptivo en español siguiendo Conventional Commits (ej. `feat(concepts): agregar guía conceptual de capa física, fibra y PoE`).
   - Hacer push de la rama auxiliar (`git push -u origin <rama>`) y abrir la Pull Request hacia `main`.
   - **Detenerse y entregar el enlace de la PR al usuario:** El usuario revisa la PR, la aprueba y realiza el **Squash and Merge** manualmente desde la interfaz web de GitHub.

---

## 🛠️ Comandos de validación

```bash
pnpm lint:md       # Verifica formato Markdown en todo el repositorio (0 errores permitidos)
pnpm lint:md:fix   # Corrige automáticamente problemas de espaciado/listas en Markdown
pnpm validate      # Ejecuta todas las validaciones de CI
```

---

## 📛 Convenciones de nombres e idioma

- **Nombres de archivos y carpetas:** Siempre en inglés, ASCII, `kebab-case.md` (sin tildes, sin `ñ`, sin espacios, sin emojis).
  - En `concepts/` y `reference/`: sin prefijo numérico (`osi-and-tcp-ip-models.md`).
  - En `guides/`: agrupados dentro de sus 8 subcarpetas numeradas (`guides/02-switching-l2/vlans-8021q-access-trunk-pvid.md`).
  - En `scenarios/`: con prefijo secuencial de dos dígitos por subcarpeta (`scenarios/l1-l2/02-stp-broadcast-storm-and-mac-flapping.md`).
- **Idioma del contenido:** Español técnico claro, riguroso y directo, conservando los términos universales de ingeniería de redes (`Trunk`, `Access`, `Tagged`, `Untagged`, `PVID`, `Root Bridge`, `Longest Prefix Match`, `Handshake`, `Conntrack`, `Failover`).
- **Sintaxis MikroTik:** Usar exclusivamente sintaxis moderna de **RouterOS v7+** y **Bridge VLAN Filtering** (`/interface bridge vlan` y `/interface bridge port`).
