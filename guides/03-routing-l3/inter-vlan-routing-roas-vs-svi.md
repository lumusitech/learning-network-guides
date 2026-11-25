⬅️ [Volver a Guías](../README.md)

# Inter-VLAN Routing: Router-on-a-Stick (ROAS) vs Switch Capa 3 (SVI) — Guía práctica multi-vendor

**Dominio:** `03-routing-l3`
**Nivel:** 🟡 Intermedio
**Estándares:** `IEEE 802.1Q`, `IPv4 Forwarding (RFC 1812)`, `ASIC L3HW Offloading`
**Concepto base:** [`routing-fundamentals-static-and-dynamic`](../../concepts/routing-fundamentals-static-and-dynamic.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Ver interfaces SVI / Subinterfaces 802.1Q activas, tabla de rutas y aceleración CEF
show ip interface brief | include Vlan|Gi
show ip route connected
show ip cef

# MikroTik RouterOS v7: Ver interfaces VLAN, IPs asignadas y estado de L3 Hardware Offloading (H)
/interface vlan print
/ip address print
/ip route print where connect
/interface ethernet switch print

# Aruba / HP Capa 3: Verificar si ip routing está activo y estado de las interfaces VLAN
show ip
show ip route

# Linux: Verificar subinterfaces VLAN, forwarding del kernel y rutas locales
ip -br addr show
sysctl net.ipv4.ip_forward
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

Cuando dividís un switch en VLANs (`VLAN 10 Staff` y `VLAN 40 Servidores`), quedan aisladas en Capa 2. Para que una PC de la VLAN 10 pueda consultar la base de datos de un servidor en la VLAN 40, el paquete tiene que subir a **Capa 3 (un Router o Switch Capa 3)**.

Existen **dos formas** de construir este puente de Capa 3:

1. **Arquitectura A — *Router-on-a-Stick (ROAS)*:** El switch actúa solo en Capa 2 y sube todas las VLANs por un cable Trunk hacia el **Router / Firewall**, donde viven los Default Gateways (`10.1.10.1` y `10.1.40.1`). **Ventaja:** todo el tráfico entre VLANs pasa por el Firewall Stateful. **Desventaja:** el tráfico interno sube y baja por el mismo cable Trunk y usa la CPU del router.
2. **Arquitectura B — *Switch Capa 3 (SVIs / L3HW)*:** Los Default Gateways (`10.1.10.1` y `10.1.40.1`) viven **adentro del propio Switch Core Capa 3** (que enruta en su chip ASIC a `10 Gbps / 100 Gbps`), y el switch se conecta al Router de borde por una sola subred de tránsito `/30` (`10.1.255.0/30`). **Ventaja:** máxima velocidad entre usuarios y servidores locales sin tocar el router.

> **🧠 Recordatorio del modelo mental:** Pensá en **ROAS** como **un edificio donde para ir de una oficina del Piso 2 a otra oficina del mismo Piso 2 tenés que subir en ascensor hasta la oficina del Director en la terraza (el Firewall) para que te firme el pase**. Pensá en un **Switch Capa 3 (SVI)** como **poner un guardia en el mismo pasillo del Piso 2** que te deja cruzar de una sala a la otra a velocidad de carrera, y solo usás el ascensor a la terraza cuando tenés que salir a la calle (Internet).

---

## 2. 🗺️ Topología de referencia

Mostraremos cómo implementar ambas arquitecturas para enrutar entre la `VLAN 10 (10.1.10.0/24)` y la `VLAN 40 (10.1.40.0/24)`:

```text
OPCIÓN 1: ROUTER-ON-A-STICK (ROAS)               OPCIÓN 2: SWITCH CAPA 3 (SVIs + Enlace /30 al Router)
+-----------------------------------+            +-----------------------------------+
|            RTR-BORDE              |            |            RTR-BORDE              |
|  Subinterfaz VLAN 10: 10.1.10.1   |            |  IP Tránsito: 10.1.255.1/30       |
|  Subinterfaz VLAN 40: 10.1.40.1   |            |  Ruta a 10.1.0.0/16 via .255.2    |
+-----------------------------------+            +-----------------------------------+
                 ||                                                |
                 || Trunk 802.1Q (VLANs 10, 40)                    | Enlace L3 Puro (10.1.255.0/30)
                 v                                                 v
+-----------------------------------+            +-----------------------------------+
|          SW-CORE (Capa 2)         |            |     SW-CORE (Switch Capa 3!)      |
+-----------------------------------+            |  IP Tránsito: 10.1.255.2/30       |
       /                     \                   |  SVI VLAN 10: 10.1.10.1/24        |
  [PC VLAN 10]         [Servidor VLAN 40]        |  SVI VLAN 40: 10.1.40.1/24        |
  GW: 10.1.10.1        GW: 10.1.40.1             +-----------------------------------+
```

| Parámetro | En Opción 1 (ROAS) | En Opción 2 (Switch Capa 3 con SVIs) |
|-----------|--------------------|--------------------------------------|
| **Gateway de VLAN 10 (`10.1.10.1/24`)** | Vive en `RTR-BORDE` (`Gi0/0.10` / `vlan10`) | Vive en `SW-CORE` (`interface Vlan10` / `vlan10` con L3HW) |
| **Gateway de VLAN 40 (`10.1.40.1/24`)** | Vive en `RTR-BORDE` (`Gi0/0.40` / `vlan40`) | Vive en `SW-CORE` (`interface Vlan40` / `vlan40` con L3HW) |
| **Enlace entre Switch y Router** | Trunk Capa 2 (`Tagged 10, 40`) | Enlace Capa 3 `/30` (`10.1.255.1/30 ↔ 10.1.255.2/30`) |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. Cisco IOS (Opción 1: Router-on-a-Stick en un Router ISR vs Opción 2: SVIs en un Switch Catalyst L3)

#### Opción 1 en Router Cisco (ROAS con subinterfaces `dot1Q`)

```cisco
configure terminal

! 1. Encender la interfaz física padre (SIN ponerle dirección IP a la interfaz física!)
interface GigabitEthernet0/0
 description TRUNK_ROAS_HACIA_SW_CORE
 no ip address
 no shutdown
exit

! 2. Crear una subinterfaz por cada VLAN con 'encapsulation dot1Q <VLAN_ID>'
interface GigabitEthernet0/0.10
 description GATEWAY_VLAN10_STAFF
 encapsulation dot1Q 10
 ip address 10.1.10.1 255.255.255.0
exit

interface GigabitEthernet0/0.40
 description GATEWAY_VLAN40_SERVIDORES
 encapsulation dot1Q 40
 ip address 10.1.40.1 255.255.255.0
exit

end
write memory
```

#### Opción 2 en Switch Cisco Capa 3 (`SVIs` + `ip routing` + puerto enrutado `no switchport`)

```cisco
configure terminal

! 1. PASO OBLIGATORIO: Habilitar el motor de enrutamiento Capa 3 del switch
ip routing

! 2. Asegurar que las VLANs existan en la base de datos de Capa 2 (si no existen, la SVI queda DOWN!)
vlan 10
 name STAFF
vlan 40
 name SERVIDORES
exit

! 3. Crear las interfaces virtuales SVI (Default Gateways locales en el chip ASIC)
interface Vlan10
 description SVI_GW_STAFF
 ip address 10.1.10.1 255.255.255.0
 no shutdown
exit

interface Vlan40
 description SVI_GW_SERVIDORES
 ip address 10.1.40.1 255.255.255.0
 no shutdown
exit

! 4. Convertir el Puerto 1 (que sube al Router de borde) en un puerto Capa 3 puro ('no switchport')
interface GigabitEthernet1/0/1
 description ENLACE_L3_HACIA_RTR_BORDE
 no switchport
 ip address 10.1.255.2 255.255.255.252
 no shutdown
exit

! 5. Apuntar la ruta por defecto del Switch L3 hacia el Router de borde (.1)
ip route 0.0.0.0 0.0.0.0 10.1.255.1

end
write memory
```

> *(Nota importante en la Opción 2: En el `RTR-BORDE` debés agregar la ruta de retorno hacia todas las VLANs del switch: `ip route 10.1.0.0 255.255.0.0 10.1.255.2`).*

---

### B. MikroTik RouterOS v7 (ROAS en Router vs Switch L3 `CRS3xx/CRS5xx` con `L3HW Offloading`)

```text
# 1. Crear las interfaces VLAN sobre el bridge1 (donde ya están declaradas con bridge1 en tagged=):
/interface vlan
add interface=bridge1 name=vlan10-staff   vlan-id=10
add interface=bridge1 name=vlan40-servers vlan-id=40

# 2. Asignar las IPs de Default Gateway a cada interfaz VLAN:
/ip address
add address=10.1.10.1/24 interface=vlan10-staff   comment="GW VLAN 10"
add address=10.1.40.1/24 interface=vlan40-servers comment="GW VLAN 40"

#    ¡Listo! En MikroTik el enrutamiento IP está activo siempre por defecto:
#    al crear ambas IPs, se crean automáticamente las rutas conectadas (DAC) y el equipo ya enruta entre ellas.

# 3. (EXCLUSIVO PARA SWITCHES MIKROTIK CRS3xx / CRS5xx actuando como Switch Capa 3):
#    Activar el enrutamiento directamente adentro del chip Marvell Prestera a velocidad de cable (10G/40G/100G):
/interface ethernet switch
set switch1 l3-hw-offloading=yes
```

### C. Switches Gestionables Capa 3 (Aruba / HP ProCurve)

```text
configure
# 1. Activar el enrutamiento entre VLANs
ip routing

# 2. Asignar las IPs de Gateway a cada VLAN y la ruta de salida hacia el firewall de borde
vlan 10
   ip address 10.1.10.1 255.255.255.0
   exit
vlan 40
   ip address 10.1.40.1 255.255.255.0
   exit
vlan 255
   name "TRANSITO_FIREWALL"
   untagged 1
   ip address 10.1.255.2 255.255.255.252
   exit

ip route 0.0.0.0 0.0.0.0 10.1.255.1
write memory
```

### D. Linux (`iproute2` — Router-on-a-Stick sobre `eth0`)

```bash
# 1. Activar el reenvío de paquetes IPv4 en el kernel de forma inmediata y persistente
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-ip-forward.conf

# 2. Crear las subinterfaces 802.1Q y asignarles sus IPs de Gateway
sudo ip link set dev eth0 up
sudo ip link add link eth0 name eth0.10 type vlan id 10
sudo ip addr add 10.1.10.1/24 dev eth0.10
sudo ip link set dev eth0.10 up

sudo ip link add link eth0 name eth0.40 type vlan id 40
sudo ip addr add 10.1.40.1/24 dev eth0.40
sudo ip link set dev eth0.40 up
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En Cisco Switch L3 (`show ip interface brief` y `show ip route`)

```text
SW-CORE# show ip interface brief | include Vlan|Gi1/0/1
Interface              IP-Address      OK? Method Status                Protocol
GigabitEthernet1/0/1   10.1.255.2      YES manual up                    up
Vlan10                 10.1.10.1       YES manual up                    up
Vlan40                 10.1.40.1       YES manual up                    up

SW-CORE# show ip route
C        10.1.10.0/24 is directly connected, Vlan10
L        10.1.10.1/32 is directly connected, Vlan10
C        10.1.40.0/24 is directly connected, Vlan40
L        10.1.40.1/32 is directly connected, Vlan40
S*       0.0.0.0/0 [1/0] via 10.1.255.1
```

### En MikroTik (`/ip route print`)

```text
[netops@SW-CORE] > /ip route print
Flags: D - DYNAMIC; A - ACTIVE; c - CONNECT, s - STATIC; H - HW-OFFLOADED
Columns: DST-ADDRESS, GATEWAY, DISTANCE
#      DST-ADDRESS     GATEWAY         DISTANCE
0  AsH 0.0.0.0/0       10.1.255.1             1
  DAcH 10.1.10.0/24    vlan10-staff           0
  DAcH 10.1.40.0/24    vlan40-servers         0
  DAcH 10.1.255.0/30   ether1                 0
```

### Tabla de interpretación de columnas y flags

| Columna / Flag | Fabricante | Qué significa realmente | Estado sano vs Estado roto |
|----------------|------------|-------------------------|----------------------------|
| **`Status: up` / `Protocol: up` en `Vlan10`** | Cisco IOS | La SVI está encendida (`Status up`) y **existe al menos 1 puerto físico activo en esa VLAN** (`Protocol up`) | ❌ Si dice `Status: up / Protocol: down`, la SVI no enruta (ver troubleshooting abajo) |
| **`DAcH` (`H = HW-OFFLOADED`)** | MikroTik CRS3xx | La ruta está instalada directamente en la memoria TCAM del **chip ASIC del switch** | ✅ Con `H`, el switch enruta entre VLANs a `10G/40G/100G` con `0%` de uso de CPU |
| **`C` (Connected `/24`) + `L` (Local `/32`)** | Cisco IOS | `C` es la subred completa conectada a la interfaz; `L` es la dirección IP propia del router | Ambas aparecen automáticamente apenas la interfaz pasa a `up/up` |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: En un Switch Cisco creaste `interface Vlan40`, pusiste `ip address 10.1.40.1 255.255.255.0` y `no shutdown`, pero queda en `Vlan40 is up, line protocol is down`

1. **Las 3 condiciones obligatorias para que una SVI (`interface VlanX`) levante `line protocol is up` en Cisco:**
   1. La VLAN `40` debe existir en la base de datos de Capa 2 (`show vlan brief` → si no está, crearla con el comando global `vlan 40`).
   2. Debe existir **al menos un puerto físico en `Link UP`** asignado a la VLAN 40 (ya sea como `access vlan 40` o como un `trunk` que permita la VLAN 40).
   3. Ese puerto físico debe estar en estado **`Forwarding` de Spanning Tree** (no bloqueado).
2. **Corrección:** Verificá `show vlan id 40` y `show interfaces trunk`. Apenas un puerto con la VLAN 40 tenga cable conectado y activo, `Vlan40` pasará a `up / up` instantáneamente.

### Síntoma 2: En un Switch Capa 3 (`SW-CORE`) las PCs de la VLAN 10 llegan a los Servidores de la VLAN 40 a `1 Gbps`, pero ninguna PC de la VLAN 10 ni 40 puede salir a Internet a través del `RTR-BORDE`

1. **Causa raíz (99% de las veces):** Configuraste `0.0.0.0/0 via 10.1.255.1` en el `SW-CORE`, pero **en el `RTR-BORDE` te olvidaste de crear la ruta estática de regreso** hacia las redes que ahora viven detrás del `SW-CORE` (`10.1.10.0/24` y `10.1.40.0/24` via `10.1.255.2`), o te olvidaste de incluir a `10.1.0.0/16` en el NAT de salida a Internet del `RTR-BORDE`.
2. **Corrección en `RTR-BORDE`:** Agregar `/ip route add dst-address=10.1.0.0/16 gateway=10.1.255.2`.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **En Switches MikroTik con `l3-hw-offloading=yes`:**
  - Recordá que las reglas de Firewall (`/ip firewall filter` y `nat`) de RouterOS viven en la **CPU**. Si querés que el chip ASIC del switch CRS3xx enrute a `10 Gbps` entre las VLANs internas pero querés usar el Firewall/NAT de la CPU para el puerto WAN, poné `l3-hw-offloading=no` **únicamente en el puerto WAN** (`/interface ethernet switch port set ether1-wan l3-hw-offloading=no`).

---

## 7. ⚠️ Errores comunes en producción

- **❌ En un Switch Capa 3 Cisco o Aruba, usar `ip default-gateway 10.1.255.1` en lugar de `ip route 0.0.0.0 0.0.0.0 10.1.255.1`:**
  - ¡Atención a esta diferencia clásica! El comando `ip default-gateway` en Cisco **SOLO funciona cuando el switch está en modo Capa 2 puro (`no ip routing`)**.
  - En el instante en que ejecutás **`ip routing`** para convertirlo en Switch Capa 3, el switch ignora `ip default-gateway` y pasa a usar su tabla de enrutamiento: tenés que configurar sí o sí **`ip route 0.0.0.0 0.0.0.0 10.1.255.1`**.
- **❌ En Router-on-a-Stick (ROAS), olvidar que si tenés un servidor DHCP central en la VLAN 40, las demás subinterfaces VLAN (`Gi0/0.10`, `vlan10`) necesitan `ip helper-address 10.1.40.10` (`/ip dhcp-relay`)** para que los pedidos DHCP crucen de la VLAN 10 al servidor de la VLAN 40.

---

## 8. ✅ Buenas prácticas profesionales

- **Diseño híbrido recomendado en empresas medianas:**
  - Dejá en el **Switch Core Capa 3 (SVIs)** las VLANs de alto tráfico interno de confianza (ej. Servidores de Virtualización ↔ Almacenamiento / Backup) para que vuelen a `10 Gbps / 25 Gbps` en el chip ASIC.
  - Y subí en Capa 2 (como **ROAS**) hasta el **Firewall de Borde** las VLANs que exigen inspección de seguridad estricta (como `WiFi Invitados`, `DMZ` y `Cámaras CCTV / IoT`).

---

## 9. 🔗 Referencias internas

- [`routing-fundamentals-static-and-dynamic`](../../concepts/routing-fundamentals-static-and-dynamic.md) — Comparación conceptual detallada entre ROAS y Switch Capa 3 (SVIs)
- [`vlans-8021q-access-trunk-pvid`](../02-switching-l2/vlans-8021q-access-trunk-pvid.md) — Configuración de los enlaces Trunk de Capa 2 que alimentan al Router-on-a-Stick
- [`mikrotik-bridge-vlan-filtering-deep-dive`](../06-mikrotik/mikrotik-bridge-vlan-filtering-deep-dive.md) — Por qué en MikroTik hay que incluir `bridge1` en `tagged=` cuando el equipo enruta esa VLAN
