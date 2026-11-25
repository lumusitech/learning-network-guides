⬅️ [Volver a Referencias](README.md)

# 📚 Piedra Rosetta Multi-Vendor CLI — Cisco ↔ MikroTik ↔ Aruba ↔ Linux

**Alcance:** `Capas 1 a 7` | `Cisco IOS / Catalyst` · `MikroTik RouterOS v7` · `Aruba / HP ProCurve` · `Linux (iproute2 / bridge / FRR)`

---

## 🎯 Cómo usar esta referencia

Esta tabla traduce la **misma operación técnica** entre los cuatro ecosistemas más comunes en infraestructura real. Usala cuando sabés qué necesitás verificar o configurar en una marca y querés su equivalente exacto en otra.

---

## 📊 1. Sistema, Configuración, Backups y Salvavidas

| Tarea / Acción | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Aruba / HP ProCurve | Linux (`iproute2` / `systemd`) |
|----------------|----------------------|----------------------|---------------------|--------------------------------|
| **Salvavidas anti-bloqueo remoto** | `reload in 10` (`reload cancel`) | `Ctrl+X` (**Safe Mode**) | `reload after 00:10` | `at now + 10 min` / `iptables-apply` |
| **Ver configuración activa completa** | `show running-config` | `/export` (o `/export terse`) | `show running-config` | `ip addr; ip route; nft list ruleset` |
| **Ver config incluyendo secretos** | `show running-config` | `/export show-sensitive` | `show running-config` | Archivos en `/etc/` con `sudo` |
| **Guardar cambios en memoria persistente** | `write memory` (`copy run start`) | Automático en tiempo real (salvo en Safe Mode) | `write memory` | Persistir en `/etc/netplan/` o `/etc/network/` |
| **Exportar backup legible en texto (Git)** | `copy running-config scp://...` | `/export show-sensitive file=backup` (`.rsc`) | `copy running-config tftp/scp` | `tar czf etc-net.tgz /etc/netplan /etc/frr` |
| **Ver versión, modelo y uptime** | `show version` | `/system resource print` | `show version` / `show system` | `uname -a && uptime` |
| **Ver uso de CPU y memoria RAM** | `show processes cpu sorted` / `show memory` | `/system resource print` / `/tool profile` | `show cpu` / `show memory` | `top` / `free -h` |
| **Ver logs del sistema en vivo** | `show logging` | `/log print follow` | `show logging -r` | `journalctl -f` / `dmesg -T` |

---

## 📊 2. Capa 1 — Interfaces Físicas, SFP/Fibra, Cable Test y PoE

| Tarea / Acción | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Aruba / HP ProCurve | Linux (`iproute2` / `ethtool`) |
|----------------|----------------------|----------------------|---------------------|--------------------------------|
| **Resumen rápido de estado de puertos** | `show interfaces status` | `/interface print` | `show interfaces brief` | `ip -br link show` |
| **Ver velocidad, duplex y link físico** | `show interfaces Gi1/0/1` | `/interface ethernet monitor ether1 once` | `show interfaces 1` | `ethtool eth0` |
| **Ver contadores de errores (CRC/FCS/Drops)** | `show interfaces Gi1/0/1 counters errors` | `/interface ethernet print stats where name=ether1` | `show interfaces 1` | `ip -s link show eth0` / `ethtool -S eth0` |
| **Medir niveles ópticos SFP (DDM / DOM en dBm)** | `show interfaces Gi1/0/25 transceiver detail` | `/interface ethernet monitor sfp-sfpplus1 once` | `show interfaces transceiver 25 detail` | `ethtool -m eth0` |
| **Test de cable UTP integrado (TDR)** | `test cable-diagnostics tdr interface Gi1/0/1` | `/interface ethernet cable-test ether1` | `test cable-diagnostics 1` | `ethtool --cable-test eth0` |
| **Ver consumo y presupuesto PoE** | `show power inline` | `/interface ethernet poe monitor ether1` | `show power-over-ethernet brief` | SNMP OID `1.3.6.1.2.1.105` |
| **Reiniciar energía PoE de un puerto** | `power inline never` → `power inline auto` | `/interface ethernet poe power-cycle ether1` | `no interface 1 power-over-ethernet` → activar | Controlador PoE / SNMP |

---

## 📊 3. Capa 2 — VLANs (802.1Q), Tabla MAC, STP/RSTP, LACP y Vecinos

