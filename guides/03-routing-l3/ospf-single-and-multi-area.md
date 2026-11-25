⬅️ [Volver a Guías](../README.md)

# OSPF (Open Shortest Path First) Multi-Vendor — Guía práctica en Cisco, MikroTik v7 y FRRouting

**Dominio:** `03-routing-l3`
**Nivel:** 🔴 Avanzado
**Estándares:** `RFC 2328 (OSPFv2)`, `RFC 5340 (OSPFv3)`, `Protocolo IP 89`, `Multicast 224.0.0.5 / 224.0.0.6`
**Concepto base:** [`routing-fundamentals-static-and-dynamic`](../../concepts/routing-fundamentals-static-and-dynamic.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Ver vecinos OSPF (deben llegar a estado FULL), interfaces activas y rutas aprendidas (O)
show ip ospf neighbor
show ip ospf interface brief
show ip route ospf

# MikroTik RouterOS v7: Ver vecinos OSPF, instancias, plantillas de interfaz y rutas OSPF (DAo)
/routing ospf neighbor print
/routing ospf interface-template print
/ip route print where ospf

# Linux (FRRouting — vtysh): Ver vecinos y rutas OSPF
sudo vtysh -c "show ip ospf neighbor"
sudo vtysh -c "show ip route ospf"
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

Cuando tu red crece a 3, 5 o 20 routers (por ejemplo: un Switch Core L3, dos routers de borde, sucursales unidas por fibra y túneles VPN de respaldo), mantener rutas estáticas a mano se vuelve inmanejable: cada vez que creás una VLAN nueva tenés que entrar a 10 routers a escribir la ruta.

**OSPF (*Open Shortest Path First*)** es el protocolo estándar universal de enrutamiento dinámico interno (**IGP**). Como es un estándar abierto (`RFC 2328`), **podés conectar un router Cisco, un router MikroTik con RouterOS v7 y un servidor Linux con FRRouting en la misma red y hablarán OSPF entre sí a la perfección**:

1. Se descubren solos enviando paquetes `Hello` al multicast **`224.0.0.5` (Protocolo IP `89`)**.
2. Intercambian anuncios de estado de enlace (**LSAs**) para que todos los routers tengan el mismo mapa topológico (**LSDB**).
3. Eligen el camino más rápido sumando el **Costo (`Cost`)** de cada enlace según su ancho de banda.
4. Si un enlace se corta, todos los routers recalculan el camino alternativo con el algoritmo de **Dijkstra (SPF)** en menos de **1 a 2 segundos**.

> **🧠 Recordatorio del modelo mental:** Pensá en las Rutas Estáticas como **imprimir un papel con indicaciones paso a paso ("doblá a la derecha en la calle 2")**: si esa calle está cortada por obras, el chofer se queda parado frente a la valla. Pensá en **OSPF** como **Waze o Google Maps compartido en vivo entre todos los routers**: todos conocen el mapa completo de la ciudad (`LSDB`) y cuánto tráfico/velocidad tiene cada avenida (`Cost`); si se corta un puente, el GPS recalcula la ruta de todos los autos instantáneamente.

---

## 2. 🗺️ Topología de referencia

En esta topología multi-vendor en triángulo, un **Cisco (`R1`)**, un **MikroTik v7 (`R2`)** y un **Linux con FRRouting (`R3`)** forman vecindad OSPF en el **`Area 0 (Backbone)`** usando enlaces punto a punto (`network-type=ptp`) y anuncian sus VLANs locales como interfaces pasivas (`passive`):

```text
                       +-----------------------------------+
                       |     R1: CISCO IOS (Casa Central)  |
                       |     Router-ID (lo0): 10.0.0.1/32  |
                       |     LAN Local: 10.1.10.0/24       |
                       +-----------------------------------+
                            /                         \
      Enlace Fibra (/30)   /                           \  Enlace Fibra (/30)
      10.0.255.0/30       /                             \ 10.0.255.8/30
      (Cost = 10)        /                               \ (Cost = 10)
                        v                                 v
+-----------------------------------+         +-----------------------------------+
|  R2: MIKROTIK v7 (Sucursal Norte) |         |  R3: LINUX FRRouting (DataCenter) |
|  Router-ID (lo0): 10.0.0.2/32     | <- - -> |  Router-ID (lo): 10.0.0.3/32      |
|  LAN Local: 10.2.10.0/24          |  Túnel  |  LAN Servidores: 10.3.40.0/24     |
+-----------------------------------+  VPN /30+-----------------------------------+
                                    10.0.255.4/30
                                    (Cost = 100 — Backup!)
```

| Parámetro OSPF | Valor Estándar que aplicaremos en los 3 fabricantes | Por qué es una buena práctica crítica |
|----------------|-----------------------------------------------------|---------------------------------------|
| **Área OSPF** | **`Area 0` (`0.0.0.0` — Backbone)** | Toda red OSPF empieza en el `Area 0`. Hasta ~50 routers no necesitás dividir en múltiples áreas (`Single-Area OSPF`) |
| **Router-ID (`10.0.0.X`)** | IP fija `/32` en una interfaz **Loopback** | Una interfaz Loopback es virtual y **jamás se cae** aunque se desconecte un cable físico |
| **Tipo de Red en enlaces `/30`** | **`point-to-point` (`ptp`)** | En un cable `/30` entre 2 routers no hace falta elegir *Designated Router (DR/BDR)*: con `point-to-point` OSPF levanta **15 segundos más rápido** |
| **Interfaces de Usuarios (`LANs`)** | **`passive` (`passive-interface`)** | Anuncia la subred `10.X.10.0/24` a los demás routers, pero **prohíbe enviar/aceptar paquetes `Hello` OSPF hacia las PCs de los usuarios** |
| **Autenticación del enlace** | **`MD5` / `SHA`** | Impide que un equipo no autorizado inyecte rutas falsas |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. Router 1: Cisco IOS (`R1` — `Router-ID 10.0.0.1`)

```cisco
configure terminal

! 1. Crear interfaz Loopback0 para el Router-ID
interface Loopback0
 ip address 10.0.0.1 255.255.255.255
exit

! 2. Configurar los enlaces entre routers como 'ip ospf network point-to-point' y su Costo
interface GigabitEthernet0/1
 description ENLACE_FIBRA_HACIA_R2_MIKROTIK
 ip address 10.0.255.1 255.255.255.252
 ip ospf network point-to-point
 ip ospf cost 10
exit

interface GigabitEthernet0/2
 description ENLACE_FIBRA_HACIA_R3_FRR
 ip address 10.0.255.9 255.255.255.252
 ip ospf network point-to-point
 ip ospf cost 10
exit

! 3. Configurar el proceso OSPF 1:
!    - 'passive-interface default': bloquea saludos OSPF en todas las bocas por defecto
!    - 'no passive-interface ...': habilita saludos SOLO en los enlaces hacia R2 y R3
router ospf 1
 router-id 10.0.0.1
 auto-cost reference-bandwidth 10000
 passive-interface default
 no passive-interface GigabitEthernet0/1
 no passive-interface GigabitEthernet0/2
 network 10.0.0.1 0.0.0.0 area 0
 network 10.0.255.0 0.0.0.3 area 0
 network 10.0.255.8 0.0.0.3 area 0
 network 10.1.10.0 0.0.0.255 area 0
exit

end
write memory
```

### B. Router 2: MikroTik RouterOS v7 (`R2` — `Router-ID 10.0.0.2`)

> **⚠️ Cambio importante en RouterOS v7:** En RouterOS v7 ya no existe el menú viejo `/routing ospf network` de v6. En **RouterOS v7**, todo se configura de forma mucho más limpia y potente mediante **`/routing ospf interface-template`**, donde en una sola línea definís la interfaz o subred, si es `ptp` o `passive` y su `cost`:

```text
# 1. Asignar la IP de Loopback (en RouterOS v7.14+ existe la interfaz 'lo' nativa, o se crea un bridge vacío 'lo0'):
/interface bridge add name=lo0 comment="Loopback OSPF"
/ip address add address=10.0.0.2/32 interface=lo0

# 2. (MUY IMPORTANTE EN EL FIREWALL): Asegurar que la cadena INPUT permita el Protocolo IP 89 (OSPF)
#    en las interfaces entre routers! Si tu regla final de INPUT es 'drop', sin esto OSPF no levanta:
/ip firewall filter
add chain=input protocol=ospf in-interface-list=!WAN action=accept place-before=[find action=drop] comment="Permitir OSPF (Proto 89)"

# 3. Crear la Instancia OSPF v2 y el Area 0 (Backbone):
/routing ospf instance
add name=ospf-instance-1 version=2 router-id=10.0.0.2

/routing ospf area
add name=backbone-v2 instance=ospf-instance-1 area-id=0.0.0.0

# 4. Definir las plantillas de interfaz (interface-template):
/routing ospf interface-template
# Enlace de Fibra principal hacia R1 (Cisco): Punto a Punto, Costo 10 (rápido)
add area=backbone-v2 interfaces=ether2-to-r1 networks=10.0.255.0/30 type=ptp cost=10 comment="Enlace Fibra a R1"

# Enlace de Túnel VPN de Backup hacia R3 (Linux): Punto a Punto, Costo 100 (solo se usa si cae una fibra!)
add area=backbone-v2 interfaces=wg-to-r3 networks=10.0.255.4/30 type=ptp cost=100 comment="Enlace VPN Backup a R3"

# Loopback y VLANs locales de Usuarios: PASSIVE (se anuncian, pero NO hablan OSPF hacia las PCs!)
add area=backbone-v2 interfaces=lo0,vlan10-staff passive=yes comment="Anunciar LANs en modo Pasivo"
```

### C. Router 3: Linux con `FRRouting` (`R3` — `Router-ID 10.0.0.3`)

**FRRouting (`frr`)** es el motor de routing open-source estándar de la industria que corre en Linux, Proxmox (SDN), SONiC y pfSense/OPNsense, y tiene una consola (`vtysh`) idéntica a Cisco IOS:

```bash
# 1. Instalar FRRouting y habilitar el demonio ospfd en /etc/frr/daemons
sudo apt install -y frr
sudo sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons
sudo systemctl restart frr

# 2. Entrar a la consola vtysh y configurar exactamente igual que en Cisco IOS:
sudo vtysh << 'EOF'
configure terminal
interface lo
 ip address 10.0.0.3/32
exit
interface eth1
 description ENLACE_FIBRA_HACIA_R1_CISCO
 ip address 10.0.255.10/30
 ip ospf network point-to-point
 ip ospf cost 10
exit
interface wg0
 description ENLACE_VPN_HACIA_R2_MIKROTIK
 ip address 10.0.255.6/30
 ip ospf network point-to-point
 ip ospf cost 100
exit
router ospf
 ospf router-id 10.0.0.3
 auto-cost reference-bandwidth 10000
 passive-interface default
 no passive-interface eth1
 no passive-interface wg0
 network 10.0.0.3/32 area 0
 network 10.0.255.8/30 area 0
 network 10.0.255.4/30 area 0
 network 10.3.40.0/24 area 0
exit
end
write memory
EOF
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/routing ospf neighbor print` y `/ip route print where ospf`)

