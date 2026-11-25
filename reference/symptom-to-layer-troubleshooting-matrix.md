⬅️ [Volver a Referencias](README.md)

# 📚 Matriz de Guardia: Síntoma → Capa OSI → Primer Comando → Causa Raíz

**Alcance:** `Troubleshooting Multi-Vendor (Capas 1 a 7)` | `Cisco IOS` · `MikroTik RouterOS v7` · `Aruba / Switches` · `Linux`

---

## 🎯 Cómo usar esta referencia

Cuando suena el teléfono o salta una alerta en plena guardia, buscá en la columna izquierda el **síntoma exacto que reporta el usuario o el monitoreo**. La tabla te indica en qué capa OSI está la falla, qué comando ejecutar primero sin perder tiempo y cuál es la causa raíz en el 95% de los casos.

---

## 📊 1. Problemas de Capa 1 (Física, Cobre, Fibra SFP y PoE)

| Síntoma Observado | Capa | Primer Comando (Cisco / MikroTik / Linux) | Qué buscar en la salida | Causa Raíz Más Probable y Acción |
|-------------------|:----:|-------------------------------------------|-------------------------|----------------------------------|
| **Un puerto Gigabit negocia solo a `100 Mbps` (o baja de `1G` a `100M` solo)** | **L1** | Cisco: `test cable-diagnostics tdr interface Gi1/0/1` \| MikroTik: `/interface ethernet cable-test ether1` \| Linux: `ethtool eth0` | Un par figura `open` o `short` en los pines **`4–5` (Azul)** o **`7–8` (Marrón)** | **Hilo cortado o ficha RJ45 sulfatada:** `100 Mbps` usa solo 2 pares (`1,2,3,6`), `1 Gbps` exige los 4 pares. Recrimpar ficha o cambiar patchcord |
| **El enlace figura `UP`, el ping liviano da `1 ms`, pero copiar archivos va a `< 1 Mbps`** | **L1** | Cisco: `show interfaces Gi1/0/1` \| MikroTik: `/interface ethernet monitor ether1` \| Linux: `ip -s link show eth0` | Un extremo dice `Full-duplex` y el otro `Half-duplex`; suben `CRC / FCS` y `Late Collisions` | **Duplex Mismatch** (alguien forzó un lado manual y dejó el otro en `Auto`) o cable UTP pasando pegado a un motor/trifásica. Poner ambos en **`Auto-Negotiation`** |
| **Enlace de fibra óptica recién conectado queda en `Link Down` en ambos switches** | **L1** | Cisco: `show interfaces Gi1/0/25 transceiver detail` \| MikroTik: `/interface ethernet monitor sfp-sfpplus1` | `TX Power` está en `-3 dBm`, pero **`RX Power` marca `-40 dBm` (`rx-los: yes`)** | **Los dos pelos del patchcord LC están sin cruzar (`TX` mirando a `TX`)** o se mezcló un SFP Monomodo (`1310nm`) con otro Multimodo (`850nm`). Destrabar clip LC e invertir los 2 hilos en una punta |
| **Enlace de fibra óptica entre edificios sufre microcortes cuando hay viento o humedad** | **L1** | MikroTik: `/interface ethernet monitor sfp-sfpplus1` \| Aruba: `show interfaces transceiver detail` | `RX Power` está entre **`-22 dBm` y `-26 dBm`** (al borde del corte `LOS`) | **Atenuación óptica excesiva:** conector LC sucio con polvo, patchcord de fibra estrangulado/doblado en el rack o agua en caja de empalme exterior |
| **Las cámaras IP exteriores o APs funcionan de día pero se reinician en bucle toda la noche** | **L1** | Cisco: `show power inline` \| MikroTik: `/interface ethernet poe monitor ether1` | Consumo total al `100%` del presupuesto del switch (`overload` / `POWER_DENY`) o voltaje `< 44V` | **De noche se encienden los LEDs infrarrojos (IR)** duplicando el consumo en Watts y agotando la fuente del switch PoE (o cable CCA de mala calidad con caída de tensión) |

---

