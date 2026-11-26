⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Proyecto Integrador Capstone — Construir y Operar una Empresa Multi-Sede "Lumen Corp"

**Dominio:** `maintenance`
**Nivel:** 🔴 Avanzado
**Duración estimada:** 4–6 horas (proyecto guiado de 5 fases)
**Capas OSI afectadas:** `Capas 1 a 7 (Arquitectura completa: conmutación, enrutamiento, seguridad, VPN y operación)`
**Equipos involucrados:** `Router de Borde Cisco IOS / MikroTik RouterOS v7`, `Switches Gestionables (Aruba / Ubiquiti)`, `Linux (FRRouting / iproute2 / iptables)`

---

## 🎯 Problema

**Lumen Corp** acaba de alquilar un galpón industrial y abre su **Sucursal 2** a 30 km de la Casa Central. Te contratan como el único ingeniero de redes para **construir toda la infraestructura desde cero y dejarla en producción**: direccionamiento, VLANs, enrutamiento redundante, firewall por zonas, publicación del sistema ERP, túnel entre las dos sedes y monitoreo/backups.

No es un ejercicio de un solo tema: es el **examen final práctico** que obliga a integrar *todos* los conceptos y guías del repositorio. El resultado debe ser una red que:

- Segmente por VLAN (`10, 20, 40, 99, 100, 200`) y aplique *Zero-Trust* (nadie habla con nadie salvo lo estrictamente permitido).
- Tenga **redundancia de gateway** (VRRP/HSRP) y **doble salida a Internet** con conmutación automática.
- Publique el ERP con **DNAT** y resuelva el **Hairpin NAT** para que funcione también desde adentro.
- Interconecte las sedes con un **túnel cifrado** y enrutamiento dinámico **OSPFv2** encima.
- Supere un **checklist de aceptación de 25 pruebas** y quede respaldada en Git.

```text
                               INTERNET (WAN)
                      +=============================+
                      |        Nube / ISP           |
                      +======+==============+=======+
                             |              |
        WAN 203.0.113.2/30   |              |   WAN 198.51.100.2/30
                      +------+-----+        +-----+------+
                      | RTR-SEDE1  |        | RTR-SEDE2  |
                      | Casa Central|<======>| Sucursal 2 |
                      +------+-----+  TUNEL +-----+------+
                             |      10.255.255.0/30  |
            802.1Q Trunk     |                       |   802.1Q Trunk
                      +------+-----+        +-----+------+
                      |  SW-CORE   |        | SW-SUCURSAL|
                      | RSTP Root  |        |            |
                      | 4096 + LACP|        |            |
                      +-+--+--+--+-+        +-----+------+
                        |  |  |  |                |
        VLAN 10 Staff --+  |  |  +-- VLAN 200     +-- VLAN 10 Staff
        VLAN 20 Voz ------+  |     WiFi Guest     +-- VLAN 40 Serv.
        VLAN 40 Servidores --+                VLAN 40 Serv.
        VLAN 99 Gestion ------+

   TUNEL SITE-TO-SITE: WireGuard wg1 (10.255.255.1 <-> 10.255.255.2, MTU 1420)
                        sobre el que corre OSPFv2 Area 0 (point-to-point)
```

> **Laboratorio gemelo:** todo el proyecto es practicable en tu PC con 6 contenedores en [`labs/docker-compose.integrative.yml`](../../labs/docker-compose.integrative.yml).

---

## ⚡ Quick command (Auditoría de arranque en 30 segundos)

Ejecutá esto en cada fase para confirmar que el estado es sano antes de avanzar:

```text
# Cisco IOS
show vlan brief
show interfaces trunk
show ip route ospf
show standby brief          ! o  show vrrp brief

# MikroTik RouterOS v7
/interface bridge vlan print
/interface bridge port print
/ip route print where active
/routing ospf neighbor print
/interface wireguard peers print

# Linux host / FRRouting
ip -br addr
bridge vlan show
ip route show
vtysh -c "show ip ospf neighbor"
wg show
```