```text
[netops@R2-MIKROTIK] > /routing ospf neighbor print
Flags: V - virtual; D - dynamic
 0 D instance=ospf-instance-1 area=backbone-v2 address=10.0.255.1 router-id=10.0.0.1 state="Full" state-changes=4 adjacency=3d12h10m
 1 D instance=ospf-instance-1 area=backbone-v2 address=10.0.255.6 router-id=10.0.0.3 state="Full" state-changes=4 adjacency=3d12h09m

[netops@R2-MIKROTIK] > /ip route print where ospf
Flags: D - DYNAMIC; A - ACTIVE; o - OSPF
Columns: DST-ADDRESS, GATEWAY, DISTANCE
   DST-ADDRESS   GATEWAY                 DISTANCE
   DAo 10.0.0.1/32   10.0.255.1%ether2-to-r1      110
   DAo 10.0.0.3/32   10.0.255.1%ether2-to-r1      110
   DAo 10.1.10.0/24  10.0.255.1%ether2-to-r1      110
   DAo 10.3.40.0/24  10.0.255.1%ether2-to-r1      110
```

> **💡 Observá la última línea de la tabla de rutas de `R2`:** Para llegar a `10.3.40.0/24` (que vive en `R3`), `R2` eligió ir a través de `R1` (`10.0.255.1`) porque **`Costo Fibra (10) + Costo Fibra (10) = 20`**, que es menor que el **`Costo 100`** del túnel VPN directo entre `R2` y `R3`. Pero si se corta la fibra entre `R2` y `R1`, en 1 segundo la ruta hacia `10.1.10.0/24` y `10.3.40.0/24` salta automáticamente al túnel VPN `10.0.255.6%wg-to-r3`.

