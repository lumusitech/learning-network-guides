⬅️ [Volver a Guías](../README.md)

# Dual-WAN: Failover Automático con Rutas Recursivas y Balanceo de Carga (PCC) — Guía práctica multi-vendor

**Dominio:** `03-routing-l3`
**Nivel:** 🔴 Avanzado
**Estándares:** `Recursive Routing`, `Cisco IP SLA + PBR`, `MikroTik PCC (Per Connection Classifier)`, `Linux ip rule`
**Concepto base:** [`routing-fundamentals-static-and-dynamic`](../../concepts/routing-fundamentals-static-and-dynamic.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Ver estado de las rutas recursivas WAN1/WAN2 (flags As vs Is) y tablas de ruteo PCC
/ip route print detail where dst-address=0.0.0.0/0 or scope=10
/routing table print
/ip firewall mangle print stats

# Cisco IOS: Ver estado de las sondas de salud IP SLA hacia Internet y objetos Track
show ip sla statistics
show track
show ip route 0.0.0.0

# Linux: Ver reglas de Policy-Based Routing (PBR) y tablas de cada proveedor
ip rule show
ip route show table all
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

Cuando una empresa contrata un **segundo proveedor de Internet (`WAN 2`)** y lo conecta al mismo router principal, el error número 1 es poner simplemente `check-gateway=ping` apuntando a la IP local del módem del proveedor (`192.168.1.1`).

**¿Por qué eso falla en el 95% de los cortes reales de Internet (*"El Problema del ISP Zombie"*)?**
Porque cuando se corta la fibra del proveedor en la calle, **el módem que está adentro de tu rack sigue encendido y sigue respondiendo al ping en `192.168.1.1`**. Tu router cree que el ISP 1 sigue sano y jamás cambia al ISP 2.

En esta guía implementamos las **dos arquitecturas profesionales de Dual-WAN**:

1. **Failover Puro Inteligente (*Rutas Recursivas* / *IP SLA*):** El router vigila un destino real en Internet (`1.1.1.1` / `9.9.9.9`) obligando a que esa sonda salga exclusivamente por el `ISP 1`, y vigila `8.8.8.8` por el `ISP 2`. Si el `ISP 1` pierde salida real a Internet (aunque su módem siga encendido), conmuta al `ISP 2` en 10 segundos sin scripts frágiles.
2. **Balanceo de Carga Activo-Activo sin romper Home Banking ni HTTPS (*MikroTik PCC — Per Connection Classifier*):** Usa **ambos proveedores al mismo tiempo** asegurando que todas las conexiones de un mismo cliente hacia un mismo servidor salgan siempre por la misma IP pública.

> **🧠 Recordatorio del modelo mental:** Pensá en el **Failover con Ruta Recursiva** como **no conformarte con mirar si el teléfono de la oficina tiene tono (`ping al módem 192.168.1.1`), sino llamar cada 10 segundos a un número real en otra ciudad (`ping a 1.1.1.1 a través del módem 1`)**: si el módem tiene luz verde pero la llamada a afuera no sale, sabés que la línea externa murió y pasás todas las llamadas por la línea 2.

---

## 2. 🗺️ Topología de referencia

Un router con dos proveedores de Internet independientes (`WAN 1` y `WAN 2`):

```text
   [ISP 1: Fibra Principal (300 Mbps)]             [ISP 2: Cable/Starlink Backup (150 Mbps)]
   Gateway ISP 1: 203.0.113.1                      Gateway ISP 2: 198.51.100.1
   Vigila Host Canario 1: 1.1.1.1/32               Vigila Host Canario 2: 8.8.8.8/32
                  \                                               /
           (ether1-wan1)                                   (ether2-wan2)
            +---------------------------------------------------------+
            |                       RTR-BORDE                         |
            |  - Lista WAN = ether1-wan1 + ether2-wan2                |
            |  - Masquerade en out-interface-list=WAN                 |
            +---------------------------------------------------------+
                                        ||
                                        v
                          [Redes LAN Internas: 10.1.0.0/16]
```

| Parámetro Dual-WAN | Proveedor 1 (`ether1-wan1`) | Proveedor 2 (`ether2-wan2`) |
|--------------------|:---------------------------:|:---------------------------:|
| **IP del Gateway del ISP** | `203.0.113.1` | `198.51.100.1` |
| **Host "Canario" en Internet que vigila** | **`1.1.1.1/32`** (Cloudflare DNS) | **`8.8.8.8/32`** (Google DNS) |
| **Distancia Administrativa en Tabla `main`** | **`distance = 1`** (Titular) | **`distance = 2`** (Respaldo) |
| **Tabla de Ruteo Dedicada (para PCC)** | `to-wan1` | `to-wan2` |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. MikroTik RouterOS v7 — Parte 1: Failover Automático Perfecto con **Rutas Recursivas** (Sin Scripts!)

> **💡 Cómo funciona la magia de las Rutas Recursivas en RouterOS v7 (`scope` y `target-scope`):**
>
> 1. Creamos una ruta "Semilla" hacia `1.1.1.1/32` que dice: *"Para llegar a `1.1.1.1`, andá por el módem del ISP 1 (`203.0.113.1`)"*, y le ponemos **`scope=10` y `target-scope=10`**.
> 2. Luego creamos la ruta por defecto `0.0.0.0/0` diciendo: *"Mi gateway para todo Internet es **`1.1.1.1`** (con `check-gateway=ping`, `scope=30` y **`target-scope=11`**)"*.
> 3. Como `target-scope=11` es mayor o igual al `scope=10` de la ruta semilla, RouterOS resuelve recursivamente `1.1.1.1` a través del módem 1 y le hace ping cada 10 segundos a `1.1.1.1`. Si se corta la fibra del ISP 1 en la calle, `1.1.1.1` deja de responder y la ruta `0.0.0.0/0` del ISP 1 se apaga sola!

```text
# 1. Asegurar que AMBAS interfaces WAN estén en la lista WAN (para que el Firewall y el Masquerade cubran a las dos!):
/interface list member
add list=WAN interface=ether1-wan1
add list=WAN interface=ether2-wan2

# 2. (Si tus proveedores te dan IP por DHCP Client, desactivar 'add-default-route=no' en ambos DHCP Clients
#    para que no pisen nuestras rutas recursivas inteligentes, y anotar sus gateways):

# 3. CREAR LAS RUTAS SEMILLA ("Canarios" en Internet con scope=10 y target-scope=10):
/ip route
add dst-address=1.1.1.1/32 gateway=203.0.113.1 scope=10 target-scope=10 comment="Semilla Canario ISP 1 (Cloudflare)"
add dst-address=8.8.8.8/32 gateway=198.51.100.1 scope=10 target-scope=10 comment="Semilla Canario ISP 2 (Google)"

# 4. CREAR LAS RUTAS POR DEFECTO RECURSIVAS (Con check-gateway=ping y target-scope=11!):
/ip route
add dst-address=0.0.0.0/0 gateway=1.1.1.1 distance=1 scope=30 target-scope=11 check-gateway=ping comment="WAN 1 Principal (Recursiva via 1.1.1.1)"
add dst-address=0.0.0.0/0 gateway=8.8.8.8 distance=2 scope=30 target-scope=11 check-gateway=ping comment="WAN 2 Backup (Recursiva via 8.8.8.8)"
```

---

### B. MikroTik RouterOS v7 — Parte 2 (Opcional): Sumar **Balanceo de Carga PCC** (*Per Connection Classifier*)

Si además del failover querés **usar los megas de ambos proveedores al mismo tiempo** (ej. repartir 50/50 o 2/3 para el ISP 1 y 1/3 para el ISP 2), agregamos **tablas de ruteo dedicadas** y reglas **Mangle PCC**:

```text
# 1. Crear las dos tablas de ruteo dedicadas con fib en RouterOS v7:
/routing table
add name=to-wan1 fib
add name=to-wan2 fib

# 2. Agregar las rutas recursivas adentro de cada tabla dedicada:
/ip route
add dst-address=0.0.0.0/0 gateway=1.1.1.1 routing-table=to-wan1 scope=30 target-scope=11 check-gateway=ping comment="Tabla PCC WAN1"
add dst-address=0.0.0.0/0 gateway=8.8.8.8 routing-table=to-wan2 scope=30 target-scope=11 check-gateway=ping comment="Tabla PCC WAN2"

# 3. Crear lista de redes internas (RFC 1918) para que el tráfico ENTRE VLANs internas NUNCA sea mandado a Internet por PCC!
/ip firewall address-list
add list=REDES-INTERNAS address=10.0.0.0/8
add list=REDES-INTERNAS address=172.16.0.0/12
add list=REDES-INTERNAS address=192.168.0.0/16

# 4. Reglas Mangle de PCC:
#    Usamos clasificador 'src-address-and-dst-address' (sin puertos!) para que si una PC abre 5 conexiones HTTPS
#    contra la página del mismo Banco, las 5 salgan SIEMPRE por la misma IP pública y el Banco no cierre la sesión!
/ip firewall mangle
# 4.1 No tocar el tráfico que va de una VLAN interna a otra VLAN interna:
add chain=prerouting src-address-list=REDES-INTERNAS dst-address-list=REDES-INTERNAS action=accept comment="0. Eximir trafico LAN-a-LAN del PCC"

# 4.2 Si entra una conexión desde afuera por WAN1 o WAN2, marcarla para que el router conteste por esa misma WAN:
add chain=prerouting in-interface=ether1-wan1 connection-mark=no-mark action=mark-connection new-connection-mark=conn-wan1 passthrough=yes
add chain=prerouting in-interface=ether2-wan2 connection-mark=no-mark action=mark-connection new-connection-mark=conn-wan2 passthrough=yes

# 4.3 Dividir las conexiones nuevas salientes de la LAN con PCC (2/0 va a WAN1, 2/1 va a WAN2):
add chain=prerouting in-interface-list=LAN dst-address-type=!local connection-mark=no-mark \
    per-connection-classifier=src-address-and-dst-address:2/0 action=mark-connection new-connection-mark=conn-wan1 passthrough=yes comment="PCC Mitad 1 -> WAN1"
add chain=prerouting in-interface-list=LAN dst-address-type=!local connection-mark=no-mark \
    per-connection-classifier=src-address-and-dst-address:2/1 action=mark-connection new-connection-mark=conn-wan2 passthrough=yes comment="PCC Mitad 2 -> WAN2"

# 4.4 Traducir la marca de conexión en marca de ruteo hacia su tabla correspondiente:
add chain=prerouting in-interface-list=LAN connection-mark=conn-wan1 action=mark-routing new-routing-mark=to-wan1 passthrough=no
add chain=prerouting in-interface-list=LAN connection-mark=conn-wan2 action=mark-routing new-routing-mark=to-wan2 passthrough=no
add chain=output connection-mark=conn-wan1 action=mark-routing new-routing-mark=to-wan1 passthrough=no
add chain=output connection-mark=conn-wan2 action=mark-routing new-routing-mark=to-wan2 passthrough=no
```

> *(Nota: Cuando usás `mark-routing` con Mangle PCC, debés desactivar la regla de `fasttrack-connection` en `/ip firewall filter` para que los paquetes no salteen la tabla `mangle`).*

---

### C. Cisco IOS (Failover Dual-WAN con `IP SLA` + `Track` + Limpieza de NAT)

```cisco
configure terminal

! 1. Forzar que el ping hacia 1.1.1.1 salga siempre por el ISP 1 (203.0.113.1)
ip route 1.1.1.1 255.255.255.255 GigabitEthernet0/0 203.0.113.1 name SEMILLA_ISP1

! 2. Configurar IP SLA 1 haciendo ping cada 5 segundos a 1.1.1.1 y atarlo al Track 1
ip sla 1
 icmp-echo 1.1.1.1 source-interface GigabitEthernet0/0
 timeout 2000
 frequency 5
ip sla schedule 1 life forever start-time now

track 1 ip sla 1 reachability
 delay down 10 up 15
exit

! 3. Rutas por defecto: WAN 1 con AD=1 atada al Track 1, y WAN 2 flotante con AD=10
ip route 0.0.0.0 0.0.0.0 203.0.113.1 1 track 1 name WAN1_PRINCIPAL
ip route 0.0.0.0 0.0.0.0 198.51.100.1 10 name WAN2_BACKUP

end
write memory
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/ip route print detail where dst-address=0.0.0.0/0`)

