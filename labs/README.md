⬅️ [Volver al README principal](../README.md)

# 🧪 Laboratorios Prácticos de Redes (`labs/`)

Topologías reproducibles con **Docker Compose**, **FRRouting (`vtysh` estilo Cisco IOS)**, **Linux Bridge (`802.1Q` / `RSTP`)** y **`nftables` / `iptables` (`Conntrack`)** para practicar configuración, captura de paquetes con `tcpdump` y resolución de incidentes reales en cualquier computadora sin necesidad de hardware físico.

---

## ⚙️ Requisitos y limitaciones del entorno

- **Host Docker sobre Linux (recomendado).** Los labs usan `NET_ADMIN`/`privileged`, `iptables`, `sysctls` y (en el lab integrador) túneles **WireGuard/GRE**. En **Docker Desktop / WSL2** algunos labs de **NAT/DNAT y ruteo entre bridges** no reproducen su comportamiento esperado, porque el host interfiere en el ruteo entre redes; para esas prácticas conviene un **host Docker Linux nativo**.
- **Orden de interfaces no garantizado.** Docker Compose asigna las interfaces de un servicio **en orden alfabético por nombre de red** (no por el orden en que se declaran). Por eso los labs que dependen de una interfaz concreta la **detectan por su IP** al arrancar (p. ej. la WAN por `203.0.113.2`) en lugar de asumir `eth0`/`eth1`.
- **Internet en el primer arranque.** Los contenedores instalan paquetes con `apk add` al iniciar: la primera vez necesitan salida a Internet.
- **`ip_forward`.** Se habilita con `sysctls:` de Compose (más un `sysctl -w` tolerante), para funcionar aunque `/proc/sys` sea de solo lectura en el contenedor.

---

## 🗂️ Los 5 Entornos de Laboratorio Incluidos

| Lab | Archivo Docker Compose | Qué vas a practicar en vivo |
|:---:|------------------------|-----------------------------|
| **01** | [`docker-compose.lab01-vlan-roas.yml`](docker-compose.lab01-vlan-roas.yml) | Etiquetas **VLAN `802.1Q`**, captura de tags con `tcpdump -ni eth0 -e vlan` y enrutamiento **Router-on-a-Stick (ROAS)** entre la `VLAN 10` y la `VLAN 20` |
| **02** | [`docker-compose.lab02-stp-and-lacp.yml`](docker-compose.lab02-stp-and-lacp.yml) | **Spanning Tree (`STP`)**, elección del **Root Bridge (`Priority 4096 vs 32768`)**, inspección de tramas BPDU (`01:80:C2:00:00:00`) y **Bonding LACP `802.3ad`** |
| **03** | [`docker-compose.lab03-ospf-and-vrrp.yml`](docker-compose.lab03-ospf-and-vrrp.yml) | **3 Routers con consola `vtysh` (idéntica a Cisco IOS)** corriendo **OSPFv2 (`Area 0`)**, simulación de caída de fibra (failover por costo `10` vs `100`) y reproducción del fallo **`ExStart` por diferencia de MTU** |
| **04** | [`docker-compose.lab04-nat-hairpin-mtu.yml`](docker-compose.lab04-nat-hairpin-mtu.yml) | **Port Forwarding (`DNAT`)**, reproducción del **"Triángulo Roto" del Hairpin NAT** (funciona desde `cliente-externo` pero falla desde `pc-interna`), solución en 1 línea, inspección de **Conntrack** y **TCP MSS Clamping** |
| **05** | [`docker-compose.integrative.yml`](docker-compose.integrative.yml) | **Proyecto Integrador Capstone Multi-Sede:** 6 contenedores que unen **VLANs 802.1Q**, **Inter-VLAN**, **OSPFv2 sobre túnel site-to-site**, **Firewall + DNAT + Hairpin NAT** y **MSS Clamping** en una sola topología `Lumen Corp` |

---

## 🚀 Ejercicios Guiados Paso a Paso

### 🧪 Lab 01 — VLANs `802.1Q` y Router-on-a-Stick (ROAS)

```bash
# 1. Levantar la topología:
docker compose -f labs/docker-compose.lab01-vlan-roas.yml up -d

# 2. En una terminal, abrir captura en vivo en el Router viendo las etiquetas 802.1Q (-e):
docker exec -it lab01-router tcpdump -ni eth0 -e 'vlan'

# 3. En otra terminal, desde la PC de la VLAN 10 (10.1.10.50) consultar el servidor HTTP de la VLAN 20 (10.1.20.10:8080):
docker exec -it lab01-pc-vlan10 curl -I http://10.1.20.10:8080
# -> ¡Observá en el tcpdump del Router cómo el paquete ENTRA con 'vlan 10' y SALE hacia el servidor con 'vlan 20'
#    cambiando las direcciones MAC de Capa 2 y restando 1 al TTL!

# 4. Apagar el laboratorio al terminar:
docker compose -f labs/docker-compose.lab01-vlan-roas.yml down
```