### Tabla de interpretación de Estados de Vecindad OSPF

| Estado del Vecino (`state`) | ¿Es normal o está roto? | Qué significa y qué revisar si se queda trabado ahí |
|-----------------------------|:-----------------------:|-----------------------------------------------------|
| **`Down` / (Lista vacía)** | ❌ **Roto** | No se recibe ningún paquete `Hello` (`224.0.0.5`). Revisar IP, VLAN, o firewall `INPUT` bloqueando `protocol=ospf` (`89`) |
| **`Init`** | ❌ **Roto** | Escuchás el `Hello` del vecino, pero el vecino no te escucha a vos (enlace unidireccional o el vecino tiene tu IP bloqueada en su firewall) |
| **`2-Way`** | 🟡 Normal solo en Broadcast entre Drothers | Ambos se escucharon. En un enlace `point-to-point` debe pasar de largo a `Full` en milisegundos |
| **`ExStart` / `Exchange`** | 🚨 **Roto (99% es MTU!)** | Los routers intentan enviarse el resumen de su base de datos (`DBD`), que son paquetes grandes, y **uno de los dos lados tiene un MTU de Capa 3 diferente al otro** |
| **`Full`** | ✅ **100% Sano** | Las bases de datos (`LSDB`) están sincronizadas y las rutas ya están instaladas en la tabla de enrutamiento |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Conectar un Cisco y un MikroTik/FRR: el ping entre ambos funciona perfecto, pero en `show ip ospf neighbor` el vecino se queda clavado en `ExStart` o `Exchange` y se reinicia