```text
[netops@RTR-BORDE] > /ip route print detail where dst-address=0.0.0.0/0
Flags: D - dynamic; X - disabled, I - inactive, A - active; c - connect, s - static
 0  As   ;;; WAN 1 Principal (Recursiva via 1.1.1.1)
         dst-address=0.0.0.0/0 routing-table=main gateway=1.1.1.1
         immediate-gw=203.0.113.1%ether1-wan1 check-gateway=ping
         distance=1 scope=30 target-scope=11

 1   s   ;;; WAN 2 Backup (Recursiva via 8.8.8.8)
         dst-address=0.0.0.0/0 routing-table=main gateway=8.8.8.8
         immediate-gw=198.51.100.1%ether2-wan2 check-gateway=ping
         distance=2 scope=30 target-scope=11
```

### Tabla de interpretación de columnas y flags

| Campo en la salida | Qué significa realmente | Estado sano vs Estado roto |
|--------------------|-------------------------|----------------------------|
| **`gateway=1.1.1.1` → `immediate-gw=203.0.113.1%ether1-wan1`** | ✅ **La recursividad funcionó:** RouterOS buscó cómo llegar a `1.1.1.1`, descubrió que el próximo salto real es `203.0.113.1` por `ether1-wan1` y está haciendo ping a `1.1.1.1` | ❌ Si `immediate-gw` está vacío y la ruta figura **`Is` (*Inactive*)** aún con Internet sano, te olvidaste de poner **`target-scope=11`** (en RouterOS v7 el `target-scope` de la ruta recursiva debe ser `>= 1` punto más alto que el `scope=10` de la ruta semilla!) |
| **Fila 0 con `As` y Fila 1 con `s`** | En la tabla principal, `WAN 1` (`distance=1`) está activa y `WAN 2` (`distance=2`) está lista para saltar si `1.1.1.1` deja de responder 2 pings seguidos | Si cae la fibra de `WAN 1`, la Fila 0 pasa a `Is` y la Fila 1 pasa a `As` automáticamente |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: En RouterOS v7 copiaste un tutorial viejo de RouterOS v6 con `scope=10` y `target-scope=10` en ambas rutas y la ruta recursiva `0.0.0.0/0` queda siempre en **`Is` (Inactiva / Unreachable)**