---

## ✅ Salida esperada vs Salida anómala

### Estado sano (lo que debés ver al terminar cada fase)

```text
# Vecindad OSPF sobre el túnel ya en FULL (no en EXSTART ni INIT):
Neighbor ID     Pri State           Up Time         Address         Interface
10.255.255.2      1 Full/PointToP   00:03:21        10.255.255.2    wg1

# Hairpin NAT funcionando: desde la PC interna (VLAN 10) el ERP responde usando la IP pública:
pc-staff$ curl -s http://203.0.113.2:8080
<h1>Servidor ERP Lumen Corp (10.1.40.10:8080) - OK</h1>
```

**Interpretación de la evidencia:**

- OSPF en `Full/PointToPoint` → el túnel está estable y la MTU de ambos extremos coincide (no hay `EXSTART`).
- `curl` interno hacia la IP pública resuelve → la cadena `DNAT + Hairpin (srcnat)` está bien armada.

---

## 🧠 Diagnóstico por capas y decisiones de diseño

Antes de tocar un solo comando, entendé *por qué* el diseño es así:

- **Direccionamiento (`10.<Sede>.<VLAN>.<Host>/24`):** cada sede es un bloque agregable `10.1.0.0/16` y `10.2.0.0/16`, de modo que OSPF anuncie **una** ruta por sede en vez de decenas de subredes sueltas.
- **Segmentación Zero-Trust:** 6 zonas internas (`Staff`, `Voz`, `Servidores`, `Gestión`, `CCTV`, `Invitados`) + `WAN`. La regla por defecto en `FORWARD` es **DROP**; solo se abre el flujo estrictamente necesario.
- **Redundancia L2 de primer salto:** RSTP con `Root Bridge` de prioridad `4096` en el switch core y **VRRP/HSRP** en los routers de gateway, para que ninguna PC dependa de un solo equipo.
- **Redundancia WAN:** dos salidas a Internet con **rutas recursivas** (`scope/target-scope` en MikroTik) y chequeo de salud por ping al ISP, no solo estado del enlace (`Link Up ≠ Internet`).
- **Túnel y MTU:** el sitio-a-sitio reduce la MTU útil (WireGuard `1420`, IPsec VTI `1400`) y por eso **siempre** se acompaña de *TCP MSS Clamping*, o los sitios HTTPS pesados se cuelgan.

> **🧠 Modelo mental del capstone:** Pensá en esta red como **construir un edificio de oficinas por pisos**: primero el terreno y la estructura (`direccionamiento + VLANs`), después los ascensores y salidas de emergencia (`VRRP + Dual-WAN`), luego la seguridad de cada piso con llave propia (`firewall por zonas`), más tarde el puente que une dos edificios (`túnel + OSPF`) y, al final, la sala de cámaras y las copias de las llaves (`monitoreo + backups`). Si salteás el terreno, todo lo de arriba se derrumba.

---

## 🛠️ Procedimiento paso a paso (Runbook del Proyecto en 5 Fases)

### Fase 1 — Direccionamiento VLSM y Switching Capa 2

**Objetivo:** definir el plan de direcciones y dejar la planta baja (conmutación) sana, con bucles controlados y seguridad de puertos.

**Plan de direccionamiento (plantilla corporativa):**

| VLAN | Nombre | Sede 1 (Casa Central) | Sede 2 (Sucursal) |
|:----:|--------|-----------------------|-------------------|
| 10 | Staff (Datos) | `10.1.10.0/24` | `10.2.10.0/24` |
| 20 | Voz (VoIP) | `10.1.20.0/24` | `10.2.20.0/24` |
| 40 | Servidores | `10.1.40.0/24` | `10.2.40.0/24` |
| 99 | Gestión | `10.1.99.0/24` | `10.2.99.0/24` |
| 100 | CCTV | `10.1.100.0/24` | — |
| 200 | WiFi Invitados | `10.1.200.0/24` | `10.2.200.0/24` |