## 📊 2. Problemas de Capa 2 (Switching, Tabla MAC, ARP, VLANs, RSTP y LACP)

| Síntoma Observado | Capa | Primer Comando (Cisco / MikroTik / Linux) | Qué buscar en la salida | Causa Raíz Más Probable y Acción |
|-------------------|:----:|-------------------------------------------|-------------------------|----------------------------------|
| **Toda la red colapsa de golpe: todos los LEDs parpadean fijos, ping `> 1500 ms` y CPU al 100%** | **L2** | Cisco: `show logging` + `show interfaces counters rate` \| MikroTik: `/log print` + `/interface print stats` | Alerta de **`MAC Flapping`** entre 2 puertos y tráfico Broadcast a `100–950 Mbps` en una boca | **Tormenta de Broadcast por bucle físico L2:** alguien conectó un cable entre dos bocas de pared o un switch chico en bucle. Apagar el puerto que trae el broadcast y activar `RSTP + BPDU Guard + Loop Protect` |
| **Un piso o escritorio entero se queda sin red de golpe y la luz del puerto en el switch está apagada** | **L2** | Cisco: `show interfaces status err-disabled` \| MikroTik: `/interface bridge port monitor [find]` | El puerto figura en estado **`err-disabled (bpduguard)`** o `loop-protect: disabled` | **Actuó la protección anti-bucles:** enchufaron un switch no autorizado o cerraron un lazo en ese puerto. Retirar el bucle físico y reactivar el puerto (`shutdown` / `no shutdown`) |
| **La PC dice "Conectado / Red no identificada" y tiene asignada la IP `169.254.x.x`** | **L2/L7** | Cisco: `show interfaces trunk` \| MikroTik: `/interface bridge vlan print` + `/interface bridge port print` | El puerto de acceso tiene el **`PVID`** equivocado o falta la VLAN como **`tagged`** en el Trunk al router | **La trama `DHCP Discover` no llega al router:** revisar que el puerto de la PC tenga `PVID = <VLAN>` y que todos los trunks intermedios permitan esa VLAN |
| **Una impresora o servidor responde al ping durante 2 minutos, se corta 2 minutos y vuelve sola** | **L2** | Router MikroTik: `/ip arp print where address=10.1.10.200` \| Cisco: `show ip arp 10.1.10.200` | Al limpiar la entrada ARP, **la misma IP alterna entre dos direcciones MAC de fabricantes distintos** | **Conflicto de IP Duplicada:** dos equipos en la misma VLAN tienen puesta la misma IP. Buscar la MAC intrusa en la tabla CAM del switch (`show mac address-table address <MAC>`) para saber en qué puerto está enchufada |
| **La mitad de las PCs de la oficina reciben IP `192.168.0.x` o `192.168.1.x` y no navegan** | **L2/L7** | Desde PC afectada: `arp -a` (mirar MAC de `192.168.0.1`) → en Switch: buscar esa MAC en la tabla CAM | La MAC del falso gateway pertenece a un router hogareño (TP-Link/Tenda/Mercusys) en una boca de oficina | **Rogue DHCP Server:** alguien conectó un router WiFi doméstico por su puerto LAN a la red. Desconectarlo del puerto indicado por la tabla MAC y activar **`DHCP Snooping`** |
| **Armaste un LACP de 2 cables entre switches y se pierde exactamente el 50% de los pings** | **L2** | Cisco: `show etherchannel summary` \| MikroTik: `/interface bonding monitor bond1` \| Aruba: `show lacp` | Un extremo fue puesto en modo estático (`mode on` / `balance-rr`) y el otro no tiene LACP o tiene RSTP bloqueando 1 cable | **Incompatibilidad de modo LAG:** nunca usar `mode on`. Configurar **`LACP 802.3ad` (`mode active`)** en ambos extremos y aplicar las VLANs a la interfaz lógica (`Po1 / bond1 / trk1`) |

---

## 📊 3. Problemas de Capa 3 (Enrutamiento, Subredes, OSPF, VRRP y Multi-WAN)