1. **Causa raíz (Cambio estricto del motor de routing en RouterOS v7):**
   - En RouterOS v6 se permitía que la ruta recursiva tuviera el mismo `target-scope=10` que el `scope=10` de la ruta semilla.
   - En **RouterOS v7**, por prevención de bucles recursivos, **el `target-scope` de la ruta que resuelve debe ser estrictamente MAYOR que el `scope` de la ruta semilla** (ej. ruta semilla a `1.1.1.1` con `scope=10 target-scope=10`, y ruta `0.0.0.0/0` con **`target-scope=11`**).
2. **Corrección inmediata:** `/ip route set [find dst-address=0.0.0.0/0] target-scope=11` → La ruta pasa a `As` al instante.

### Síntoma 2: Cuando haces balanceo PCC, los usuarios se quejan de que la página del Banco o de AFIP les cierra la sesión cada vez que hacen clic en un botón

1. **Causa raíz:** Configuraste `per-connection-classifier=both-addresses-and-ports` en lugar de **`src-address-and-dst-address`**.
2. **Por qué ocurre:** Cuando tu navegador entra a un banco, abre 6 conexiones TCP simultáneas desde distintos puertos efímeros origen (`54001`, `54002`, `54003`). Si incluís los puertos en el hash de PCC, la conexión 1 sale por la IP Pública del ISP 1 y la conexión 2 sale por la IP Pública del ISP 2. El servidor de seguridad del banco ve que tu token de sesión viene desde dos IPs públicas distintas al mismo tiempo y bloquea la sesión por sospecha de robo de cookie.
3. **Corrección:** Usar siempre **`per-connection-classifier=src-address-and-dst-address`** (sin puertos), garantizando que una misma PC hablando con un mismo servidor web use siempre el mismo ISP.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Limpieza de conexiones UDP (VoIP / SIP) al cambiar de proveedor WAN:**
  - Como vimos en [`tcp-udp-mtu-and-nat-conntrack.md`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md), las conexiones TCP mueren y se reabren solas al cambiar de WAN, pero los teléfonos VoIP (`UDP 5060`) que envían paquetes cada 15 segundos mantienen viva la entrada vieja en Conntrack con la IP pública del ISP caído.
  - Si tenés telefonía IP, agregá un pequeño `Netwatch` hacia `1.1.1.1` cuyo `down-script` y `up-script` ejecuten: `/ip firewall connection remove [find protocol=udp dst-port=5060]` para que todos los teléfonos se re-registren por el nuevo ISP en 1 segundo.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Usar la misma IP canario (`8.8.8.8`) para vigilar tanto al ISP 1 como al ISP 2:** La ruta semilla `/32` hacia `8.8.8.8` solo puede tener un único gateway activo en la tabla principal. **Siempre tenés que elegir un host canario distinto y ultra-confiable para cada proveedor** (ej. `1.1.1.1` de Cloudflare para el ISP 1 y `8.8.8.8` de Google o `9.9.9.9` de Quad9 para el ISP 2).