| Tarea / Acción | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Aruba / HP ProCurve | Linux (`bridge` / `iproute2`) |
|----------------|----------------------|----------------------|---------------------|-------------------------------|
| **Ver tabla de direcciones MAC aprendidas** | `show mac address-table` | `/interface bridge host print` | `show mac-address` | `bridge fdb show` |
| **Buscar en qué puerto está una MAC** | `show mac address-table address <MAC>` | `/interface bridge host print where mac-address=<MAC>` | `show mac-address <MAC>` | `bridge fdb show \| grep -i <MAC>` |
| **Ver resumen de VLANs y puertos** | `show vlan brief` | `/interface bridge vlan print` | `show vlans` | `bridge vlan show` |
| **Ver puertos Trunk y Native VLAN / PVID** | `show interfaces trunk` | `/interface bridge port print` | `show vlans ports 1-24 detail` | `bridge vlan show` |
| **Configurar puerto Access en VLAN 10** | `switchport mode access` + `switchport access vlan 10` | En `/interface bridge port`: `pvid=10 frame-types=admit-only-untagged-and-priority-tagged` | `vlan 10 untagged 5` | `bridge vlan add dev eth1 vid 10 pvid untagged` |
| **Configurar puerto Trunk (VLANs 10, 20)** | `switchport mode trunk` + `switchport trunk allowed vlan 10,20` | En `/interface bridge vlan`: `vlan-ids=10,20 tagged=ether1` | `vlan 10 tagged 1` + `vlan 20 tagged 1` | `bridge vlan add dev eth0 vid 10` + `vid 20` |
| **Ver estado Spanning Tree (STP / RSTP)** | `show spanning-tree` | `/interface bridge monitor bridge1` + `port monitor` | `show spanning-tree` | `bridge link show` / `mstpd` |
| **Ver estado de agregación LACP (802.3ad)** | `show etherchannel summary` | `/interface bonding monitor bond1` | `show trunks` / `show lacp` | `cat /proc/net/bonding/bond0` |
| **Ver equipos vecinos (LLDP / CDP / MNDP)** | `show cdp neighbors detail` / `show lldp neighbors` | `/ip neighbor print detail` | `show lldp info remote-device` | `lldpcli show neighbors` |

---

## 📊 4. Capa 3 — Direccionamiento IP, ARP, Rutas, OSPF y VRRP/HSRP

| Tarea / Acción | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Aruba / HP ProCurve | Linux (`iproute2` / `vtysh` FRR) |
|----------------|----------------------|----------------------|---------------------|----------------------------------|
| **Ver direcciones IP configuradas** | `show ip interface brief` | `/ip address print` | `show ip` | `ip -br addr show` |
| **Ver tabla ARP (IP ↔ MAC)** | `show ip arp` | `/ip arp print` | `show arp` | `ip neigh show` |
| **Ver tabla de enrutamiento (RIB)** | `show ip route` | `/ip route print` | `show ip route` | `ip route show` |
| **Consultar qué ruta toma una IP destino** | `show ip route 10.0.40.10` | `/ip route check 10.0.40.10` | `show ip route 10.0.40.10` | `ip route get 10.0.40.10` |
| **Agregar ruta estática** | `ip route 10.0.50.0 255.255.255.0 10.0.1.2` | `/ip route add dst-address=10.0.50.0/24 gateway=10.0.1.2` | `ip route 10.0.50.0/24 10.0.1.2` | `ip route add 10.0.50.0/24 via 10.0.1.2` |
| **Ver vecinos OSPF y su estado** | `show ip ospf neighbor` | `/routing ospf neighbor print` | `show ip ospf neighbor` | `vtysh -c "show ip ospf neighbor"` |
| **Ver resumen de sesiones BGP** | `show ip bgp summary` | `/routing bgp session print` | `show ip bgp summary` | `vtysh -c "show bgp summary"` |
| **Ver estado de redundancia VRRP / HSRP** | `show standby brief` / `show vrrp brief` | `/interface vrrp print` | `show vrrp` | `ip addr show` (`keepalived` status) |

---

## 📊 5. Capas 4 a 7 — Firewall, NAT, Conntrack y Captura de Tráfico

