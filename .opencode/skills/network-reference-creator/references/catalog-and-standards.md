# Catálogo y Estándares para `reference/`

Cada documento en `reference/` es una tabla de consulta de alta densidad lista para usar durante guardias, diseños o mantenimientos.

---

## Catálogo maestro de `reference/`

| # | Archivo (`reference/`) | Tablas obligatorias que debe incluir |
|---|------------------------|--------------------------------------|
| 1 | `multivendor-cli-rosetta-stone.md` | Traducción directa de comandos y conceptos entre **Cisco IOS**, **MikroTik RouterOS v7**, **Aruba/HP ProCurve**, **Ubiquiti EdgeOS/UniFi** y **Linux (`iproute2`/`bridge`/`FRR`)** dividida en: Sistema/Config/Backup, Interfaces/Capa 1, Switching/VLANs/STP/LACP, Routing/ARP/OSPF/BGP, Firewall/NAT/Conntrack y Diagnóstico/Captura. Incluye tabla de decodificación de flags de MikroTik (`D`, `R`, `S`, `H`, `X`, `I`, `A`, `C`) y Cisco (`C`, `L`, `S`, `O`, `B`, `*`, `P`, `I`). |
| 2 | `ipv4-cidr-vlsm-and-special-ranges.md` | Tabla completa de máscaras CIDR (`/8` a `/32`) con máscara decimal, wildcard mask (Cisco ACLs), total de IPs, hosts útiles y equivalente en `/24`s; tabla de rangos especiales IANA/RFC (`RFC 1918`, `CGNAT 100.64.0.0/10`, `APIPA 169.254.0.0/16`, `Loopback 127.0.0.0/8`, `Multicast 224.0.0.0/4`, `TEST-NET`); plantilla de direccionamiento corporativo recomendado por sede y VLAN. |
| 3 | `physical-media-fiber-sfp-and-poe-reference.md` | Tabla de categorías de cobre (`Cat5e` a `Cat8`, ancho de banda MHz, distancia a 1G/2.5G/5G/10G); pinout RJ45 `T568A` vs `T568B` y qué pares usan Fast Ethernet, Gigabit y PoE (Modo A vs Modo B); tabla de fibra óptica (`OS2` monomodo vs `OM1/OM2/OM3/OM4/OM5` multimodo, color de chaqueta, longitud de onda `850nm/1310nm/1550nm`); umbrales de potencia óptica SFP DDM/DOM en `dBm` (Normal, Saturación, Alarma Baja, `LOS`); estándares PoE (`802.3af/at/bt` Tipo 1 a 4 y pasivo 24V/48V). |
| 4 | `ieee-and-ietf-networking-standards.md` | Mapa de estándares `IEEE 802.x` (`802.1Q` VLAN, `802.1ad` QinQ, `802.1D/w/s` STP/RSTP/MSTP, `802.1AB` LLDP, `802.1X` NAC, `802.3ad/1AX` LACP, `802.3af/at/bt` PoE, `802.11a/b/g/n/ac/ax/be` WiFi y `802.11k/v/r` Roaming) y RFCs esenciales con explicación de 1 línea de para qué sirven en campo. |
| 5 | `network-ports-protocols-and-multicast.md` | Puertos TCP/UDP críticos para infraestructura de red (SSH `22`, Telnet `23`, TACACS+ `49`, DNS `53`, DHCP `67/68`, TFTP `69`, NTP `123`, SNMP `161/162`, BGP `179`, Syslog `514/6514`, IPsec `UDP 500/4500`, RTSP `554`, RADIUS `1812/1813`, NetFlow/IPFIX `2055/4739`, WinBox `8291`, API RouterOS `8728/8729`, WireGuard `UDP 51820`); números de protocolo IP (`1` ICMP, `6` TCP, `17` UDP, `47` GRE, `50` ESP, `89` OSPF, `112` VRRP); direcciones MAC e IP Multicast bien conocidas (`224.0.0.1`, `224.0.0.2`, `224.0.0.5/6` OSPF, `224.0.0.18` VRRP, `224.0.0.102` HSRP, `01:80:C2:00:00:00` STP). |
| 6 | `symptom-to-layer-troubleshooting-matrix.md` | Matriz rápida de guardia: **Síntoma observado** → **Capa OSI sospechosa** → **Primer comando en Cisco / MikroTik / Linux** → **Causa raíz más probable** → **Escenario o guía a abrir**. |