- **❌ En PCC, olvidar la regla #0 que exime al tráfico `REDES-INTERNAS -> REDES-INTERNAS` en `mangle prerouting`:** Si no ponés esa regla #0 antes del PCC, cuando una PC de la `VLAN 10` quiera hablar con un servidor local de la `VLAN 40`, la regla Mangle le estampará la marca `to-wan1` y **mandará el paquete destinado a tu servidor local hacia el módem de Internet**, rompiendo la comunicación entre todas tus VLANs internas.

---

## 8. ✅ Buenas prácticas profesionales

- **Si un ISP tiene el doble de velocidad que el otro (ej. ISP 1 = `300 Mbps` e ISP 2 = `150 Mbps`), usar proporción 3:1 en PCC:** En vez de dividir en 2 (`2/0` y `2/1`), dividís en 3 reglas: `3/0` → `conn-wan1`, `3/1` → `conn-wan1`, y `3/2` → `conn-wan2`. Así el ISP 1 recibe el `66%` de las sesiones y el ISP 2 el `33%`.

---

## 9. 🔗 Referencias internas

- [`static-routing-and-floating-routes`](static-routing-and-floating-routes.md) — Fundamentos de rutas flotantes y rutas Blackhole
- [`tcp-udp-mtu-and-nat-conntrack`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md) — Cómo interactúa el cambio de WAN con la tabla Conntrack y el Source NAT
- [`vrrp-and-hsrp-gateway-redundancy`](vrrp-and-hsrp-gateway-redundancy.md) — Qué hacer cuando cada proveedor WAN entra a un router físico diferente (RTR-1 y RTR-2 con VRRP)