| Síntoma Observado | Capa | Primer Comando (Cisco / MikroTik / Linux) | Qué buscar en la salida | Causa Raíz Más Probable y Acción |
|-------------------|:----:|-------------------------------------------|-------------------------|----------------------------------|
| **Desde el Router A el ping a la Sucursal B funciona, pero desde las PCs detrás del Router A no llega** | **L3** | En el **Router B (remoto)**: `/ip route check 10.1.10.50` \| Cisco: `show ip route 10.1.10.50` | El Router B **no tiene ruta de vuelta** hacia la LAN `10.1.10.0/24` del Router A (o una regla de `masquerade` mal hecha pisa el tráfico) | **Falta la ruta de retorno:** cuando el Router A hace ping usa la IP del túnel `/30` (que B sí conoce), pero cuando una PC hace ping usa su IP `10.1.10.50`. Agregar la ruta hacia `10.1.10.0/24` en el Router B |
| **El tráfico se va por el enlace de backup lento en vez de usar el enlace principal rápido** | **L3** | MikroTik: `/ip route print where dst-address in 10.2.0.0/16` \| Cisco: `show ip route` | El enlace lento anuncia una máscara **más específica (`/24`)** mientras el enlace principal tiene una **`/16`** | **Ley #1: *Longest Prefix Match*:** una ruta `/24` (aunque tenga `AD = 110` de OSPF) siempre le gana a una `/16` (aunque tenga `AD = 1` estática). Igualar las máscaras en ambos enlaces |
| **Dos routers se ven por ping en su enlace directo, pero OSPF queda trabado en `ExStart` o `Exchange`** | **L3** | Cisco: `show ip ospf neighbor` \| MikroTik: `/routing ospf neighbor print` | El estado del vecino nunca llega a `Full` y se reinicia desde `ExStart` | **Diferencia de MTU en Capa 3 entre las dos interfaces** (ej. un lado tiene `1500` y el otro `1492` o `1508`). Igualar el IP MTU exacto en ambos extremos del enlace |
| **Dos routers con VRRP pierden paquetes de forma intermitente hacia la IP Virtual `.1`** | **L3** | MikroTik: `/interface vrrp print` en ambos routers \| Cisco: `show vrrp brief` | **Ambos routers dicen que son `Master (RM)` al mismo tiempo** (*Split-Brain*) | **Los latidos Multicast `224.0.0.18` (Protocolo IP `112`) no cruzan entre ambos routers:** revisar que la VLAN esté permitida en el switch, que `INPUT` permita `protocol=vrrp` y que coincida la versión VRRP |
| **Se cortó Internet en el proveedor principal, pero el router no cambia al proveedor secundario** | **L3** | MikroTik: `/ip route print detail` \| Cisco: `show ip sla statistics` | La interfaz `ether1-wan1` sigue `Running (R)` porque el cable al módem del ISP está enchufado | **ISP Zombie:** el enlace eléctrico con el módem sigue `UP`, pero el corte está en la calle. Configurar **Rutas Recursivas (`check-gateway=ping` hacia `1.1.1.1` / `8.8.8.8`)** o *IP SLA / Netwatch* |

---

## 📊 4. Problemas de Capas 4 a 7 (MTU/MSS, NAT, Firewall, DNS y NTP)

