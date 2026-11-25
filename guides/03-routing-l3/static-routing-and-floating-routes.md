⬅️ [Volver a Guías](../README.md)

# Enrutamiento Estático, Rutas Flotantes de Backup y Blackholes — Guía práctica multi-vendor

**Dominio:** `03-routing-l3`
**Nivel:** 🟢 Básico
**Estándares:** `RFC 1812`, `Longest Prefix Match`, `Administrative Distance`
**Concepto base:** [`routing-fundamentals-static-and-dynamic`](../../concepts/routing-fundamentals-static-and-dynamic.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Ver rutas estáticas (S), ruta por defecto (S*) y consultar qué ruta toma un paquete
show ip route static
show ip route 10.2.10.50

# MikroTik RouterOS v7: Ver rutas estáticas activas (As) e inactivas/flotantes (s) y chequear destino
/ip route print where static
/ip route check 10.2.10.50

# Aruba / HP Capa 3: Ver rutas estáticas configuradas
show ip route static

# Linux: Ver tabla de rutas y simular decisión del kernel hacia una IP destino
ip route show
ip route get 10.2.10.50
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

Las **Rutas Estáticas** son los cimientos del enrutamiento: no consumen CPU, no envían paquetes de control por la red y son 100% predecibles. En esta guía implementamos los **4 patrones profesionales de enrutamiento estático**:

1. **Ruta de Resumen por Sucursal (`10.2.0.0/16`):** En lugar de cargar 10 rutas `/24` por cada VLAN de la Sucursal 2, cargamos una sola ruta `/16` que engloba a toda la sede.
2. **Ruta Estática Flotante de Respaldo (*Floating Static Route*, `AD = 10`):** Una segunda ruta hacia la misma `10.2.0.0/16` por un túnel VPN de backup con **Distancia Administrativa `10`** (mayor que `1`), que permanece dormida en segundo plano y despierta automáticamente en 1 segundo si se corta el enlace principal.
3. **Ruta por Defecto (`0.0.0.0/0` — *Default Gateway*):** La puerta de salida hacia Internet para todo destino desconocido.
4. **Rutas *Blackhole / Null0* para bloques privados (`RFC 1918`, `AD = 250`):** El seguro que evita que, cuando se cae el enlace con una sucursal, los paquetes destinados a `10.2.x.x` se escapen hacia tu proveedor de Internet público o formen un bucle de enrutamiento.

> **🧠 Recordatorio del modelo mental:** Pensá en una **Ruta Flotante (`distance=10`)** como **el generador eléctrico de emergencia con arranque automático**: mientras hay corriente de la calle (`Ruta Principal con distance=1`), el generador está apagado en espera; en el segundo en que se corta la luz principal, arranca solo. Y pensá en la **Ruta Blackhole (`distance=250`)** como **un muro de contención al final del estacionamiento**: si tanto el camino principal como el de emergencia hacia la Sucursal 2 están cortados, frena el auto ahí mismo en lugar de dejarlo salir desbocado a la autopista pública (Internet).

---

## 2. 🗺️ Topología de referencia

Conectaremos **Casa Central (`Sede 1: 10.1.0.0/16`)** con **Sucursal Norte (`Sede 2: 10.2.0.0/16`)** a través de un enlace principal de fibra punto a punto (`10.0.255.0/30`) y un túnel VPN de backup (`10.0.255.4/30`):

```text
+-----------------------------------+     Enlace Principal Fibra (/30)     +-----------------------------------+
|     RTR-SEDE1 (Casa Central)      |     10.0.255.1 <=======> 10.0.255.2  |    RTR-SEDE2 (Sucursal Norte)     |
|     Redes: 10.1.0.0/16            |     (Ruta Principal: AD = 1)         |    Redes: 10.2.0.0/16             |
|     (VLANs 10, 20, 40, 99, 100)   |                                      |    (VLANs 10, 99, 100)            |
|                                   |     Túnel VPN Backup (/30)           |                                   |
|     WAN Internet: 203.0.113.2     |     10.0.255.5 <- - - -> 10.0.255.6  |    WAN Internet: 198.51.100.2     |
+-----------------------------------+     (Ruta Flotante: AD = 10)         +-----------------------------------+
                 |                                                                          |
                 v                                                                          v
      [GW ISP 1: 203.0.113.1]                                                    [GW ISP 2: 198.51.100.1]
```

| Ruta a configurar en `RTR-SEDE1` | Prefijo Destino | Próximo Salto (*Gateway*) | Distancia Admin (`AD`) | Cuándo está activa |
|----------------------------------|-----------------|---------------------------|:----------------------:|--------------------|
| **1. Ruta Principal a Sede 2** | `10.2.0.0/16` | `10.0.255.2` (Fibra P2P) | **`1`** | ✅ **Siempre** mientras la fibra responda al ping |
| **2. Ruta Flotante Backup a Sede 2** | `10.2.0.0/16` | `10.0.255.6` (Túnel VPN) | **`10`** | 🔄 Solo cuando cae la ruta principal (`AD 1`) |
| **3. Seguro Blackhole Anti-Fuga** | `10.0.0.0/8` | `blackhole` / `Null0` | **`250`** | 🛡️ Si caen tanto la fibra como la VPN (impide que `10.2.x.x` salga a la WAN) |
| **4. Default Gateway a Internet** | `0.0.0.0/0` | `203.0.113.1` (ISP) | **`1`** | ✅ Para todo destino público fuera de `10.0.0.0/8` |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. MikroTik RouterOS (v7+)

```text
# =====================================================================
# EN RTR-SEDE1 (Casa Central -> hacia Sucursal 2: 10.2.0.0/16)
# =====================================================================
/ip route
# 1. Ruta Principal por Fibra P2P (AD = 1, con chequeo de ping cada 10s al otro extremo)
add dst-address=10.2.0.0/16 gateway=10.0.255.2 distance=1 check-gateway=ping comment="1. Principal a Sede 2 por Fibra"

# 2. Ruta Flotante de Backup por Túnel VPN (AD = 10: queda en espera mientras viva la de AD=1)
add dst-address=10.2.0.0/16 gateway=10.0.255.6 distance=10 check-gateway=ping comment="2. Backup Flotante a Sede 2 por VPN"

# 3. Seguro Blackhole para todos los bloques privados RFC 1918 con AD=250:
#    (Si se caen la fibra y la VPN a la vez, descarta el tráfico interno en vez de mandarlo al ISP!)
add dst-address=10.0.0.0/8     blackhole distance=250 comment="Blackhole RFC1918 Anti-Fuga WAN"
add dst-address=172.16.0.0/12  blackhole distance=250 comment="Blackhole RFC1918 Anti-Fuga WAN"
add dst-address=192.168.0.0/16 blackhole distance=250 comment="Blackhole RFC1918 Anti-Fuga WAN"

# 4. Ruta por Defecto hacia Internet
add dst-address=0.0.0.0/0 gateway=203.0.113.1 distance=1 comment="Default Gateway Internet"


# =====================================================================
# EN RTR-SEDE2 (Sucursal Norte -> ¡SIEMPRE configurar la ruta de VUELTA!)
# =====================================================================
/ip route
add dst-address=10.1.0.0/16 gateway=10.0.255.1 distance=1 check-gateway=ping comment="1. Vuelta a Casa Central por Fibra"
add dst-address=10.1.0.0/16 gateway=10.0.255.5 distance=10 check-gateway=ping comment="2. Vuelta Backup a Casa Central por VPN"
add dst-address=10.0.0.0/8  blackhole distance=250 comment="Blackhole RFC1918 Anti-Fuga WAN"
add dst-address=0.0.0.0/0   gateway=198.51.100.1 distance=1 comment="Default Gateway Internet Sede 2"
```

### B. Cisco IOS / Catalyst L3

> **💡 Nota en Cisco IOS:** Si el enlace de fibra `10.0.255.0/30` pasa por un conversor de medios o radioenlace cuyo puerto Ethernet no se apaga físicamente cuando se corta en la calle, en Cisco asociamos un **IP SLA (Ping monitor)** + **`track 1`** a la ruta principal para que se retire automáticamente si `10.0.255.2` deja de responder al ping:

```cisco
configure terminal

! 1. Crear sonda de ping (IP SLA 1) cada 5 segundos hacia el otro lado de la fibra (10.0.255.2)
ip sla 1
 icmp-echo 10.0.255.2 source-ip 10.0.255.1
 frequency 5
 timeout 2000
ip sla schedule 1 life forever start-time now
track 1 ip sla 1 reachability

! 2. Ruta Principal (AD = 1, vigilada por el track 1)
ip route 10.2.0.0 255.255.0.0 10.0.255.2 1 track 1 name PRINCIPAL_SEDE2_FIBRA

! 3. Ruta Flotante de Backup por VPN (AD = 10: entra en acción apenas cae el track 1!)
ip route 10.2.0.0 255.255.0.0 10.0.255.6 10 name BACKUP_SEDE2_VPN

! 4. Rutas Null0 (Blackhole) con AD = 250 para evitar bucles y fugas de IPs privadas hacia la WAN
ip route 10.0.0.0 255.0.0.0 Null0 250 name BLACKHOLE_RFC1918_10
ip route 172.16.0.0 255.240.0.0 Null0 250 name BLACKHOLE_RFC1918_172
ip route 192.168.0.0 255.255.0.0 Null0 250 name BLACKHOLE_RFC1918_192

! 5. Default Gateway hacia el proveedor de Internet
ip route 0.0.0.0 0.0.0.0 203.0.113.1 name DEFAULT_WAN

end
write memory
```

### C. Switches Gestionables Capa 3 (Aruba / HP ProCurve)

```text
configure
ip route 10.2.0.0/16 10.0.255.2 distance 1
ip route 10.2.0.0/16 10.0.255.6 distance 10
ip route 10.0.0.0/8 reject distance 250
ip route 0.0.0.0/0 203.0.113.1
write memory
```

### D. Linux (`iproute2` / `/etc/network/interfaces` / `Netplan`)

En el kernel Linux, la prioridad entre rutas de igual prefijo (`/16`) se define con el parámetro **`metric`** (menor métrica gana):

```bash
# 1. Ruta Principal por Fibra (metric 10) y Ruta Flotante por VPN (metric 100)
sudo ip route add 10.2.0.0/16 via 10.0.255.2 metric 10
sudo ip route add 10.2.0.0/16 via 10.0.255.6 metric 100

# 2. Ruta Blackhole de seguridad para el bloque 10.0.0.0/8 (como es /8, solo actúa si no coincide ninguna /16 o /24!)
sudo ip route add blackhole 10.0.0.0/8 metric 250

# 3. Ruta por defecto hacia Internet
sudo ip route add default via 203.0.113.1 metric 10
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/ip route print where dst-address~"10.2.0.0"`)