---

### 🧪 Lab 02 — Spanning Tree (Elección de Root Bridge y captura de BPDUs)

```bash
# 1. Levantar los dos switches (SW-CORE con prioridad 4096 y SW-ACCESO con prioridad 32768):
docker compose -f labs/docker-compose.lab02-stp-and-lacp.yml up -d

# 2. Verificar la configuración del bridge y prioridad STP en SW-CORE:
docker exec -it lab02-sw-core ip -d link show br0

# 3. Apagar el laboratorio al terminar:
docker compose -f labs/docker-compose.lab02-stp-and-lacp.yml down
```

---

### 🧪 Lab 03 — OSPFv2 Multi-Router (Consola `vtysh` estilo Cisco IOS + Romper y Arreglar `ExStart` por MTU)

```bash
# 1. Levantar el triángulo de 3 routers OSPF (RTR1 Central, RTR2 Sucursal, RTR3 DataCenter):
docker compose -f labs/docker-compose.lab03-ospf-and-vrrp.yml up -d

# 2. Ver los vecinos OSPF en estado FULL y la tabla de rutas OSPF en RTR2 (igual que en un Cisco real!):
docker exec -it lab03-rtr2 vtysh -c "show ip ospf neighbor"
docker exec -it lab03-rtr2 vtysh -c "show ip route ospf"
# -> Observá cómo RTR2 llega a la red 10.3.40.0/24 de RTR3 a través de RTR1 (Costo 10 + 10 = 20)
#    en lugar de usar el enlace directo lento (Costo 100)!

# 3. SIMULACRO 1 (Failover OSPF en 1 segundo): Cortar el enlace principal eth0 de RTR2 y ver cómo salta al backup!
docker exec -it lab03-rtr2 ip link set dev eth0 down
docker exec -it lab03-rtr2 vtysh -c "show ip route ospf"
# -> ¡La ruta a 10.1.10.0/24 y 10.3.40.0/24 ahora sale automáticamente por eth1 (10.0.255.6) con Costo 100/110!
# Volver a levantar eth0:
docker exec -it lab03-rtr2 ip link set dev eth0 up

# 4. SIMULACRO 2 (Provocar el clásico error 'ExStart' por diferencia de MTU!):
#    Cambiar el MTU de eth0 en RTR2 a 1420 bytes y reiniciar la vecindad OSPF:
docker exec -it lab03-rtr2 ip link set dev eth0 mtu 1420
docker exec -it lab03-rtr2 vtysh -c "clear ip ospf process"
docker exec -it lab03-rtr2 vtysh -c "show ip ospf neighbor"
# -> ¡Vas a ver con tus propios ojos cómo el vecino 10.0.0.1 queda TRABADO en 'ExStart/-'!
#    Ahora arreglalo devolviendo el MTU a 1500:
docker exec -it lab03-rtr2 ip link set dev eth0 mtu 1500

# 5. Apagar el laboratorio al terminar:
docker compose -f labs/docker-compose.lab03-ospf-and-vrrp.yml down
```

---

### 🧪 Lab 04 — Port Forwarding (`DNAT`), Reproducción en Vivo del *Hairpin NAT* y Tabla *Conntrack*

