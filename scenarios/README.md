⬅️ [Volver al README principal](../README.md)

# 🚨 Escenarios Reales y Runbooks de Mantenimiento

Casos reales del día a día resueltos paso a paso: desde el síntoma inicial reportado por los usuarios hasta el aislamiento de la capa culpable, la corrección en **Cisco, MikroTik, Switches Gestionables y Linux**, y el plan de rollback.

---

## 🗂️ Catálogo de escenarios por dominio (20/20 Completados)

### 1. `l1-l2/` — Incidentes de Capa Física y Switching Capa 2

| # | Escenario | Nivel | Problema real que resuelve |
|---|-----------|:-----:|----------------------------|
| 01 | [`01-cable-pair-broken-100mbps-crc.md`](l1-l2/01-cable-pair-broken-100mbps-crc.md) | 🟢 Básico | Enlace Gigabit baja a `100Mbps` o acumula errores `CRC/FCS` por par cortado o duplex mismatch |
| 02 | [`02-stp-broadcast-storm-and-mac-flapping.md`](l1-l2/02-stp-broadcast-storm-and-mac-flapping.md) | 🟡 Intermedio | Tormenta de broadcast y *MAC Flapping* por bucle físico en un escritorio que tumba toda la red |
| 03 | [`03-vlan-trunk-pvid-and-native-mismatch.md`](l1-l2/03-vlan-trunk-pvid-and-native-mismatch.md) | 🟡 Intermedio | Incompatibilidad de Native VLAN / PVID o falta de etiqueta en enlace Trunk entre switches de distintas marcas |
| 04 | [`04-poe-budget-exceeded-and-camera-reboots.md`](l1-l2/04-poe-budget-exceeded-and-camera-reboots.md) | 🟢 Básico | Cámaras IP o APs se reinician de noche al encender infrarrojos por presupuesto PoE agotado o caída de tensión |
| 05 | [`05-lacp-bonding-misconfiguration-and-split.md`](l1-l2/05-lacp-bonding-misconfiguration-and-split.md) | 🟡 Intermedio | Enlace agregado LACP (EtherChannel / Bonding) con puertos suspendidos o pérdida del 50% de paquetes |
| 06 | [`06-sfp-optical-power-degradation.md`](l1-l2/06-sfp-optical-power-degradation.md) | 🟡 Intermedio | Enlace de fibra óptica intermitente por atenuación excesiva (`Rx Power dBm` al límite de `LOS`) |

### 2. `l3-routing/` — Incidentes de Enrutamiento, MTU y Multi-WAN

| # | Escenario | Nivel | Problema real que resuelve |
|---|-----------|:-----:|----------------------------|
| 01 | [`01-mtu-mss-blackhole-pppoe-and-vpn.md`](l3-routing/01-mtu-mss-blackhole-pppoe-and-vpn.md) | 🔴 Avanzado | El ping y Google andan, pero sitios HTTPS pesados se congelan por cuello de botella de MTU/MSS en PPPoE o VPN |
| 02 | [`02-inter-vlan-asymmetric-routing-and-conntrack-drop.md`](l3-routing/02-inter-vlan-asymmetric-routing-and-conntrack-drop.md) | 🔴 Avanzado | Conexiones internas se cortan a los 30 segundos por ruta asimétrica que el firewall stateful descarta como `INVALID` |
| 03 | [`03-ospf-neighbor-stuck-in-exstart-or-init.md`](l3-routing/03-ospf-neighbor-stuck-in-exstart-or-init.md) | 🔴 Avanzado | Dos routers se ven por ping pero OSPF queda trabado en `ExStart` (MTU), `Init` o no instala rutas (`ptp` vs `broadcast`) |
| 04 | [`04-dual-wan-failover-zombie-isp.md`](l3-routing/04-dual-wan-failover-zombie-isp.md) | 🟡 Intermedio | El ISP principal pierde salida a Internet pero el módem mantiene el puerto Ethernet `UP` y el failover no activa |
| 05 | [`05-vrrp-split-brain-dual-master.md`](l3-routing/05-vrrp-split-brain-dual-master.md) | 🔴 Avanzado | Dos routers VRRP/HSRP actúan como `Master` a la vez (*Split-Brain*) porque el firewall o switch bloquea su multicast |

### 3. `security-vpn/` — Incidentes de Seguridad, NAT y VPNs

| # | Escenario | Nivel | Problema real que resuelve |
|---|-----------|:-----:|----------------------------|
| 01 | [`01-rogue-dhcp-server-on-lan.md`](security-vpn/01-rogue-dhcp-server-on-lan.md) | 🟡 Intermedio | Un router doméstico enchufado por error en una boca de red reparte IPs falsas y deja sin red a la oficina |
| 02 | [`02-hairpin-nat-internal-domain-unreachable.md`](security-vpn/02-hairpin-nat-internal-domain-unreachable.md) | 🟡 Intermedio | Un servidor publicado por Port Forwarding se ve desde Internet/4G pero no abre desde adentro de la propia oficina |
| 03 | [`03-site-to-site-vpn-up-but-no-traffic.md`](security-vpn/03-site-to-site-vpn-up-but-no-traffic.md) | 🟡 Intermedio | El túnel WireGuard/IPsec está `UP`, pero el tráfico entre sedes falla porque la regla de `MASQUERADE` de WAN lo pisa |
| 04 | [`04-router-management-exposed-and-brute-force.md`](security-vpn/04-router-management-exposed-and-brute-force.md) | 🟢 Básico | Router con CPU alta bajo ataque de fuerza bruta a SSH/WinBox/Telnet desde WAN y cierre seguro sin perder acceso |

### 4. `wireless/` — Incidentes de WiFi Corporativo

| # | Escenario | Nivel | Problema real que resuelve |
|---|-----------|:-----:|----------------------------|
| 01 | [`01-wifi-sticky-clients-and-roaming-failure.md`](wireless/01-wifi-sticky-clients-and-roaming-failure.md) | 🟡 Intermedio | Dispositivos quedan "pegados" a un AP lejano con mala señal en lugar de saltar al AP cercano |
| 02 | [`02-ssid-vlan-dhcp-timeout-on-ap-trunk.md`](wireless/02-ssid-vlan-dhcp-timeout-on-ap-trunk.md) | 🟢 Básico | El WiFi conecta pero no entrega IP (`169.254.x.x`) porque falta la VLAN `tagged` en el puerto del switch del AP |

### 5. `maintenance/` — Ventanas de Mantenimiento y Migraciones del Día a Día

| # | Escenario | Nivel | Tarea de mantenimiento paso a paso |
|---|-----------|:-----:|------------------------------------|
| 01 | [`01-flat-network-to-vlans-zero-downtime-migration.md`](maintenance/01-flat-network-to-vlans-zero-downtime-migration.md) | 🔴 Avanzado | Migrar una red plana (`192.168.1.0/24`) a VLANs separadas (Datos, Servidores, CCTV, WiFi) sin frenar la empresa |
| 02 | [`02-core-switch-replacement-and-config-translation.md`](maintenance/02-core-switch-replacement-and-config-translation.md) | 🟡 Intermedio | Reemplazar un switch principal traduciendo su configuración (Cisco ↔ MikroTik ↔ Aruba) con verificación de impacto |
| 03 | [`03-remote-router-firmware-upgrade-and-recovery-drill.md`](maintenance/03-remote-router-firmware-upgrade-and-recovery-drill.md) | 🟡 Intermedio | Actualizar firmware de un router remoto crítico con pre-checks, backup `.rsc` y plan de rollback probado |

---

⬅️ [Volver al README principal](../README.md)