```text
[netops@RTR-SEDE1] > /ip route print where dst-address~"10.2.0.0"
Flags: A - ACTIVE; s - STATIC
Columns: DST-ADDRESS, GATEWAY, DISTANCE
#    DST-ADDRESS  GATEWAY     DISTANCE
;;; 1. Principal a Sede 2 por Fibra
0 As 10.2.0.0/16  10.0.255.2         1
;;; 2. Backup Flotante a Sede 2 por VPN
1  s 10.2.0.0/16  10.0.255.6        10
```

### Qué pasa en la salida cuando se corta la fibra (`10.0.255.2` deja de responder al ping)

```text
[netops@RTR-SEDE1] > /ip route print where dst-address~"10.2.0.0"
Flags: I - INACTIVE, A - ACTIVE; s - STATIC
Columns: DST-ADDRESS, GATEWAY, DISTANCE
#    DST-ADDRESS  GATEWAY     DISTANCE
;;; 1. Principal a Sede 2 por Fibra
0 Is 10.2.0.0/16  10.0.255.2         1
;;; 2. Backup Flotante a Sede 2 por VPN
1 As 10.2.0.0/16  10.0.255.6        10
```

### Tabla de interpretación de columnas y flags

| Flag en MikroTik / Cisco | Qué significa realmente | Comportamiento en vivo |
|--------------------------|-------------------------|------------------------|
| **`As` (*Active, Static*)** | Esta ruta ganó la elección y está instalada en la tabla FIB reenviando paquetes ahora mismo |En estado normal, solo la ruta de `DISTANCE 1` tiene la `A` |
| **`s` (sin la letra `A`)** | **Ruta Flotante en espera:** la ruta es válida y su gateway responde, pero está dormida porque hay otra ruta idéntica con menor `DISTANCE` (`1 < 10`) | En Cisco, una ruta flotante dormida **ni siquiera aparece en `show ip route`** hasta que cae la principal (para verla mientras duerme usás `show running-config \| include ip route`) |
| **`Is` (*Inactive, Static*)** | El `check-gateway=ping` falló (o la interfaz cayó): RouterOS desactivó la ruta principal y le pasó la letra **`A`** a la ruta flotante de `DISTANCE 10` | Cuando la fibra vuelve a responder al ping, la ruta 0 recupera su `As` automáticamente |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Cortás la fibra principal para probar el backup, la ruta en `RTR-SEDE1` salta a la VPN (`10.0.255.6`), pero la Sucursal 2 igual no responde