**En Cisco IOS (switch Catalyst):**

```cisco
vlan 10,20,40,99,100,200
 exit
! Uplink hacia el router: Trunk con Native VLAN 99 (nunca la VLAN 1)
interface GigabitEthernet1/0/1
 description UPLINK-RTR-SEDE1
 switchport mode trunk
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,40,99,100,200
!
! Puerto de usuario (Access) con PortFast y guardas
interface range GigabitEthernet1/0/10 - 20
 switchport mode access
 switchport access vlan 10
 spanning-tree portfast
 spanning-tree bpduguard enable
!
! Root Bridge deliberado + LACP (2 puertos hacia un SW de piso)
spanning-tree vlan 10,20,40,99,100,200 priority 4096
interface range GigabitEthernet1/0/23 - 24
 channel-group 1 mode active
!
! DHCP Snooping: confiar SOLO en el uplink al router
ip dhcp snooping
ip dhcp snooping vlan 10,20,100,200
interface GigabitEthernet1/0/1
 ip dhcp snooping trust
```

**En MikroTik RouterOS v7 (Bridge VLAN Filtering):**

```text
/interface bridge add name=br0 vlan-filtering=yes frame-types=admit-only-vlan-tagged
/interface bridge port
add bridge=br0 interface=ether2 pvid=10 frame-types=admit-only-untagged-and-priority-tagged
add bridge=br0 interface=ether3 pvid=40 frame-types=admit-only-untagged-and-priority-tagged
add bridge=br0 interface=sfp1 pvid=99 frame-types=admit-only-vlan-tagged
/interface bridge vlan
add bridge=br0 vlan-ids=10,20,40,99,100,200 tagged=sfp1
add bridge=br0 vlan-ids=10  untagged=ether2
add bridge=br0 vlan-ids=40  untagged=ether3
/interface bridge set br0 priority=0x1000
```

**En Linux (host o switch gestionable con CLI):**

```bash
ip link add name br0 type bridge vlan_filtering 1 stp_state 1 priority 4096
ip link set dev br0 up
bridge vlan add dev eth1 vid 10 pvid untagged
bridge vlan add dev eth2 vid 40 pvid untagged
bridge vlan add dev sfp1 vid 10,20,40,99,100,200 tagged
```

---

### Fase 2 — Inter-VLAN, VRRP/HSRP con WAN Tracking y Dual-WAN recursivo

**Objetivo:** enrutar entre VLANs, dar primer salto redundante y conmutar a la WAN de respaldo cuando el ISP principal quede "zombie".

**En MikroTik RouterOS v7:**

```text
# Inter-VLAN por Router-on-a-Stick (ROAS) sobre el trunk y VRRP en la VLAN 10
/interface vlan
add name=vlan10 interface=br0 vlan-id=10
/ip address add address=10.1.10.1/24 interface=vlan10
/interface vrrp add name=vrrp10 interface=vlan10 vrid=10 priority=100
/ip address add address=10.1.10.254/24 interface=vrrp10

# WAN principal (ether1) y WAN de respaldo (ether5) con chequeo de salud real
/interface list add name=WAN
/routing table add name=to-backup fib
/ip route
add dst-address=0.0.0.0/0 gateway=203.0.113.1 check-gateway=ping distance=1 scope=10 target-scope=10
add dst-address=0.0.0.0/0 gateway=192.168.88.1 check-gateway=ping distance=2 scope=10 target-scope=10 routing-table=to-backup
```

**En Cisco IOS (SVI + HSRP + rutas flotantes con object tracking):**

