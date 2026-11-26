# Catálogo y Estándares de Laboratorios (`labs/`)

## 1. Catálogo de Topologías Docker Compose

| Archivo | Propósito Pedagógico | Contenedores Clave |
|---------|----------------------|--------------------|
| `labs/docker-compose.lab01-vlan-roas.yml` | VLANs 802.1Q (`10` y `20`), Bridge VLAN Filtering (`PVID`, `Untagged`, `Tagged`) y Router-on-a-Stick (ROAS) | `lab01-rtr-roas`, `lab01-pc-vlan10`, `lab01-pc-vlan20` |
| `labs/docker-compose.lab02-stp-and-lacp.yml` | Elección de Root Bridge STP (`4096` vs `32768`), puertos `Forwarding`/`Blocking` e inspección de BPDUs | `lab02-sw-core`, `lab02-sw-access` |
| `labs/docker-compose.lab03-ospf-and-vrrp.yml` | OSPFv2 Area 0 con FRRouting (`vtysh` estilo Cisco IOS), enlaces `point-to-point`, costos `10` vs `100` y ExStart por MTU | `lab03-rtr-core1`, `lab03-rtr-core2`, `lab03-rtr-branch` |
| `labs/docker-compose.lab04-nat-hairpin-mtu.yml` | Firewall Stateful, Masquerade, Port Forwarding (`DNAT`), triángulo roto de Hairpin NAT y tabla `conntrack` | `lab04-fw-edge`, `lab04-srv-web`, `lab04-pc-lan`, `lab04-cli-wan` |
| `labs/docker-compose.integrative.yml` | Proyecto Integrador Capstone Multi-Sede (5 fases: Switching L2, OSPF/VRRP, Firewall Zero-Trust + Hairpin, VPN WireGuard + MSS Clamping) | `rtr-sede1`, `sw-core`, `rtr-sede2`, `srv-erp`, `pc-staff`, `cliente-wan` |

---

## 2. Estándar para el Entrenador Interactivo (`labs/break-and-fix.sh`)

El script `labs/break-and-fix.sh` debe cumplir:

1. **Shebang y seguridad:** `#!/bin/sh` y `set -eu` al inicio. Prohibido usar arrays de Bash, `[[ ]]`, `function` o sustitución de procesos `<()`.
2. **Interfaz CLI de 4 subcomandos:**
   - `sh labs/break-and-fix.sh list` → Muestra la tabla de las 8 misiones con el laboratorio requerido y el síntoma reportado por el usuario.
   - `sh labs/break-and-fix.sh break <1..8|random>` → Verifica que el contenedor del lab esté corriendo, inyecta la falla silenciosamente (`>/dev/null 2>&1`) y muestra el ticket de guardia sin revelar qué comando ejecutó.
   - `sh labs/break-and-fix.sh hint <1..8>` → Da una pista orientada a la capa OSI y qué comando `show`/`ip`/`vtysh`/`iptables` inspeccionar.
   - `sh labs/break-and-fix.sh verify <1..8>` → Ejecuta la sonda real de extremo a extremo (`ping`, `wget`/`curl`, `vtysh -c "show ip ospf neighbor"`) y devuelve código `0` (`✅ INCIDENTE RESUELTO`) o `1` (`❌ El problema persiste`).