1. **Verificación rápida:** Revisar la tabla de rutas en el router del otro extremo (**`RTR-SEDE2`**).
2. **Causa raíz (Asimetría en el Failover):**
   - En `RTR-SEDE1` habías puesto `check-gateway=ping`, por lo que `RTR-SEDE1` detectó el corte y empezó a mandar los paquetes por la VPN.
   - Pero en **`RTR-SEDE2` te olvidaste de poner `check-gateway=ping`** (y como su puerto Ethernet seguía conectado al conversor de fibra en `Link Up`, `RTR-SEDE2` siguió intentando devolver las respuestas por la fibra cortada).
3. **Corrección:** Activar `check-gateway=ping` (o `IP SLA track`) en **ambos extremos** del enlace para que tanto la ida como la vuelta conmuten a la VPN al mismo tiempo.

### Síntoma 2: ¿Por qué es tan importante la ruta `blackhole 10.0.0.0/8 distance=250`?

1. **Qué ocurre si NO la ponés:**
   - Supongamos que se cae el túnel VPN con la Sucursal 2 (`10.2.0.0/16`). La ruta hacia `10.2.0.0/16` desaparece de la tabla de rutas.
   - Un segundo después, una PC de Casa Central intenta enviar un paquete al servidor `10.2.40.10`.
   - El router busca `10.2.40.10` en su tabla: como ya no existe la ruta `10.2.0.0/16`, **¡coincide con la ruta por defecto `0.0.0.0/0` (Internet)!** El router le aplica NAT y escupe tus paquetes internos confidenciales por la boca WAN hacia tu proveedor de Internet (y si el ISP tiene mal configuradas sus rutas, puede devolvértelos creando un bucle en tu interfaz WAN).