```bash
# 1. Levantar el Firewall de borde, el Servidor Web interno, la PC de la oficina y el Cliente 4G externo:
docker compose -f labs/docker-compose.lab04-nat-hairpin-mtu.yml up -d

# 2. Probar entrar al servidor usando la IP Pública (203.0.113.2:8080) desde el CLIENTE 4G EXTERNO:
docker exec -it lab04-cliente-externo curl -m 3 http://203.0.113.2:8080
# -> ✅ ¡Funciona al instante! Devuelve: "<h1>Servidor ERP Interno (10.1.40.10:8080) - Conexion Exitosa!</h1>"

# 3. Ahora probar entrar a esa MISMA IP Pública (203.0.113.2:8080) desde la PC DE LA OFICINA (10.1.40.50):
docker exec -it lab04-pc-interna curl -m 3 http://203.0.113.2:8080
# -> ❌ ¡FALLA con Timeout! Acabás de reproducir el "Triángulo Roto" del escenario 02 de security-vpn!

# 4. SOLUCIONARLO EN VIVO agregando la regla de Hairpin NAT en el Firewall (fw-borde):
docker exec -it lab04-fw-borde iptables -t nat -A POSTROUTING -s 10.1.40.0/24 -d 10.1.40.10 -p tcp --dport 8080 -j MASQUERADE

# 5. Volver a probar desde la PC DE LA OFICINA e inspeccionar la tabla Conntrack en el Firewall:
docker exec -it lab04-pc-interna curl -m 3 http://203.0.113.2:8080
# -> ✅ ¡Ahora abre instantáneamente desde adentro de la oficina también!
docker exec -it lab04-fw-borde conntrack -L

# 6. Apagar el laboratorio al terminar:
docker compose -f labs/docker-compose.lab04-nat-hairpin-mtu.yml down
```

---

### 🧪 Lab 05 — Proyecto Integrador Capstone "Lumen Corp" (6 contenedores)

El laboratorio más completo del repositorio: une **Switching L2, Inter-VLAN, OSPFv2, túnel site-to-site, Firewall, NAT/Hairpin y MSS Clamping** en una topología de dos sedes. Es el entorno ejecutable del [Proyecto Integrador Capstone](../scenarios/maintenance/04-integrative-capstone-enterprise-network.md).

```text
                         INTERNET (wan_net 203.0.113.0/24)
              cliente-wan .100        rtr-sede1 .2        rtr-sede2 .3
                    |                     |                   |
                    |              (tunel wg0 10.255.255.0/30) |
                    |                     |<===== OSPF =======>|
                    |              802.1Q Trunk               |
                    |        +------------+                   |
                    |        |  sw-core   |  (VLAN 99: .2)    |
                    |        +--+------+--+                   |
                    |   VLAN 10 |      | VLAN 40               | dummy0 10.2.40.1/24
                    |     pc-staff     srv-erp                 | (LAN Sucursal)
                    |     10.1.10.50   10.1.40.10:8080        |
```

```bash
# 1. Levantar las dos sedes y esperar ~20 s a que suba WireGuard + OSPF:
docker compose -f labs/docker-compose.integrative.yml up -d

# 2. Verificar que el TUNEL quedó arriba (WireGuard) y que OSPF llego a FULL:
docker exec -it rtr-sede1 wg show
docker exec -it rtr-sede1 vtysh -c "show ip ospf neighbor"
docker exec -it rtr-sede1 vtysh -c "show ip route ospf"
# -> Debes ver el vecino 10.255.255.2 en 'Full/PointToPoint' y la ruta a 10.2.0.0/16.

# 3. Inter-VLAN: la PC de Staff (VLAN 10) alcanza el ERP (VLAN 40):
docker exec -it pc-staff curl -m 3 http://10.1.40.10:8080

# 4. DNAT desde "Internet" y HAIRPIN desde adentro (misma URL publica):
docker exec -it cliente-wan curl -m 3 http://203.0.113.2:8080
docker exec -it pc-staff   curl -m 3 http://203.0.113.2:8080
# -> Ambas deben responder el HTML del ERP. Inspeccionar conntrack:
docker exec -it rtr-sede1 conntrack -L | grep 8080
```

**Drills "Break & Fix" del capstone (rompé y arreglá vos mismo):**

```bash
# DRILL A - MTU mismatch en el tunel (OSPF se traba en EXSTART):
docker exec -it rtr-sede2 ip link set mtu 1300 dev wg0
docker exec -it rtr-sede2 vtysh -c "clear ip ospf process"
docker exec -it rtr-sede1 vtysh -c "show ip ospf neighbor"   # -> ExStart/Exchange!
# Arreglo:
docker exec -it rtr-sede2 ip link set mtu 1420 dev wg0
docker exec -it rtr-sede2 vtysh -c "clear ip ospf process"

# DRILL B - "Triangulo roto" del Hairpin: borrar la regla srcnat y ver que desde adentro falla:
docker exec -it rtr-sede1 iptables -t nat -D POSTROUTING -s 10.1.40.0/24 -d 10.1.40.10 -p tcp --dport 8080 -j MASQUERADE
docker exec -it pc-staff curl -m 3 http://203.0.113.2:8080   # -> Timeout (aunque desde Internet anda!)
# Arreglo (volver a agregar la regla de Hairpin NAT):
docker exec -it rtr-sede1 iptables -t nat -A POSTROUTING -s 10.1.40.0/24 -d 10.1.40.10 -p tcp --dport 8080 -j MASQUERADE

# DRILL C - Verificar el MSS Clamping que evita el agujero negro de MTU por el tunel:
docker exec -it rtr-sede1 iptables -t mangle -S FORWARD      # -> regla TCPMSS --clamp-mss-to-pmtu

# 5. Apagar y limpiar el laboratorio al terminar:
docker compose -f labs/docker-compose.integrative.yml down
```