1. **Causa raíz (Diferencia de MTU):**
   - Por estándar `RFC 2328`, en el paso `ExStart` cada router anuncia el **IP MTU** de su interfaz en el paquete `DBD`. Si el Router A dice `MTU = 1500` y el Router B dice `MTU = 1492` (o `1420` en un túnel VPN), OSPF se niega a sincronizar la base de datos.
2. **Corrección profesional:**
   - **Solución real:** Igualar el `MTU` en las interfaces de ambos routers (por ejemplo, fijar `mtu=1420` en ambos extremos del túnel WireGuard).
   - **Workaround de emergencia en Cisco/FRR:** `ip ospf mtu-ignore` dentro de la interfaz (le dice a OSPF que ignore el chequeo de número de MTU, aunque siempre es mejor igualar el MTU real).

### Síntoma 2: Ambos routers tienen las interfaces arriba, pero jamás aparecen en `show ip ospf neighbor` (lista vacía)

1. **Los 4 requisitos que DEBEN coincidir al 100% en un enlace para que dos vecinos OSPF formen adyacencia:**
   1. **Misma subred y misma máscara exacta** (ej. ambos `/30` en `10.0.255.0/30`).
   2. **Mismo número de Área** (ej. ambos en `Area 0` / `0.0.0.0`).
   3. **Mismos intervalos `Hello` (`10s`) y `Dead` (`40s`)** y **mismo `network-type`** (`point-to-point` en ambos lados, o `broadcast` en ambos lados: si un lado está en `ptp` y el otro quedó en `broadcast`, se ven en `Full` pero **no instalan las rutas** en la tabla!).
   4. **Misma contraseña de autenticación** y **Router-IDs diferentes** (si clonaste un router y ambos tienen `router-id=10.0.0.1`, se rechazarán mutuamente).

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Cómo sacar de servicio un router o un enlace OSPF para mantenimiento sin perder paquetes (*Graceful Drain / Cost Out*):**
  - Antes de apagar o reiniciar un enlace de fibra con OSPF, subile su costo a **`65535`** (`/routing ospf interface-template set [find] cost=65535` o `ip ospf cost 65535`).
  - OSPF avisará a todos los demás routers de la empresa que ese camino ahora es "carísimo", todo el tráfico migrará limpiamente al enlace secundario sin cortar ni una sola sesión TCP, y 5 segundos después ya podés desconectar el cable tranquilo.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Usar `redistribute connected` o `redistribute static` en OSPF para anunciar las VLANs internas de la empresa:**
  - En lugar de usar `redistribute connected` (que inyecta rutas externas Tipo 5 `O E2` y puede anunciar por accidente la subred de tu módem WAN o interfaces temporales), **agregá siempre las VLANs internas como `passive` dentro del área OSPF** (`interface-template passive=yes` en MikroTik / `network ... area 0` + `passive-interface` en Cisco). Así viajan como rutas internas nativas de OSPF con métricas limpias.
