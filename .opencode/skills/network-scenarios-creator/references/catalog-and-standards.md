# Catálogo y Estándares para `scenarios/`

Cada escenario en `scenarios/<dominio>/NN-<kebab-name>.md` representa un caso real del día a día de un ingeniero de redes o administrador de infraestructura.

---

## Estructura de dominios y escenarios

### 1. `scenarios/l1-l2/` — Incidentes de Capa Física y Switching Capa 2

| Archivo | Problema real a resolver |
|---------|--------------------------|
| `01-cable-pair-broken-100mbps-crc.md` | Enlace Gigabit cae a `100Mbps` o sufre microcortes y errores `CRC/FCS` crecientes por par trenzado dañado o duplex mismatch; diagnóstico con `ethtool`, `cable-test` TDR y contadores de switch. |
| `02-stp-broadcast-storm-and-mac-flapping.md` | Un usuario conecta un cable entre dos bocas de pared (o un switch doméstico en bucle) y tira toda la oficina: CPU de switches al 100%, *MAC Flapping* entre puertos y cómo rastrear el puerto exacto del bucle. |
| `03-vlan-trunk-pvid-and-native-mismatch.md` | Se conecta un switch MikroTik o Aruba a un switch Cisco por un enlace Trunk y las VLANs etiquetadas pasan, pero la VLAN nativa o una VLAN nueva no tiene tráfico (o salta alerta `%CDP-4-NATIVE_VLAN_MISMATCH`). |
| `04-poe-budget-exceeded-and-camera-reboots.md` | Las cámaras IP PTZ o puntos de acceso WiFi se reinician solos de noche (cuando encienden los infrarrojos IR) porque el switch supera su presupuesto total en watts o la caída de tensión en un cable de 95m baja de 44V. |
| `05-lacp-bonding-misconfiguration-and-split.md` | Se arma un EtherChannel / Bonding LACP de 2 puertos entre un switch y un servidor o entre dos switches, pero un puerto queda suspendido (`individual` / `suspended`) o se pierden el 50% de los paquetes. |
| `06-sfp-optical-power-degradation.md` | Enlace de fibra óptica entre edificios sufre caídas aleatorias: lectura de DDM/DOM (`Rx Power -27 dBm` al borde del umbral de pérdida de señal `LOS`), limpieza de conectores LC y atenuación. |

### 2. `scenarios/l3-routing/` — Incidentes de Enrutamiento, MTU y Multi-WAN

| Archivo | Problema real a resolver |
|---------|--------------------------|
| `01-mtu-mss-blackhole-pppoe-and-vpn.md` | **El clásico dolor de cabeza:** El `ping 8.8.8.8` y la búsqueda de Google funcionan, pero las páginas HTTPS pesadas, bancos o adjuntos de correo se quedan congelados cargando por MTU menor en PPPoE (`1492`) o WireGuard/IPsec (`1420`) sin *TCP MSS Clamping*. |
| `02-inter-vlan-asymmetric-routing-and-conntrack-drop.md` | Las conexiones entre dos subredes internas se cortan a los 30 segundos porque los paquetes de ida pasan por el firewall y los de vuelta van directo por un switch L3, haciendo que el firewall stateful descarte los `ACK` como `INVALID`. |
| `03-ospf-neighbor-stuck-in-exstart-or-init.md` | Dos routers (ej. Cisco y MikroTik/FRR) se ven por ping en el enlace punto a punto, pero la adyacencia OSPF nunca llega a `Full` (queda trabada en `ExStart/Exchange` por diferencia de MTU o en `Init/Down` por timers/área/subred). |
| `04-dual-wan-failover-zombie-isp.md` | El proveedor principal de fibra se queda sin salida a Internet, pero el módem/ONT mantiene encendido el enlace Ethernet hacia el router (`Link Up`), por lo que la ruta por defecto común no conmuta al ISP de backup. |
| `05-vrrp-split-brain-dual-master.md` | Dos routers con VRRP/HSRP se declaran `Master/Active` al mismo tiempo (*Split-Brain*) porque una VLAN o filtro en el switch bloquea el multicast `224.0.0.18`, provocando pérdida intermitente de paquetes en toda la LAN. |

### 3. `scenarios/security-vpn/` — Incidentes de Seguridad de Red, NAT y VPNs

| Archivo | Problema real a resolver |
|---------|--------------------------|
| `01-rogue-dhcp-server-on-lan.md` | La mitad de las PCs de la oficina reciben una IP `192.168.0.x` sin salida a sistemas internos porque alguien conectó un router WiFi hogareño por su boca LAN a la red de la empresa; detección de la MAC del intruso y bloqueo con *DHCP Snooping*. |
| `02-hairpin-nat-internal-domain-unreachable.md` | Se publica un servidor web o NVR por Port Forwarding (`DNAT`): desde 4G/exterior funciona perfecto con el dominio público, pero desde las computadoras dentro de la misma oficina no carga. |
| `03-site-to-site-vpn-up-but-no-traffic.md` | El túnel WireGuard o IPsec entre Casa Central y Sucursal figura activo (`Handshake OK` / `Phase 2 Established`), pero las PCs de una sede no llegan a las de la otra porque la regla de `MASQUERADE` de Internet está haciendo NAT sobre el tráfico privado antes de entrar al túnel. |
| `04-router-management-exposed-and-brute-force.md` | El router de borde tiene la CPU alta y los logs llenos de intentos de login por SSH/WinBox/Telnet desde miles de IPs públicas: cierre del plano de gestión en WAN sin cortarse el propio acceso administrativo. |

### 4. `scenarios/wireless/` — Incidentes de WiFi Corporativo

| Archivo | Problema real a resolver |
|---------|--------------------------|
| `01-wifi-sticky-clients-and-roaming-failure.md` | Los usuarios caminan con su laptop del salón de ventas a la sala de reuniones y se quedan sin red porque su dispositivo sigue aferrado al AP lejano a `-82 dBm` en vez de saltar al AP del techo con `-48 dBm` (potencia TX excesiva en 2.4GHz y falta de `802.11k/v/r`). |
| `02-ssid-vlan-dhcp-timeout-on-ap-trunk.md` | Los usuarios conectan al WiFi `"Empresa-Corp"` pero quedan en *"Obteniendo dirección IP..."* y reciben `169.254.x.x` (APIPA) porque la VLAN del SSID no fue agregada como `tagged` en el puerto del switch donde está enchufado ese AP específico. |

### 5. `scenarios/maintenance/` — Ventanas de Mantenimiento y Migraciones Reales

| Archivo | Tarea de mantenimiento paso a paso |
|---------|------------------------------------|
| `01-flat-network-to-vlans-zero-downtime-migration.md` | Cómo migrar una empresa que tiene todo mezclado en `192.168.1.0/24` (PCs, servidores, cámaras, impresoras y WiFi) a una arquitectura segmentada por VLANs sin parar la operación del negocio. |
| `02-core-switch-replacement-and-config-translation.md` | Reemplazo físico y lógico de un switch principal viejo (ej. Cisco Catalyst) por uno nuevo (ej. MikroTik CRS3xx o Aruba) traduciendo trunks, access ports, LACP y VLAN de gestión sin errores. |
| `03-remote-router-firmware-upgrade-and-recovery-drill.md` | Procedimiento estandarizado para actualizar RouterOS/RouterBOOT o Cisco IOS en un router remoto crítico: pre-checks, backup `.rsc` + `.backup`, ejecución, verificación de rutas/VPNs y plan de contingencia con partición/consola OOB. |