```cisco
interface Vlan10
 ip address 10.1.10.2 255.255.255.0
 standby 10 ip 10.1.10.254
 standby 10 priority 110
 standby 10 preempt
 standby 10 track 1 decrement 20
!
track 1 ip sla 1 reachability
ip sla 1
 icmp-echo 203.0.113.1 source-interface GigabitEthernet0/0
 frequency 5
!
ip route 0.0.0.0 0.0.0.0 203.0.113.1 track 1
ip route 0.0.0.0 0.0.0.0 192.168.88.1 10
```

> **Por qué recursivo:** el proveedor puede dejar de enrutar a Internet **sin bajar el enlace** (ISP *zombie*). `check-gateway=ping` (o `ip sla`) verifica conectividad real y recién ahí conmuta.

---

### Fase 3 — Firewall Stateful Zero-Trust, DNAT/Hairpin, Split-DNS y QoS

**Objetivo:** aislar las 6 zonas, publicar el ERP y administrar el ancho de banda.

**Matriz de zonas (por defecto `DROP` en `FORWARD`, se abre solo lo necesario):**

| Origen ↓ / Destino → | WAN | Staff | Voz | Servidores | Gestión | CCTV | Invitados |
|----------------------|:---:|:-----:|:---:|:----------:|:-------:|:----:|:---------:|
| **WAN** | — | ❌ | ❌ | ✅ (solo `:8080` ERP) | ❌ | ❌ | ❌ |
| **Staff** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Servidores** | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **Gestión** | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **CCTV** | ❌ | ❌ | ❌ | ✅ (solo NVR) | ❌ | ✅ | ❌ |
| **Invitados** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

**En MikroTik RouterOS v7 (DNAT + Hairpin + QoS):**

```text
# Port Forwarding del ERP (DNAT)
/ip firewall nat
add chain=dstnat dst-address=203.0.113.2 protocol=tcp dst-port=8080 action=dst-nat to-addresses=10.1.40.10 to-ports=8080

# Hairpin NAT: el tráfico interno que va a la IP pública debe volver con la IP del router
add chain=srcnat src-address=10.1.0.0/16 dst-address=10.1.40.10 protocol=tcp dst-port=8080 action=masquerade

# Salida a Internet solo para las zonas permitidas
add chain=srcnat src-address=10.1.0.0/16 out-interface-list=WAN action=masquerade

# Split-DNS: el nombre del ERP resuelve a la IP interna dentro de la empresa
/ip dns static add name=erp.lumencorp.local address=10.1.40.10

# QoS: control de ancho de banda por cliente con PCQ + fq-codel para latencia baja
/queue type add name=fq-codel-lowdelay kind=fq-codel
/queue type add name=pcq-download kind=pcq pcq-classifier=dst-address
/queue simple add name=qos-staff target=10.1.10.0/24 max-limit=200M/200M queue=fq-codel-lowdelay/pcq-download
```

**En Cisco IOS (ZBFW + NAT + Split-DNS en el DNS interno):**

```cisco
interface GigabitEthernet0/0
 zone-member security WAN
interface GigabitEthernet0/1
 zone-member security LAN
!
ip access-list extended WEB-ERP
 permit tcp any host 10.1.40.10 eq 8080
!
zone-pair security WAN-to-LAN source WAN destination LAN
 service-policy type inspect WAN-SELF
ip nat inside source static tcp 10.1.40.10 8080 interface GigabitEthernet0/0 8080
ip access-list extended HAIRPIN
 permit ip 10.1.0.0 0.0.255.255 host 10.1.40.10
ip nat source list HAIRPIN interface GigabitEthernet0/1 overload
```

---

### Fase 4 — Túnel Site-to-Site y OSPFv2 sobre el túnel

**Objetivo:** unir las dos sedes con cifrado y hacer que se vean las subredes solas vía OSPF.

**En MikroTik RouterOS v7 (WireGuard + OSPFv2 v7):**