| Tarea / Acción | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Linux (`nftables` / `conntrack`) |
|----------------|----------------------|----------------------|----------------------------------|
| **Ver reglas de Firewall / ACLs y contadores** | `show access-lists` | `/ip firewall filter print stats` | `nft list ruleset` / `iptables -L -v -n` |
| **Ver reglas de NAT (SNAT / DNAT)** | `show ip nat statistics` | `/ip firewall nat print stats` | `nft list table ip nat` |
| **Ver tabla de conexiones activas (Conntrack)** | `show ip nat translations` | `/ip firewall connection print` | `conntrack -L` / `ss -tan` |
| **Ping desde una IP o interfaz origen específica** | `ping 10.0.40.10 source 10.0.10.1` | `/ping 10.0.40.10 src-address=10.0.10.1` | `ping -I 10.0.10.1 10.0.40.10` |
| **Ping con tamaño fijo sin fragmentar (Test MTU)** | `ping 8.8.8.8 size 1500 df-bit` | `/ping 8.8.8.8 size=1500 do-not-fragment` | `ping -M do -s 1472 8.8.8.8` (`1472+28=1500`) |
| **Capturar paquetes en vivo por consola** | `monitor capture` (EPC) | `/tool sniffer quick interface=ether1 ip-protocol=icmp` | `tcpdump -ni eth0 -e icmp` |

---

## 🔑 6. Decodificador Rápido de Flags en Consola

### Flags de MikroTik RouterOS (`/interface`, `/ip route`, `/ip arp`, `/interface bridge`)

| Flag | Nombre en RouterOS | Dónde aparece | Significado e interpretación en campo |
|:----:|--------------------|---------------|---------------------------------------|
| **`R`** | **Running** | Interfaces | ✅ El enlace físico está levantado (`Link Up`) y operativo |
| **`S`** | **Slave** | Interfaces | El puerto pertenece a un `bridge` o a un `bonding` (la IP/DHCP debe ir en el bridge maestro, nunca en el puerto esclavo) |
| **`H`** | **Hw-Offload** | Bridge Port / VLAN | ✅ El tráfico L2 lo conmuta el **Switch Chip por hardware** a velocidad de cable sin consumir CPU |
| **`D`** | **Dynamic** | IP / Rutas / ARP / VLAN | Entrada creada automáticamente (por DHCP, OSPF, ARP o PVID) |
| **`A`** | **Active** | Rutas (`/ip route`) | ✅ Esta ruta ganó la elección y está instalada activamente en la tabla de reenvío (FIB) |
| **`C`** | **Connected / Complete** | Rutas / ARP | En rutas: red directamente conectada (`AD=0`). En ARP: resolución MAC exitosa y verificada |
| **`X`** | **Disabled** | Cualquier menú | ⚠️ El administrador deshabilitó manualmente esta interfaz, ruta o regla |
| **`I`** | **Invalid / Inactive** | Interfaces / Reglas / Rutas | ❌ **Alerta:** la regla o ruta tiene un parámetro roto (ej. gateway inalcanzable o interfaz caída) |

### Flags de Cisco IOS (`show ip route`, `show etherchannel summary`, `show interfaces status`)

| Flag | Dónde aparece | Significado e interpretación en campo |
|:----:|---------------|---------------------------------------|
| **`C` / `L`** | `show ip route` | **Connected** (subred `/24`) y **Local** (IP exacta `/32` de la interfaz del router) |
| **`S` / `S*`** | `show ip route` | **Static** route (`S*` = candidato a Default Gateway `0.0.0.0/0`) |
| **`O` / `O IA`** | `show ip route` | Ruta aprendida por **OSPF** dentro de la misma área (`O`) o entre áreas (`O IA`) |
| **`P`** | `show etherchannel summary` | ✅ **Bundled in Port-channel**: el puerto físico negocia LACP correctamente y transmite tráfico |
| **`I`** | `show etherchannel summary` | ⚠️ **Stand-alone / Individual**: el otro extremo **no** está respondiendo LACP (revisar config del switch vecino) |
| **`s` / `D`** | `show etherchannel summary` | ❌ **Suspended / Down**: el puerto tiene distinta VLAN, velocidad o duplex que el resto del Port-channel |
| **`err-disabled`** | `show interfaces status` | ❌ **Puerto bloqueado por protección**: revisar causa con `show interfaces status err-disabled` (`bpduguard`, `psecure-violation`, `loopback`) |

---

## 🔗 Ver también

- [`how-to-think-like-network-engineer`](../concepts/how-to-think-like-network-engineer.md) — Metodología de diagnóstico y uso de Safe Mode / reload in
- [`osi-and-tcp-ip-models`](../concepts/osi-and-tcp-ip-models.md) — Qué comando de esta tabla usar según la capa OSI que sospechás
