⬅️ [Volver al README principal](../README.md)

# 🧪 Laboratorios Prácticos de Redes (`labs/`)

Topologías reproducibles para practicar switching, routing, VLANs, firewalls y troubleshooting sin necesidad de comprar equipamiento físico.

---

## 🧰 Motores de laboratorio soportados

1. **Docker Compose + Linux Bridge / Open vSwitch + FRRouting:** Ideal para levantar en segundos topologías con VLANs `802.1Q`, bonding LACP, subredes, OSPF, BGP, VRRP y firewalls stateful en cualquier PC con Docker.
2. **Containerlab (`*.clab.yml`):** El estándar moderno de NetOps para interconectar contenedores FRRouting, Linux hosts, MikroTik RouterOS (**CHR** via vrnetlab) y Cisco IOS/cEOS en topologías declarativas.

---

## 🗂️ Topologías planificadas

| Topología | Qué permite practicar |
|-----------|-----------------------|
| `lab-01-vlan-trunk-and-roas` | Segmentación 802.1Q, puertos Access/Trunk/PVID y Router-on-a-Stick con aislamiento entre departamentos |
| `lab-02-stp-loops-and-lacp` | Simulación segura de bucles L2, elección de Root Bridge RSTP y agregación de enlaces LACP 802.3ad |
| `lab-03-ospf-vrrp-and-dual-wan` | Enrutamiento dinámico OSPF multi-área, redundancia de gateway con VRRP y failover de doble salida a Internet |
| `lab-04-nat-hairpin-and-wireguard` | Firewall por zonas, Port Forwarding, Hairpin NAT, ajuste de MTU/MSS y túnel VPN Site-to-Site con WireGuard |

---

⬅️ [Volver al README principal](../README.md)