```text
# Interfaz WireGuard y dirección de túnel
/interface wireguard add name=wg1 listen-port=51820 mtu=1420 private-key="<CLAVE_PRIVADA>"
/ip address add address=10.255.255.1/30 interface=wg1

# Peer hacia la Sucursal (clave pública del otro extremo)
/interface wireguard peers add interface=wg1 \
  public-key="<CLAVE_PUBLICA_SUCURSAL>" endpoint-address=198.51.100.2 endpoint-port=51820 \
  allowed-address=10.2.0.0/16,10.255.255.0/30 persistent-keepalive=25s

# OSPFv2 v7: instancia, área y plantilla de interfaz point-to-point
/routing ospf instance add name=default router-id=10.255.255.1
/routing ospf area add name=backbone area-id=0.0.0.0 instance=default
/routing ospf interface-template add interfaces=wg1 area=backbone type=ptp cost=10
/routing ospf interface-template add interfaces=vlan10 area=backbone passive=yes
```

**En Cisco IOS (IPsec IKEv2 VTI — equivalente funcional al WireGuard, ya que IOS no trae WireGuard nativo):**

```cisco
crypto ikev2 proposal PROP
 encryption aes-cbc-256
 integrity sha256
 group 14
crypto ikev2 policy POL
 proposal PROP
crypto ikev2 keyring KR
 peer SUCURSAL
  address 198.51.100.2
  pre-shared-key local LumenClaveLocal2026
  pre-shared-key remote LumenClaveRemota2026
crypto ikev2 profile PROF
 match identity remote address 198.51.100.2 255.255.255.255
 identity local address 203.0.113.2
 authentication remote pre-share
 authentication local pre-share
 keyring local KR
!
interface Tunnel1
 ip address 10.255.255.1 255.255.255.252
 ip mtu 1400
 ip ospf network point-to-point
 tunnel source GigabitEthernet0/0
 tunnel destination 198.51.100.2
 tunnel protection ipsec profile PROF
!
router ospf 1
 network 10.1.0.0 0.0.255.255 area 0
 network 10.255.255.0 0.0.0.3 area 0
```

**En Linux (FRRouting), igual que en el lab:**

```bash
ip link add wg1 type wireguard
ip addr add 10.255.255.1/30 dev wg1
wg set wg1 private-key /etc/wireguard/wg1.key peer <PUB_SUCURSAL> \
  endpoint 198.51.100.2:51820 allowed-ips 10.2.0.0/16,10.255.255.0/30 persistent-keepalive 25
ip link set mtu 1420 dev wg1 up
vtysh -c "conf t" -c "interface wg1" -c "ip ospf network point-to-point" -c "exit" \
      -c "router ospf" -c "network 10.1.0.0/16 area 0" -c "network 10.255.255.0/30 area 0"
```

**MSS Clamping (obligatorio en ambos extremos del túnel):**

```text
# MikroTik RouterOS v7
/ip firewall mangle add chain=forward protocol=tcp tcp-flags=syn action=change-mss new-mss=1360 tcp-mss=1361-65535
```

```cisco
! Cisco IOS: ajusta el MSS de los SYN que cruzan el túnel
ip tcp adjust-mss 1360
```

```bash
# Linux / iptables
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360
```

---

### Fase 5 — Observabilidad y Respaldo de la Configuración en Git

**Objetivo:** dejar la red monitoreada y versionada (nada "en producción" sin backup reproducible).

```text
# MikroTik: exportar el estado a texto plano (versionable en Git) y a binario (restauración)
/export show-sensitive file=lumencorp-sede1-$(date)
/system backup save name=lumencorp-sede1
/system logging action add name=syslog-remote target=remote remote=10.1.40.10 remote-port=514
/system logging add topics=critical,error action=syslog-remote
/snmp set enabled=yes
/snmp community add name=monitorAuthentication address=10.1.40.0/24
```

```cisco
! Cisco IOS: snapshot legible + envío de logs y SNMPv3
show running-config
show startup-config
logging host 10.1.40.10
snmp-server group MONITOR v3 auth
snmp-server user netops MONITOR v3 auth sha <ClaveAuth> priv aes 128 <ClavePriv>
copy running-config startup-config
```

