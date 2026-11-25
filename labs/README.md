⬅️ [Volver al README principal](../README.md)

# 🧪 Laboratorios Prácticos de Redes (`labs/`)

Topologías reproducibles con **Docker Compose**, **FRRouting (`vtysh` estilo Cisco IOS)**, **Linux Bridge (`802.1Q` / `RSTP`)** y **`nftables` / `iptables` (`Conntrack`)** para practicar configuración, captura de paquetes con `tcpdump` y resolución de incidentes reales en cualquier computadora sin necesidad de hardware físico.

---

## 🗂️ Los 4 Entornos de Laboratorio Incluidos

| Lab | Archivo Docker Compose | Qué vas a practicar en vivo |
|:---:|------------------------|-----------------------------|
| **01** | [`docker-compose.lab01-vlan-roas.yml`](docker-compose.lab01-vlan-roas.yml) | Etiquetas **VLAN `802.1Q`**, captura de tags con `tcpdump -ni eth0 -e vlan` y enrutamiento **Router-on-a-Stick (ROAS)** entre la `VLAN 10` y la `VLAN 20` |
| **02** | [`docker-compose.lab02-stp-and-lacp.yml`](docker-compose.lab02-stp-and-lacp.yml) | **Spanning Tree (`STP`)**, elección del **Root Bridge (`Priority 4096 vs 32768`)**, inspección de tramas BPDU (`01:80:C2:00:00:00`) y **Bonding LACP `802.3ad`** |
| **03** | [`docker-compose.lab03-ospf-and-vrrp.yml`](docker-compose.lab03-ospf-and-vrrp.yml) | **3 Routers con consola `vtysh` (idéntica a Cisco IOS)** corriendo **OSPFv2 (`Area 0`)**, simulación de caída de fibra (failover por costo `10` vs `100`) y reproducción del fallo **`ExStart` por diferencia de MTU** |
| **04** | [`docker-compose.lab04-nat-hairpin-mtu.yml`](docker-compose.lab04-nat-hairpin-mtu.yml) | **Port Forwarding (`DNAT`)**, reproducción del **"Triángulo Roto" del Hairpin NAT** (funciona desde `cliente-externo` pero falla desde `pc-interna`), solución en 1 línea, inspección de **Conntrack** y **TCP MSS Clamping** |

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

## 🔗 Ver también

- [`guides/README.md`](../guides/README.md) — Las 24 guías de configuración multi-vendor que explican cada protocolo practicado aquí
- [`scenarios/README.md`](../scenarios/README.md) — Los 20 runbooks de incidentes reales que podés simular en estos contenedores

⬅️ [Volver al README principal](../README.md)