| Síntoma Observado | Capa | Primer Comando (Cisco / MikroTik / Linux) | Qué buscar en la salida | Causa Raíz Más Probable y Acción |
|-------------------|:----:|-------------------------------------------|-------------------------|----------------------------------|
| **El `ping 8.8.8.8` y Google funcionan, pero los bancos y webs HTTPS pesadas quedan cargando en blanco** | **L3/L4** | MikroTik: `/ping 8.8.8.8 size=1500 do-not-fragment` \| Linux: `ping -M do -s 1472 8.8.8.8` | El ping de `64B` pasa, pero el de `1500B` sin fragmentar falla con **`packet too large`** en un enlace PPPoE o VPN | **Agujero negro de MTU/MSS (*PMTUD Blackhole*):** el enlace tiene MTU `1492` (PPPoE) o `1420` (VPN) y un firewall bloquea ICMP. Activar **TCP MSS Clamping (`change-mss=clamp-to-pmtu`)** en `mangle forward` |
| **Abriste un puerto por `DNAT` (Port Forwarding), pero desde Internet nadie puede conectarse** | **L3/L4** | MikroTik: `/ip address print where interface=ether1-wan` + `/ip firewall nat print stats` | La IP de la boca WAN empieza con **`100.64.x.x` a `100.127.x.x`** y el contador de paquetes de la regla `dst-nat` está en `0` | **Tu proveedor te dio una IP de CGNAT (`100.64.0.0/10`):** los paquetes mueren en el ISP y nunca llegan a tu router. Pedir IP pública real al ISP o usar un túnel WireGuard saliente |
| **El servidor publicado abre perfecto desde el celular por 4G, pero desde el WiFi de la oficina no carga** | **L4/L7** | Desde PC interna: `nslookup sistema.empresa.com` (devuelve la IP Pública WAN de la propia oficina) | La PC interna habla a la IP pública de su propio router y el servidor le contesta directo por Capa 2 (*Triángulo Roto*) | **Falta Split-Horizon DNS o Hairpin NAT:** crear un registro DNS estático en el router local apuntando `sistema.empresa.com` a su IP privada `10.1.40.10` (o agregar regla de *Hairpin NAT*) |
| **Las conexiones entre dos VLANs internas se establecen pero se cortan exactamente a los 30 segundos** | **L3/L4** | MikroTik: `/ip firewall filter print stats` (mirar contador de la regla `drop invalid` en `forward`) | El contador de **`drop invalid`** sube con cada paquete de esa conexión | **Enrutamiento Asimétrico:** la ida va directo por un switch L3 y la vuelta pasa por el firewall (que no vio el `SYN` inicial y mata los `ACK` como `INVALID`). Corregir rutas para que ida y vuelta pasen por el mismo equipo |
| **`ping 1.1.1.1` responde en `5 ms`, pero `ping google.com` o el navegador dicen que no hay Internet** | **L7** | Desde PC: `nslookup google.com` / `dig google.com` \| En Router: `/ip dns print` | Timeout al consultar al servidor DNS o error `SERVFAIL / REFUSED` | **Falla 100% de DNS:** o bien la regla `INPUT` del firewall del router está bloqueando el puerto `UDP/TCP 53` a esa VLAN, o los servidores DNS upstream configurados están caídos |
| **Después de un corte de luz, Internet anda pero no levanta ningún túnel WireGuard ni valida HTTPS** | **L7** | MikroTik: `/system clock print` + `/system ntp client print` \| Linux: `timedatectl` | La fecha del router dice **`1970-01-02`** (o está desfasada por horas/días) | **Reloj sin sincronizar por NTP:** WireGuard rechaza handshakes con timestamps viejos y TLS rechaza certificados "del futuro". Configurar cliente NTP usando IPs directas (`162.159.200.1`) |

---

## ⚡ Comandos rápidos de verificación (La Secuencia de Oro en 30 Segundos)

```text
# 1. ¿Tengo Capa 1 y Capa 2 hasta mi Gateway? (Linux / PC)
ip -br link && ip -br addr && ip neigh show

# 2. ¿Tengo Capa 3 hasta mi Gateway y hasta Internet por IP?
ping -c 3 10.1.10.1 && ping -c 3 1.1.1.1

# 3. ¿Tengo el MTU sano sin fragmentación hasta Internet?
ping -c 3 -M do -s 1472 1.1.1.1

# 4. ¿Tengo Capa 7 (Resolución DNS y salida HTTPS)?
dig +short google.com && curl -I https://one.one.one.one
```

---

## 🔗 Ver también

- [`how-to-think-like-network-engineer`](../concepts/how-to-think-like-network-engineer.md) — Metodologías *Bottom-Up*, *Divide & Conquer* y *Follow-the-Path*
- [`multivendor-cli-rosetta-stone`](multivendor-cli-rosetta-stone.md) — Traducción exacta de cada comando de diagnóstico entre Cisco, MikroTik, Aruba y Linux