```bash
# En Git: guardar los exports como código y commitear con Conventional Commits
mkdir -p net-backups && cp lumencorp-sede1-*.rsc net-backups/
git add net-backups && git commit -m "feat(net): snapshot de config Lumen Corp Sede 1"
```

---

## 🧯 Mitigación y Rollback

> ⚠️ **Salvavidas obligatorio en cada fase:** antes de aplicar cambios remotos activá **Safe Mode** (`Ctrl+X` en MikroTik) o `reload in 10` (en Cisco). Si perdés la conexión, el equipo vuelve solo al estado previo.

### 1. Verificar antes de tocar

```text
# Cisco IOS
show running-config interface GigabitEthernet1/0/1
copy running-config startup-config

# MikroTik RouterOS v7
/export file=pre-cambio
/interface bridge vlan print
```

### 2. Acción correctiva por fase (si la verificación falla)

- **Fase 1:** si una VLAN no pasa por el trunk, revisá que esté en `switchport trunk allowed vlan` / `tagged=` y que el PVID coincida en ambos extremos.
- **Fase 2:** si VRRP queda en `Split-Brain`, revisá que ambos routers reciban el multicast `224.0.0.18` (sin filtros en el switch).
- **Fase 3:** si el ERP no abre desde adentro, faltó el `srcnat`/hairpin. Si abre de más, agregá la regla explícita en `FORWARD`.
- **Fase 4:** si OSPF queda en `EXSTART`, la MTU de los extremos del túnel difiere (debe ser `1420` en ambos).
- **Fase 5:** si perdiste acceso, `Safe Mode` revierte; en Cisco, `reload in 10` y no confirmés.

### 3. Rollback inmediato

```text
# Cisco IOS: volver a la config guardada o reiniciar la ventana de seguridad
configure replace flash:pre-cambio.cfg force
! o si estás en una ventana:  reload cancel

# MikroTik RouterOS: importar el export previo o desactivar Safe Mode
/import file-name=pre-cambio.rsc
! Salir de Safe Mode con Ctrl+X cancela TODOS los cambios de la sesión
```

---

## ✅ Verificación final y Checklist de Aceptación (25 puntos)

Confirmá cada punto sobre la red real (o sobre el lab integrador):

- [ ] **1.** Todos los equipos ven su gateway y hacen ping a `10.1.x.1` / `10.2.x.1`.
- [ ] **2.** `show interfaces trunk` / `bridge vlan show` muestra `10,20,40,99,100,200` como `tagged` en el uplink.
- [ ] **3.** La Native VLAN del trunk es `99` (nunca la VLAN 1).
- [ ] **4.** El switch core es `Root Bridge` para todas las VLANs (`priority 4096`).
- [ ] **5.** `BPDU Guard` deja en `err-disabled` una boca de acceso que recibe BPDUs.
- [ ] **6.** El agregado `LACP` está `up` con los dos puertos `active` y sin pérdida de paquetes.
- [ ] **7.** `DHCP Snooping` confía solo en el uplink; un servidor DHCP falso en un access no reparte IPs.
- [ ] **8.** Cada VLAN hace ping a su propia subred y a la del router (Inter-VLAN por ROAS/SVI).
- [ ] **9.** `VRRP/HSRP` muestra un `Master/Active` y un `Backup/Standby` (sin Split-Brain).
- [ ] **10.** Al apagar la WAN principal, la ruta por defecto conmuta a la de respaldo en segundos.
- [ ] **11.** Al restaurar la WAN principal, la ruta prefiere volver a la primaria (preempt/distance).
- [ ] **12.** La política `FORWARD` por defecto es `DROP` (Zero-Trust).
- [ ] **13.** Un host de `Invitados (200)` **no** alcanza servidores ni gestión, pero sí navega a Internet.
- [ ] **14.** Un host de `Staff (10)` alcanza el ERP y navega, pero **no** administra switches (`99`).
- [ ] **15.** `DNAT`: desde "Internet" (`203.0.113.100`) abre `http://203.0.113.2:8080` y responde el ERP.
- [ ] **16.** `Hairpin NAT`: desde `Staff (10.1.10.50)` la **misma** URL pública abre el ERP.
- [ ] **17.** `Split-DNS`: `erp.lumencorp.local` resuelve a `10.1.40.10` dentro de la empresa.
- [ ] **18.** `QoS`: una descarga de un solo host de Staff no ahoga la latencia del resto (fq-codel/PCQ).
- [ ] **19.** El túnel site-to-site está `UP` (WireGuard `latest handshake` / IPsec `QM established`).
- [ ] **20.** `show ip ospf neighbor` en ambos extremos está en `Full/PointToPoint`.
- [ ] **21.** Se ve la ruta `10.2.0.0/16` en Sede 1 y `10.1.0.0/16` en Sede 2, aprendidas por OSPF.
- [ ] **22.** `ping` entre staff de Sede 1 y Sede 2 funciona de punta a punta por el túnel.
- [ ] **23.** `curl` a un sitio HTTPS pesado por el túnel **no** se cuelga (MSS Clamping activo).
- [ ] **24.** Regla `ICMPv6`/logs/SNMP: el router reporta a Syslog y responde SNMPv3 al servidor de monitoreo.
- [ ] **25.** El export `.rsc` / `running-config` de ambos routers está **commiteado en Git** y es restaurable.