- **❌ Olvidar cambiar `auto-cost reference-bandwidth 10000` (o `100000`) en Cisco / FRRouting:**
  - Cuando se escribió el estándar OSPF en los años 90, la fórmula de costo por defecto era $\frac{100\text{ Mbps}}{\text{Ancho de Banda}}$, con un mínimo de `1`. Por eso, **con el valor de fábrica, para Cisco OSPF un enlace de `100 Mbps`, uno de `1 Gbps`, uno de `10 Gbps` y uno de `100 Gbps` valen todos exactamente `Cost = 1`!**
  - Fijá tus costos explícitamente en los enlaces troncales (`cost 10` para fibra 10G, `cost 20` para 1G, `cost 100` para VPN) o configurá `auto-cost reference-bandwidth 100000` en todos tus routers.

---

## 8. ✅ Buenas prácticas profesionales

- **Usar siempre `type=ptp` (`ip ospf network point-to-point`) en enlaces donde solo hay 2 routers (cables `/30`, `/31` o túneles WireGuard/GRE):** Evita la elección inútil de DR/BDR (que en modo `broadcast` demora 40 segundos de *Wait Timer*) y reduce el tamaño de la base de datos OSPF.
- **Activar BFD (*Bidirectional Forwarding Detection*) sobre los enlaces críticos:** Mientras que los timers estándar de OSPF tardan hasta `40 segundos` (`Dead Interval`) en detectar que un enlace con un switch en el medio murió sin caer el link físico, **BFD** detecta la caída en **`< 300 milisegundos`** (`3 × 100ms`) y le avisa instantáneamente a OSPF (`use-bfd=yes` en MikroTik v7 / `ip ospf bfd` en Cisco).

---

## 9. 🔗 Referencias internas

- [`routing-fundamentals-static-and-dynamic`](../../concepts/routing-fundamentals-static-and-dynamic.md) — El modelo mental de Distancia Administrativa (`OSPF = 110`) y Longest Prefix Match
- [`static-routing-and-floating-routes`](static-routing-and-floating-routes.md) — Cuándo basta con rutas estáticas flotantes y cómo combinarlas con rutas Blackhole
- [`network-ports-protocols-and-multicast`](../../reference/network-ports-protocols-and-multicast.md) — Referencia del Protocolo IP `89` (OSPF) y direcciones multicast `224.0.0.5` / `224.0.0.6`
