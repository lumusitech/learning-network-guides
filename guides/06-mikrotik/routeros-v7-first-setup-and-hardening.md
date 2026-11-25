⬅️ [Volver a Guías](../README.md)

# MikroTik RouterOS v7: Puesta en Marcha desde Cero y Hardening — Guía práctica

**Dominio:** `06-mikrotik`
**Nivel:** 🟢 Básico
**Estándares:** `RouterOS v7+`, `CIS RouterOS Benchmark`, `RoMON`
**Concepto base:** [`how-to-think-like-network-engineer`](../../concepts/how-to-think-like-network-engineer.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Auditar versión, servicios expuestos, listas de interfaces, firewall y RoMON
/system resource print
/system routerboard print
/ip service print
/interface list member print
/ip firewall filter print stats
/tool romon print
```

---

## 📑 Índice

1. [¿Qué resuelve y cuándo usarlo?](#1--qué-resuelve-y-cuándo-usarlo)
2. [Topología de referencia](#2-️-topología-de-referencia)
3. [Configuración paso a paso por fabricante](#3-️-configuración-paso-a-paso-por-fabricante)
4. [Salida clave e interpretación de flags](#4--salida-clave-e-interpretación-de-flags)
5. [Uso en troubleshooting](#5--uso-en-troubleshooting)
6. [Mantenimiento, backup y rollback seguro](#6-️-mantenimiento-backup-y-rollback-seguro)
7. [Errores comunes en producción](#7-️-errores-comunes-en-producción)
8. [Buenas prácticas profesionales](#8--buenas-prácticas-profesionales)
9. [Referencias internas](#9--referencias-internas)

---

## 1. 🧠 ¿Qué resuelve y cuándo usarlo?

Cuando comprás un router MikroTik nuevo (como un `RB5009`, `CCR2004`, `hEX` o `hAP ax3`), lo peor que podés hacer para una instalación empresarial es construir sobre la configuración doméstica de fábrica (`192.168.88.1`, scripts ocultos `defconf`) o, en el otro extremo, vaciarlo con `no-defaults=yes` y conectarlo a Internet sin firewall.

Esta guía te entrega la **Plantilla Maestra de Puesta en Marcha de RouterOS v7 desde cero (`no-defaults=yes`)**:

1. **Puerto de Rescate Dedicado (`ether8-rescue`):** Un puerto físico aislado fuera del bridge para que siempre puedas conectarte si cometés un error configurando VLANs en el bridge principal.
2. **Identidad, NTP, DNS y Listas de Interfaces (`WAN`, `LAN`, `MGMT`).**
3. **Hardening completo** (usuarios, servicios, MAC-WinBox, Neighbor Discovery y RoMON cifrado).
4. **Firewall Stateful base (`INPUT` + `FORWARD` + `FastTrack` + `NAT` + `MSS Clamping`).**

> **🧠 Recordatorio del modelo mental:** Pensá en el **Puerto de Rescate (`ether8-rescue`)** como **la ventana trasera de emergencia del taller**: antes de ponerte a desarmar la cerradura de la puerta principal (el `bridge1` y sus VLANs), dejás el puerto 8 fuera del bridge con su propia IP fija (`10.255.255.1/30`). Si algo sale mal en el bridge, enchufás tu laptop en la boca 8 y entrás limpio sin tener que resetear el router de fábrica.

---

## 2. 🗺️ Topología de referencia

Arquitectura base sobre un router MikroTik de 8 puertos (ej. `RB5009` o `CCR2004`):

```text
   [Proveedor ISP Fibra]
            |
       (ether1-wan)
+---------------------------------------------------------------+
|                RTR-BORDE (MikroTik RouterOS v7)               |
|                                                               |
|  - Lista WAN:  ether1-wan (y pppoe-out1 si aplica)            |
|  - Bridge1:    ether2..ether7 + sfp-sfpplus1 (Trunks/LANs)    |
|  - Lista MGMT: vlan99-mgmt + ether8-rescue                    |
|  - RoMON:      Habilitado con secreto para saltar a switches  |
+---------------------------------------------------------------+
     || (ether2..7 y SFP+: Bridge1)            | (ether8-rescue: FUERA del bridge!)
     v                                         v
[Switches y VLANs de la Empresa]      [Boca de Rescate: 10.255.255.1/30]
```

| Interfaz / Lista | Función en la plantilla | Dirección IP |
|------------------|-------------------------|--------------|
| **`ether1-wan` (Lista `WAN`)** | Salida a Internet (DHCP Client / IP Fija / PPPoE) | Dinámica o Pública Fija |
| **`ether8-rescue` (Lista `MGMT`)** | **Puerto de Rescate Físico** (Fuera del `bridge1`!) | `10.255.255.1/30` (DHCP para 1 laptop: `.2`) |
| **`bridge1` (`ether2..7`, `sfp-sfpplus1`)** | Conmutador principal con `Bridge VLAN Filtering` | Lleva encima las interfaces `vlan10`, `vlan99`, etc. |
| **`vlan99-mgmt` (Lista `MGMT`)** | Interfaz de Administración en la VLAN 99 | `10.1.99.1/24` |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. Paso 0: Vaciar la configuración de fábrica y entrar por MAC desde WinBox

1. Conectá tu cable de red en el puerto **`ether8`** (nunca en `ether1`, ya que `ether1` suele bloquear entrada en la config de fábrica).
2. Abrí **WinBox** → pestaña **Neighbors** → hacé clic sobre la **Dirección MAC** del router (para que la conexión sea de Capa 2 y no se corte al borrar las IPs).
3. Ejecutá el vaciado limpio y reconectate por MAC cuando reinicie en 30 segundos:

```text
/system reset-configuration no-defaults=yes skip-backup=yes
```

---

### B. Script Maestro de Inicialización Limpia en RouterOS v7

```text
# =====================================================================
# 1. IDENTIDAD, RELOJ NTP Y ACTUALIZACIÓN DE ROUTERBOOT
# =====================================================================
/system identity set name="RTR-BORDE-SEDE1"
/system clock set time-zone-name=America/Argentina/Buenos_Aires
/system ntp client set enabled=yes servers=162.159.200.1,162.159.200.123,time.cloudflare.com
/system ntp server set enabled=yes manycast=yes
/system routerboard settings set auto-upgrade=yes

# =====================================================================
# 2. RENOMBRAR INTERFACES Y CREAR EL PUERTO DE RESCATE (ether8-rescue)
# =====================================================================
/interface ethernet
set [find default-name=ether1] name=ether1-wan comment="WAN_ISP_PRINCIPAL"
set [find default-name=ether8] name=ether8-rescue comment="PUERTO_RESCATE_LOCAL_NO_METER_AL_BRIDGE"

# Darle IP y DHCP chiquito (/30) a ether8-rescue para entrar siempre sin tocar el bridge:
/ip address add address=10.255.255.1/30 interface=ether8-rescue comment="IP Rescate Local"
/ip pool add name=pool-rescue ranges=10.255.255.2
/ip dhcp-server add name=dhcp-rescue interface=ether8-rescue address-pool=pool-rescue disabled=no
/ip dhcp-server network add address=10.255.255.0/30 gateway=10.255.255.1 dns-server=10.255.255.1

# =====================================================================
# 3. BRIDGE PRINCIPAL, VLAN DE GESTIÓN (99) Y VLAN DE USUARIOS (10)
# =====================================================================
/interface bridge
add name=bridge1 protocol-mode=rstp priority=0x1000 vlan-filtering=no comment="Bridge Principal"

/interface bridge port
add bridge=bridge1 interface=ether2 frame-types=admit-only-vlan-tagged ingress-filtering=yes trusted=yes comment="TRUNK_SW_CORE"
add bridge=bridge1 interface=ether3 pvid=10 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes edge=yes bpdu-guard=yes
add bridge=bridge1 interface=ether4 pvid=10 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes edge=yes bpdu-guard=yes
add bridge=bridge1 interface=ether5 pvid=99 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes edge=yes bpdu-guard=yes comment="BOCA_LOCAL_MGMT"

/interface bridge vlan
add bridge=bridge1 vlan-ids=10 tagged=bridge1,ether2 untagged=ether3,ether4 comment="VLAN 10 Staff"
add bridge=bridge1 vlan-ids=99 tagged=bridge1,ether2 untagged=ether5 comment="VLAN 99 Management"

/interface vlan
add interface=bridge1 name=vlan10-staff vlan-id=10
add interface=bridge1 name=vlan99-mgmt  vlan-id=99

/ip address
add address=10.1.10.1/24 interface=vlan10-staff comment="GW VLAN 10 Staff"
add address=10.1.99.1/24 interface=vlan99-mgmt  comment="GW VLAN 99 Mgmt"

# Activar filtrado de VLANs en el chip
/interface bridge set bridge1 vlan-filtering=yes

# =====================================================================
# 4. LISTAS DE INTERFACES (ZONAS: WAN, LAN, MGMT)
# =====================================================================
/interface list
add name=WAN  comment="Salidas a Internet"
add name=LAN  comment="Todas las redes internas"
add name=MGMT comment="Solo interfaces autorizadas a administrar el router"

/interface list member
add list=WAN  interface=ether1-wan
add list=LAN  interface=vlan10-staff
add list=LAN  interface=vlan99-mgmt
add list=LAN  interface=ether8-rescue
add list=MGMT interface=vlan99-mgmt
add list=MGMT interface=ether8-rescue

# =====================================================================
# 5. SALIDA WAN, DNS CACHÉ Y SERVIDORES DHCP
# =====================================================================
/ip dhcp-client add interface=ether1-wan add-default-route=yes use-peer-dns=no disabled=no
/ip dns set servers=1.1.1.1,8.8.8.8 allow-remote-requests=yes

/ip pool add name=pool-vlan10 ranges=10.1.10.100-10.1.10.240
/ip dhcp-server add name=dhcp-vlan10 interface=vlan10-staff address-pool=pool-vlan10 disabled=no
/ip dhcp-server network add address=10.1.10.0/24 gateway=10.1.10.1 dns-server=10.1.10.1 ntp-server=10.1.10.1

# =====================================================================
# 6. HARDENING DE SERVICIOS, NEIGHBORS, MAC-WINBOX Y ROMON
# =====================================================================
/ip service
disable telnet,ftp,www,api,api-ssl
set ssh    address=10.1.99.0/24,10.255.255.0/30 port=22
set winbox address=10.1.99.0/24,10.255.255.0/30 port=8291
/ip ssh set strong-crypto=yes

/ip neighbor discovery-settings set discover-interface-list=MGMT
/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=MGMT
/tool mac-server ping set enabled=no
/tool bandwidth-server set enabled=no

# Habilitar RoMON (para saltar por WinBox a otros MikroTik internos a través de este router!)
# pero PROHIBIR RoMON en la boca WAN:
/tool romon set enabled=yes secrets="SecretoRoMONCorporativo!2026"
/tool romon port set [find default=yes] forbid=no
/tool romon port add interface=ether1-wan forbid=yes comment="Bloquear RoMON en WAN"

# =====================================================================
# 7. FIREWALL STATEFUL (INPUT + FORWARD + FASTTRACK + NAT + MSS CLAMP)
# =====================================================================
/ip firewall filter
# --- CADENA INPUT (Proteger al propio Router) ---
add chain=input connection-state=established,related,untracked action=accept comment="IN-1: Aceptar establecidas"
add chain=input connection-state=invalid action=drop comment="IN-2: Descartar invalidas"
add chain=input protocol=icmp action=accept comment="IN-3: Permitir ICMP Ping/PMTUD"
add chain=input in-interface-list=MGMT protocol=tcp dst-port=22,8291 action=accept comment="IN-4: SSH y WinBox SOLO desde MGMT"
add chain=input in-interface-list=LAN protocol=udp dst-port=53,67,123 action=accept comment="IN-5: DNS, DHCP y NTP para LANs"
add chain=input in-interface-list=LAN protocol=tcp dst-port=53 action=accept comment="IN-6: DNS TCP para LANs"
add chain=input action=drop comment="IN-99: DROP TODO EL RESTO HACIA EL ROUTER"

# --- CADENA FORWARD (Tráfico que atraviesa el Router) ---
add chain=forward connection-state=established,related action=fasttrack-connection hw-offload=yes comment="FWD-1: FastTrack establecidas"
add chain=forward connection-state=established,related,untracked action=accept comment="FWD-2: Aceptar establecidas sin FastTrack"
add chain=forward connection-state=invalid action=drop comment="FWD-3: Descartar invalidas"
add chain=forward in-interface-list=MGMT out-interface-list=LAN action=accept comment="FWD-4: Admin llega a todas las VLANs"
add chain=forward in-interface-list=LAN out-interface-list=WAN action=accept comment="FWD-5: LANs salen a Internet"
add chain=forward connection-nat-state=dstnat action=accept comment="FWD-6: Permitir Port Forwardings DNAT"
add chain=forward action=drop comment="FWD-99: DROP TRAFICO NO AUTORIZADO ENTRE VLANS"

# --- NAT Y AJUSTE AUTOMÁTICO DE TCP MSS PARA PPPOE/VPN ---
/ip firewall nat
add chain=srcnat out-interface-list=WAN action=masquerade comment="NAT Salida a Internet"

/ip firewall mangle
add chain=forward protocol=tcp tcp-flags=syn action=change-mss new-mss=clamp-to-pmtu comment="Clamp TCP MSS al MTU del camino"
```

---

## 4. 🔑 Salida clave e interpretación de flags

### Verificación de Reglas y Contadores (`/ip firewall filter print stats`)

```text
[netops@RTR-BORDE-SEDE1] > /ip firewall filter print stats
Columns: CHAIN, ACTION, BYTES, PACKETS
# CHAIN    ACTION                BYTES  PACKETS
;;; IN-1: Aceptar establecidas
0 input    accept            14520100    84210
;;; IN-2: Descartar invalidas
1 input    drop                 12400      180
...
;;; IN-99: DROP TODO EL RESTO HACIA EL ROUTER
6 input    drop               8940200   142000
;;; FWD-1: FastTrack establecidas
7 forward  fasttrack-connection  945120400  812000
```

### Tabla de interpretación de salidas

| Regla / Indicador | Qué significa realmente | Estado sano vs Estado roto |
|-------------------|-------------------------|----------------------------|
| **Fila `IN-99` (`input drop`) sumando paquetes** | Son todos los bots de Internet que intentan escanear tu IP pública (SSH, Telnet, WinBox, DNS abierto) y rebotan contra el muro final de `INPUT` | ✅ Es normal que sume miles de paquetes por hora en una IP pública; demuestra que el firewall te está protegiendo |
| **Fila `FWD-1` (`fasttrack-connection`)** | Acelera los paquetes `ESTABLISHED` salteando la evaluación repetida de firewall en CPU | ✅ Mantiene el uso de CPU por debajo del `10%` incluso a `1 Gbps` de tráfico WAN |
| **`RoMON port: ether1-wan forbid=yes`** | Impide que el protocolo RoMON (Capa 2 `EtherType 0x88BF`) salga o entre por el cable del proveedor de Internet | ✅ Vital para que nadie desde la red del ISP pueda descubrir tu topología RoMON interna |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Activaste `allow-remote-requests=yes` en `/ip dns` para que tus PCs resuelvan nombres y al día siguiente tu enlace de subida a Internet está saturado al 100%

1. **Causa raíz (*Open DNS Resolver Amplification Attack*):**
   - Si ponés `allow-remote-requests=yes` en `/ip dns` **sin tener la regla final `chain=input action=drop` bloqueando a la WAN**, convertís a tu router en un **servidor DNS abierto a todo el planeta**. Los atacantes en Internet empiezan a usar tu IP pública para lanzar ataques DDoS de amplificación DNS.
2. **Verificación y blindaje:**
   - Jamás actives `allow-remote-requests=yes` sin verificar primero que en `/ip firewall filter` las reglas de `UDP/TCP 53` tengan **`in-interface-list=LAN`** (o `in-interface-list=!WAN`) y que al final de `input` esté activa la regla `action=drop`.

### Síntoma 2: ¿Qué es **RoMON** y cómo me salva cuando cambio la IP de un switch MikroTik interno?

1. **Cómo funciona RoMON (*Router Management Overlay Network*):**
   - RoMON arma una red de enrutamiento propia en Capa 2 entre todos tus equipos MikroTik usando identificadores MAC (`RoMON ID`), **totalmente independiente de las direcciones IP y de las VLANs**.
2. **Cómo usarlo en WinBox:**
   - En WinBox, en vez de hacer clic en `Connect`, hacés clic en **`Connect To RoMON`** hacia tu router de borde (`10.1.99.1`).
   - Se abre la pestaña **RoMON Neighbors** mostrando todos los switches y APs MikroTik que están detrás del router (incluso si están a 4 switches de distancia o si perdieron su dirección IP por un error de configuración) y podés abrirles WinBox a través del túnel RoMON.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Exportar tu propia plantilla base (`golden-template.rsc`):**
  - Una vez que dejaste este router configurado y probado, ejecutá `/export show-sensitive file=golden-template-v7` y guardalo en tu repositorio Git para estandarizar todas tus sucursales futuras en 5 minutos.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Meter los 8 puertos (`ether1` al `ether8`) adentro del `bridge1` al empezar a configurar VLANs:** Si metés absolutamente todos los puertos al bridge y cometés un error en `/interface bridge vlan`, **ninguna boca física te dejará entrar**. Dejar siempre el último puerto (`ether8-rescue`) fuera del bridge con un DHCP `/30` propio es el seguro de vida de todo ingeniero MikroTik.
- **❌ Si tu proveedor es PPPoE (`pppoe-out1`), olvidar agregar la interfaz `pppoe-out1` a la lista `WAN`:** Si creás un cliente PPPoE sobre `ether1-wan`, la interfaz por donde realmente sale Internet pasa a ser **`pppoe-out1`**, no `ether1-wan`. Si no ejecutás `/interface list member add list=WAN interface=pppoe-out1`, ni el `masquerade` ni el firewall de `WAN` actuarán sobre el PPPoE.

---

## 8. ✅ Buenas prácticas profesionales

- **Usar siempre `/interface list` (`WAN`, `LAN`, `MGMT`) en las reglas de firewall en lugar de nombres de interfaces sueltas (`ether1`):** Si mañana agregás un segundo proveedor de Internet en `ether2-wan2` o un cliente `pppoe-out1`, solo agregás esa interfaz a la lista `WAN` en un único lugar y **todas tus reglas de Firewall y NAT funcionan automáticamente sin tocar ni una sola regla**.

---

## 9. 🔗 Referencias internas

- [`mikrotik-bridge-vlan-filtering-deep-dive`](mikrotik-bridge-vlan-filtering-deep-dive.md) — El paso siguiente: entender a fondo la arquitectura del Switch Chip y la CPU (`bridge1`) en MikroTik
- [`ssh-hardening-and-management-plane`](../01-fundamentals/ssh-hardening-and-management-plane.md) — Detalles adicionales de seguridad en llaves SSH
- [`stateful-firewalls-and-zone-segmentation`](../../concepts/stateful-firewalls-and-zone-segmentation.md) — Explicación conceptual completa de las cadenas `INPUT` y `FORWARD`