---

## 🔗 Referencias

- [`inter-vlan-routing-roas-vs-svi`](../../guides/03-routing-l3/inter-vlan-routing-roas-vs-svi.md) — Fase 2: Inter-VLAN por Router-on-a-Stick y SVI
- [`vrrp-and-hsrp-gateway-redundancy`](../../guides/03-routing-l3/vrrp-and-hsrp-gateway-redundancy.md) — Fase 2: redundancia de gateway con WAN Tracking
- [`dual-wan-failover-and-load-balancing`](../../guides/03-routing-l3/dual-wan-failover-and-load-balancing.md) — Fase 2: rutas recursivas y failover de WAN
- [`stateful-firewall-and-zone-acls`](../../guides/04-firewalls-nat-vpn/stateful-firewall-and-zone-acls.md) — Fase 3: firewall Zero-Trust por zonas
- [`nat-masquerade-dnat-and-hairpin`](../../guides/04-firewalls-nat-vpn/nat-masquerade-dnat-and-hairpin.md) — Fase 3: DNAT, Hairpin NAT y Split-DNS
- [`wireguard-site-to-site-and-roadwarrior`](../../guides/04-firewalls-nat-vpn/wireguard-site-to-site-and-roadwarrior.md) — Fase 4: túnel site-to-site WireGuard
- [`ospf-single-and-multi-area`](../../guides/03-routing-l3/ospf-single-and-multi-area.md) — Fase 4: OSPFv2 sobre el túnel
- [`mikrotik-qos-simple-queues-and-queue-tree`](../../guides/06-mikrotik/mikrotik-qos-simple-queues-and-queue-tree.md) — Fase 3: QoS PCQ y fq-codel
- [`network-backups-export-and-git-versioning`](../../guides/08-operations/network-backups-export-and-git-versioning.md) — Fase 5: backups `.rsc` versionados en Git
- [`snmp-syslog-and-netflow-monitoring`](../../guides/08-operations/snmp-syslog-and-netflow-monitoring.md) — Fase 5: observabilidad
- [`ipv4-cidr-vlsm-and-special-ranges`](../../reference/ipv4-cidr-vlsm-and-special-ranges.md) — Plantilla de direccionamiento `10.<Sede>.<VLAN>.<Host>`
- [`docker-compose.integrative.yml`](../../labs/docker-compose.integrative.yml) — Laboratorio gemelo de 6 contenedores para practicar el proyecto completo