> **Nota de compatibilidad:** el túnel se levanta con **WireGuard** (`wg0`, MTU `1420`). Si el kernel del host no expone el módulo WireGuard a contenedores, el arranque cae automáticamente a un **túnel GRE** con el mismo nombre, direccionamiento y MTU, de modo que el ejercicio de OSPF y MSS se mantiene idéntico.

---

## 🎯 Modo Entrenamiento: "Break & Fix" — Guardia a Ciegas

Los laboratorios por sí solos no entrenan el diagnóstico: cuando **vos** rompés algo, ya sabés qué rompiste. El script [`break-and-fix.sh`](break-and-fix.sh) invierte eso: inyecta una falla **secreta** en un lab ya levantado y te entrega **solo el ticket del usuario**. Diagnostikás, arreglás y recién ahí verificás si de verdad resolviste la causa raíz.

```bash
sh labs/break-and-fix.sh list                 # Ver las 8 misiones (sin revelar la causa)
sh labs/break-and-fix.sh break 5              # Inyecta la falla 5 en silencio y muestra el ticket
sh labs/break-and-fix.sh hint 5               # Una pista de capa OSI (sin regalar el comando)
sh labs/break-and-fix.sh verify 5             # ✅ INCIDENTE RESUELTO  o  ❌ Aún falla + pista
```

| # | Laboratorio requerido | Síntoma del ticket |
|:-:|-----------------------|--------------------|
| 1 | `lab01-vlan-roas` | La PC de la VLAN 10 perdió acceso al servidor de la VLAN 20 |
| 2 | `lab03-ospf-and-vrrp` | OSPF trabado en `EXSTART` y la sucursal no aprende rutas |
| 3 | `lab03-ospf-and-vrrp` | La adyacencia OSPF no se forma (tipo de red del enlace) |
| 4 | `lab03-ospf-and-vrrp` | El tráfico al Data Center sale por el enlace lento |
| 5 | `lab04-nat-hairpin-mtu` | El ERP abre desde Internet pero **no** desde la oficina |
| 6 | `lab04-nat-hairpin-mtu` | Las descargas grandes se congelan (las chicas andan) |
| 7 | `docker-compose.integrative.yml` | El túnel está `UP`, pero la sucursal ve todo con la misma IP |
| 8 | `lab03-ospf-and-vrrp` | OSPF se cayó de golpe en un router (el ping directo anda) |

**Ejemplo completo (misión 5):**

```bash
# 1. Levantar el laboratorio de la misión y esperar a que esté listo:
docker compose -f labs/docker-compose.lab04-nat-hairpin-mtu.yml up -d

# 2. Inyectar la falla secreta y leer solo el ticket:
sh labs/break-and-fix.sh break 5

# 3. Diagnosticar y reparar (mirá la pista de capa OSI si te trabás):
sh labs/break-and-fix.sh hint 5
docker exec -it lab04-fw-borde iptables -t nat -S

# 4. Comprobar si el incidente quedó resuelto:
sh labs/break-and-fix.sh verify 5
docker compose -f labs/docker-compose.lab04-nat-hairpin-mtu.yml down
```

> El script es **POSIX `sh`** (`set -eu`, sin *bashismos*), compatible con `/bin/sh` y pensado para pasar `shellcheck`. Cada `verify` corre una sonda real (`ping`, `curl`, `vtysh -c "show ip ospf neighbor"`, `iptables -S`) y devuelve código de salida `0` si arreglaste el incidente.

---

## 🔗 Ver también

- [`guides/README.md`](../guides/README.md) — Las 24 guías de configuración multi-vendor que explican cada protocolo practicado aquí
- [`scenarios/README.md`](../scenarios/README.md) — Los 21 runbooks de incidentes reales que podés simular en estos contenedores
- [`scenarios/maintenance/04-integrative-capstone-enterprise-network.md`](../scenarios/maintenance/04-integrative-capstone-enterprise-network.md) — El Proyecto Integrador Capstone que este Lab 05 ejecuta de punta a punta

⬅️ [Volver al README principal](../README.md)