2. **Qué hace la ruta `blackhole 10.0.0.0/8 distance=250`:**
   - Como `/8` es más específica que `0.0.0.0/0` (*Longest Prefix Match*), pero menos específica que cualquier `/16` o `/24` activa, mientras la sucursal está arriba la ruta blackhole jamás interfiere; pero si la sucursal se cae, el paquete cae en el `blackhole` y se descarta limpiamente adentro de tu router sin salir jamás a Internet.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Cómo desviar todo el tráfico de la Fibra hacia la VPN manualmente antes de hacer mantenimiento en la fibra (sin perder ni un paquete):**
  - En lugar de apagar la interfaz de fibra de golpe, entrás a ambos routers y subís temporalmente la distancia administrativa de la ruta de fibra de `1` a **`20`** (mayor que `10` de la VPN):
  - `/ip route set [find comment~"Principal a Sede 2"] distance=20`
  - El tráfico pasa suavemente a la VPN (`AD=10`), hacés tus pruebas en la fibra, y al terminar la devolvés a `distance=1`.

---

## 7. ⚠️ Errores comunes en producción

- **❌ En Cisco o MikroTik, poner como `gateway` de una ruta estática el nombre de una interfaz Ethernet (`gateway=ether1`) en lugar de la dirección IP del próximo salto (`gateway=10.0.255.2`):**
  - En una interfaz Ethernet (multipunto), si ponés `ip route 10.2.0.0 255.255.0.0 GigabitEthernet0/1` sin indicar la IP del router vecino, el router cree que los 65.534 hosts de `10.2.0.0/16` están directamente pegados a ese cable y **manda un `ARP Request` nuevo por cada una de las 65.534 IPs**, llenando su memoria RAM en segundos. **Poné siempre la dirección IP del próximo salto (`Next-Hop IP`).**
- **❌ Poner la ruta flotante con una máscara diferente a la ruta principal (ej. principal `/16` y flotante `/24`):** Recordá siempre la **Ley #1 (*Longest Prefix Match*)**: si la ruta de backup tiene una máscara `/24` y la principal tiene una `/16`, **la de backup `/24` ganará siempre** aunque le pongas `distance=250`. Ambas rutas (la principal y su flotante) deben tener **exactamente el mismo `dst-address` y la misma máscara**.

---

## 8. ✅ Buenas prácticas profesionales

- **Resumir siempre por sede (`10.<Sede>.0.0/16`):** Si respetaste el plan de direccionamiento de [`ipv4-cidr-vlsm-and-special-ranges.md`](../../reference/ipv4-cidr-vlsm-and-special-ranges.md), conectar una sucursal nueva de 15 VLANs requiere **1 sola línea de ruta estática (`10.3.0.0/16`)** en lugar de 15 rutas sueltas.
- **Cuando tengas más de 3 sedes o mallas de túneles VPN:** En vez de mantener decenas de rutas estáticas y flotantes a mano, pasá a **OSPF** con la guía siguiente ([`ospf-single-and-multi-area.md`](ospf-single-and-multi-area.md)).

---

## 9. 🔗 Referencias internas

- [`routing-fundamentals-static-and-dynamic`](../../concepts/routing-fundamentals-static-and-dynamic.md) —Las 3 leyes de decisión del router: Longest Prefix Match, Distancia Administrativa y Métrica
- [`ospf-single-and-multi-area`](ospf-single-and-multi-area.md) — El paso siguiente: automatizar el aprendizaje de rutas y el failover entre múltiples routers con OSPF
- [`dual-wan-failover-and-load-balancing`](dual-wan-failover-and-load-balancing.md) — Cómo aplicar rutas recursivas para el failover automático de dos proveedores de Internet (WAN 1 y WAN 2)
