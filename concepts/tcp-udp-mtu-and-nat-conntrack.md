⬅️ [Volver a Conceptos](README.md)

# TCP, UDP, MTU/MSS y NAT (Conntrack) — Por qué los paquetes se congelan y cómo salen a Internet

**Capa OSI principal:** Capas 3 y 4 (Red y Transporte) | **Estándares:** `RFC 9293 (TCP)`, `RFC 768 (UDP)`, `RFC 1191 (PMTUD)`, `RFC 3022 (NAT/PAT)`

---

## 🧠 ¿Qué es?

Una vez que la Capa 3 (IP) sabe cómo llevar un paquete de un router a otro, la **Capa 4 (Transporte)** se encarga de dos cosas fundamentales: **identificar a qué aplicación específica dentro del servidor va dirigido el paquete mediante un número de Puerto (`0–65535`)** y decidir si esa entrega debe ser **garantizada y ordenada (`TCP`)** o **instantánea y sin demoras (`UDP`)**.

En el borde de toda red moderna, las Capas 3 y 4 trabajan fusionadas en dos mecanismos críticos que todo ingeniero debe dominar a la perfección:

1. **La relación `MTU` (Capa 3) vs `MSS` (Capa 4):** El tamaño máximo de paquete que entra por un enlace (Ethernet `1500 B`, PPPoE `1492 B`, WireGuard `1420 B`) y por qué cuando falla causa el incidente más desconcertante de las redes: *"el ping funciona, Google abre, pero los bancos y sitios HTTPS pesados se quedan congelados en blanco"*.
2. **NAT (*Network Address Translation*) y la tabla *Conntrack*:** El mecanismo por el cual un router traduce las direcciones IP privadas internas (`RFC 1918`) a una única IP pública en Internet llevando un registro exacto de cada conversación en memoria.

---

## 🎯 ¿Por qué importa en el día a día?

Si no entendés el handshake de TCP, el cálculo de `MTU / MSS` y cómo reescribe paquetes el NAT, vas a perder días enteros culpando al DNS o al proveedor de Internet por problemas que se resuelven con **una sola regla de 1 línea en tu router**.

- **En diseño:** Te obliga a configurar **TCP MSS Clamping** siempre que uses un enlace WAN por **PPPoE** o levantes un túnel VPN (**WireGuard, IPsec, GRE, EoIP**).
- **En operación/mantenimiento:** Entender cómo funciona la tabla **Conntrack** te explica por qué si cambiás una regla de NAT o una ruta de salida WAN, las conexiones viejas (como teléfonos VoIP UDP o cámaras) siguen intentando salir por el proveedor viejo caído hasta que limpiás sus estados en Conntrack.
- **En troubleshooting:** Te permite resolver en 2 minutos el clásico problema del **Hairpin NAT** (*"publique el servidor por Port Forwarding y desde el celular por 4G entra perfecto, pero desde las PCs adentro de la misma oficina no carga"*).

---

## ⚙️ Cómo funciona por dentro

### 1. TCP vs UDP y el saludo de 3 pasos (*3-Way Handshake*)

```text
TCP (Orientado a conexión, confiable, negocia MSS):       UDP (Sin conexión, fuego y olvido, tiempo real):
[Cliente]                              [Servidor:443]     [Cliente]                              [Servidor:53]
    |  1. SYN (Seq=0, MSS=1460)               |               |  1. Datagrama UDP (Consulta DNS)       |
    +---------------------------------------->|               +--------------------------------------->|
    |  2. SYN-ACK (Seq=0, Ack=1, MSS=1460)    |               |  2. Datagrama UDP (Respuesta DNS)      |
    |<----------------------------------------+               |<---------------------------------------+
    |  3. ACK (Seq=1, Ack=1) -> ¡ESTABLISHED! |               (Sin saludo previo, sin acuse de recibo,
    +---------------------------------------->|                sin retransmisión en Capa 4)
```

| Característica | TCP (Protocolo IP `6`) | UDP (Protocolo IP `17`) |
|----------------|------------------------|-------------------------|
| **Garantía y orden** | ✅ **Total:** numera cada byte (`Seq`), exige acuse de recibo (`Ack`), reenvía lo que se pierde y frena si el receptor se satura (*Window Size*) | ❌ **Ninguna en Capa 4:** envía el paquete de una vez; si se pierde en el cable, no se detiene a reenviarlo |
| **Tamaño de cabecera** | `20 bytes` (hasta `60 bytes` con opciones como `MSS`, `SACK`, `Timestamps`) | `8 bytes` fijos (`Puerto Origen`, `Puerto Destino`, `Longitud`, `Checksum`) |
| **Dónde se usa** | Web (`HTTP/1.1`, `HTTP/2`), `SSH (22)`, `BGP (179)`, bases de datos (`5432`, `3306`), correo (`SMTP/IMAP`), `SMB (445)` | `DNS (53)`, `DHCP (67/68)`, `NTP (123)`, `SNMP (161)`, `Voz VoIP (RTP)`, `Video RTSP`, **`WireGuard (51820)`**, `HTTP/3 (QUIC)` |

---

### 2. El misterio del `MTU` vs `MSS` (Por qué el Ping anda pero las páginas HTTPS no abren)

En una placa Ethernet normal, el paquete IP más grande que entra en una trama es **`MTU = 1500 bytes`** (*Maximum Transmission Unit*). Si le restamos los `20 bytes` de la cabecera IPv4 y los `20 bytes` de la cabecera TCP, el espacio libre para datos reales en cada segmento TCP es **`MSS = 1460 bytes`** (*Maximum Segment Size*):

$$\text{MSS} = \text{MTU} - 20\text{ B (Header IP)} - 20\text{ B (Header TCP)}$$

**¿Qué pasa cuando tu conexión a Internet es PPPoE o pasa por una VPN WireGuard/IPsec?**
Esos protocolos envuelven tu paquete agregándole sus propias cabeceras extra, **achicando el tubo disponible (`MTU`)**:

| Tipo de Enlace | Overhead que agrega | MTU real del enlace | MSS máximo que entra sin fragmentar |
|----------------|---------------------|:-------------------:|:-----------------------------------:|
| **Ethernet estándar (LAN / Fibra IP directa)** | `0 bytes` extra en L3 | **`1500 bytes`** | **`1460 bytes`** (`1500 - 40`) |
| **PPPoE (Proveedores de Fibra FTTH / ADSL)** | `8 bytes` (PPP + PPPoE) | **`1492 bytes`** | **`1452 bytes`** (`1492 - 40`) |
| **Túnel VPN WireGuard (sobre IPv4)** | `60 bytes` (IP + UDP + WG) | **`1420 bytes`** | **`1380 bytes`** (`1420 - 40`) |
| **Túnel VPN IPsec (ESP + UDP NAT-T)** | `~60 a 80 bytes` | **`1400 bytes`** | **`1360 bytes`** (`1400 - 40`) |

```text
EL AGUJERO NEGRO DE MTU (PMTUD Blackhole):
==================================================================================================
[PC en LAN]                       [Tu Router]                        [Servidor HTTPS del Banco]
MTU = 1500                        WAN PPPoE / VPN: MTU = 1420        MTU = 1500
     |                                 |                                  |
     | 1. Ping 8.8.8.8 (64 bytes) ---->|---------(64B <= 1420B)---------->| -> ¡EL PING FUNCIONA!
     | 2. TCP SYN (Anuncia MSS=1460) ->|---------(60B <= 1420B)---------->| -> ¡EL HANDSHAKE CONECTA!
     |                                 |                                  |
     |                                 |   3. El Banco envía el Certificado TLS (Paquete de 1500B
     |                                 |      con el bit DF=1 "Prohibido Fragmentar"):
     |                                 |   <----- X ¡NO ENTRA EN 1420B! (El router lo descarta y
     |                                 |             manda aviso ICMP "Frag Needed: bajá a 1420".
     |                                 |             Si un firewall bloquea ese ICMP, el Banco sigue
     |                                 |             reintentando a 1500B y la página QUEDA EN BLANCO!)
```

**La solución definitiva (*TCP MSS Clamping*):**
En lugar de depender de que ningún firewall en Internet bloquee los avisos ICMP de fragmentación (**PMTUD**), configurás en tu router una regla de **MSS Clamping (`change-mss`)**. Cuando el paquete #1 (`TCP SYN`) de tu PC pasa por el router diciendo *"Mi MSS es 1460"*, el router intercepta ese `SYN` al vuelo y **le tacha el `1460` escribiendo `1380` (o `clamp-to-pmtu`)**. Así el servidor del banco jamás enviará paquetes mayores a `1420 bytes` y ninguna página volverá a congelarse.

---

### 3. La tabla Connection Tracking (*Conntrack*) y los 4 tipos de NAT

Cuando tenés 100 PCs con IPs privadas (`10.1.10.x`) saliendo a Internet con **una sola IP pública (`190.210.50.10`)**, ¿cómo sabe el router a cuál de las 100 PCs devolverle cada paquete que regresa desde Google? Gracias a la tabla **Conntrack** que anota el **Puerto Efímero de Origen**:

```text
TABLA CONNTRACK EN LA MEMORIA DEL ROUTER:
+-------+--------------------+--------------------+----------------------+----------------------+-----------+
| Proto | IP:Puerto Original | Destino Original   | IP:Puerto Traducido  | Respuesta Esperada   | Estado    |
+-------+--------------------+--------------------+----------------------+----------------------+-----------+
| TCP   | 10.1.10.51 : 54111 | 142.250.1.1 : 443  | 190.210.50.10 : 54111| 142.250.1.1 -> :54111|ESTABLISHED|
| TCP   | 10.1.10.52 : 60222 | 142.250.1.1 : 443  | 190.210.50.10 : 60222| 142.250.1.1 -> :60222|ESTABLISHED|
+-------+--------------------+--------------------+----------------------+----------------------+-----------+
```

#### Los 4 tipos de NAT que se usan en producción

| Tipo de NAT | Qué modifica el Router | Cuándo y para qué se usa |
|-------------|------------------------|--------------------------|
| **1. Source NAT / Masquerade (`SNAT / PAT`)** | Al **salir** hacia la WAN, cambia la **IP Origen privada** de la PC por la **IP Pública** del router | Para que toda la red interna pueda navegar por Internet. (**`masquerade`**: si la IP WAN es dinámica por DHCP/PPPoE; **`src-nat`**: si la IP WAN es pública fija, porque consume menos CPU y no purga toda la tabla Conntrack al microcortarse el enlace) |
| **2. Destination NAT (`DNAT` / *Port Forwarding*)** | Al **entrar** desde la WAN al puerto `X`, cambia la **IP Destino pública** por la **IP Privada** del servidor interno (`10.1.40.10`) | Para publicar hacia Internet un servidor web interno, un grabador NVR de cámaras o un puerto VPN específico |
| **3. NAT 1:1 (`Static NAT` / `netmap`)** | Vincula de forma exclusiva una IP Pública extra (`190.210.50.11`) con un servidor interno (`10.1.40.11`) tanto de entrada como de salida | Cuando tenés un bloque `/29` de IPs públicas y querés que tu servidor de correo o telefonía salga y entre siempre con su propia IP pública dedicada |
| **4. Hairpin NAT (*NAT Loopback*)** | Aplica **`DNAT` + `SNAT` al mismo tiempo** cuando un usuario **dentro de la LAN** intenta entrar al servidor local usando la **IP Pública / Dominio externo** | Evita el *"triángulo roto"* cuando un empleado abre en su celular la app de cámaras o el sistema web con la dirección pública estando conectado al WiFi de la propia oficina |

#### ¿Por qué sin *Hairpin NAT* falla el acceso desde adentro de la oficina? (El Triángulo Roto)

```text
[PC en la Oficina: 10.1.10.50]                    [Router: LAN 10.1.10.1 | WAN 190.210.50.10]
              |                                                    |
              | 1. Pide ir a la IP Pública 190.210.50.10:443 ----->| (El Router hace DNAT y cambia el destino
              |                                                    |  a 10.1.10.10, pero DEJA la IP Origen
              |                                                    |  10.1.10.50 intacta)
              |                                                    v
              | 3. El Servidor ve que quien preguntó es       [Servidor Web Local: 10.1.10.10]
              |    10.1.10.50 (¡su mismo switch!) y le
              |    CONTESTA DIRECTO por Capa 2 sin pasar
              |<--- por el Router (Origen: 10.1.10.10) -----------+
              |
   ¡ERROR EN LA PC! "Yo le hablé a 190.210.50.10, ¿por qué me contesta 10.1.10.10? -> TCP RST (Rechazado)!"
   (Con HAIRPIN NAT o SPLIT-DNS, obligás a que la respuesta vuelva por el Router o que la PC vaya directo a la IP local).
```

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

| Operación Capa 4 / NAT | Cisco IOS / IOS-XE | MikroTik RouterOS v7 | Linux (`nftables` / `iptables`) |
|------------------------|--------------------|----------------------|---------------------------------|
| **Source NAT con IP WAN dinámica** | `ip nat inside source list 1 interface Gi0/0 overload` | `/ip firewall nat add chain=srcnat out-interface-list=WAN action=masquerade` | `nft add rule ip nat postrouting oifname "eth0" masquerade` |
| **Source NAT con IP WAN pública fija** | `ip nat inside source list 1 pool MI-IP overload` | `/ip firewall nat add chain=srcnat out-interface=ether1 action=src-nat to-addresses=190.210.50.10` | `nft add rule ip nat postrouting oifname "eth0" snat to 190.210.50.10` |
| **Port Forwarding (`DNAT`) al puerto 443** | `ip nat inside source static tcp 10.1.40.10 443 interface Gi0/0 443` | `/ip firewall nat add chain=dstnat in-interface-list=WAN protocol=tcp dst-port=443 action=dst-nat to-addresses=10.1.40.10` | `nft add rule ip nat prerouting iifname "eth0" tcp dport 443 dnat to 10.1.40.10:443` |
| **TCP MSS Clamping automático (PPPoE / VPN)** | En la interfaz túnel/WAN: `ip tcp adjust-mss 1380` | `/ip firewall mangle add chain=forward protocol=tcp tcp-flags=syn action=change-mss new-mss=clamp-to-pmtu` | `iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu` |
| **Ver tabla de conexiones Conntrack / NAT** | `show ip nat translations` | `/ip firewall connection print` | `conntrack -L` |
| **Probar el MTU real de un camino sin fragmentar** | `ping 8.8.8.8 size 1500 df-bit` | `/ping 8.8.8.8 size=1500 do-not-fragment` | `ping -M do -s 1472 8.8.8.8` *(en Linux `1472 + 20 IP + 8 ICMP = 1500`)* |

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Prueba de ping con `do-not-fragment` a `1500B` vs `1420B`** | `size=1500` (o `1492` en PPPoE) responde sin errores | `size=1400` responde `0.5 ms`, pero `size=1500` devuelve **`packet too large and cannot be fragmented`** y las webs HTTPS se cuelgan | **Problema de MTU / Falta TCP MSS Clamping** en la interfaz PPPoE o en el túnel VPN |
| **Acceso a un servidor publicado (`DNAT`) desde 4G vs desde el WiFi local** | Abre tanto desde afuera como desde adentro de la oficina | Desde 4G abre al instante; desde adentro de la oficina da *Connection Timed Out* o *Connection Reset* | Falta configurar **Split-Horizon DNS** (para que adentro resuelva a la IP privada) o una regla de **Hairpin NAT** |
| **Teléfonos VoIP (SIP/UDP) tras un corte y cambio al ISP 2 de backup** | Los teléfonos se registran inmediatamente por el ISP 2 | Internet navega por el ISP 2, pero **los teléfonos VoIP quedan muertos** hasta que los desenchufás | **Entrada UDP vieja clavada en Conntrack:** como el teléfono SIP sigue mandando paquetes UDP cada 10s, el router renueva la entrada vieja en Conntrack con la IP pública del ISP 1 muerto. Hay que limpiar Conntrack en el script de failover |
| **Uso de la tabla Conntrack (`total-entries` vs `max-entries`)** | `< 20%` del límite máximo de la tabla | `100%` llena (`nf_conntrack: table full, dropping packet`) | **Torrente P2P masivo, escaneo de puertos o ataque SYN Flood** agotando las entradas de seguimiento de conexiones |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Poner `action=masquerade` sin especificar `out-interface=WAN` (o `out-interface-list=WAN`):** Si creás una regla de `srcnat` con `action=masquerade` y te olvidás de decirle que **solo se aplique cuando el paquete sale hacia Internet (`WAN`)**, el router va a enmascarar **todo el tráfico interno entre tus VLANs y tus túneles VPN**. Como resultado, tus servidores internos verán que todas las conexiones vienen de la IP `.1` del router (perdiendo la auditoría de qué PC entró) y romperás el acceso desde las sucursales VPN.
- **❌ Creer que en Linux `ping -s 1500` envía un paquete IP de 1500 bytes:**
  - ¡Cuidado con esta diferencia crítica entre consolas! En **Cisco y MikroTik**, `size=1500` incluye las cabeceras (`1472 datos + 20 IP + 8 ICMP = 1500 bytes totales`).
  - En **Linux / macOS / Windows**, el parámetro `-s` (`-l` en Windows) indica **solo el payload de datos ICMP**, a lo cual el sistema le suma `28 bytes` (`20B` IP + `8B` ICMP). Por lo tanto, para probar un MTU de `1500` desde Linux debés escribir **`ping -M do -s 1472 <IP>`** (`1472 + 28 = 1500`).
- **❌ Bloquear todo el protocolo ICMP en el firewall "por seguridad":** Si bloqueás todos los paquetes ICMP indiscriminadamente, bloqueás el mensaje **`ICMP Type 3 Code 4 (Fragmentation Needed)`**, rompiendo *Path MTU Discovery (PMTUD)* para todos tus servidores y túneles.

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

Se conecta una sucursal remota con Casa Central mediante un túnel VPN sobre un proveedor de fibra FTTH por PPPoE. Desde las PCs de la sucursal hacen `ping 10.1.40.10` (servidor ERP en Casa Central) y responde en `8 ms` con `0%` de pérdida. Incluso pueden entrar por SSH al servidor. Pero **cuando abren el sistema ERP web (`https://10.1.40.10`) o intentan abrir una carpeta compartida con archivos grandes, la pantalla queda cargando infinitamente hasta dar Timeout**.

### Análisis paso a paso por capas

1. **Síntoma observado:** Los paquetes chicos (Ping de 64B, saludo inicial de SSH) pasan perfecto de punta a punta, pero cualquier transferencia de datos grandes (certificado TLS del ERP web o archivos SMB) se congela en seco.
2. **Hipótesis usando el modelo mental (Síntoma clásico de agujero negro de MTU / MSS):**
   - Cuando "lo chiquito pasa y lo grande se congela", el culpable es **100% de las veces el MTU/MSS**.
   - La fibra PPPoE tiene `MTU = 1492`, y adentro de ella el túnel VPN tiene `MTU = 1412`. Sin embargo, las PCs de la sucursal están en una LAN Ethernet de `MTU = 1500` y en su paquete `TCP SYN` le anuncian al servidor ERP **`MSS = 1460`**.
3. **Evidencia que lo confirma:**
   - Desde el router de la sucursal probamos:
     - `/ping 10.1.40.10 src-address=10.2.10.1 size=1400 do-not-fragment` → **Responde `8 ms`**.
     - `/ping 10.1.40.10 src-address=10.2.10.1 size=1450 do-not-fragment` → **Falla (`packet too large`)**.
   - El servidor ERP en Casa Central tenía el firewall local bloqueando ICMP, por lo que nunca se enteraba de que sus paquetes de `1500 bytes` no cabían en el túnel de `1412 bytes`.
4. **Resolución arquitectónica:**
   - Agregamos en el router de la sucursal la regla de **TCP MSS Clamping** en `mangle forward` (`protocol=tcp tcp-flags=syn action=change-mss new-mss=clamp-to-pmtu`). Instantáneamente el router ajusta el `MSS` anunciado en los `SYN` a `1372 bytes`, y tanto el sistema ERP HTTPS como las carpetas compartidas cargan en menos de un segundo.

---

## 🧠 Modelo mental

Pensá en esto como **un servicio de camiones de mudanza (TCP) que sale desde un edificio de oficinas privadas (LAN con NAT) y tiene que cruzar un puente ferroviario bajo en la ruta (el MTU de un túnel VPN o PPPoE)**:

- **El `MTU` (`1500` vs `1420`)** es la altura máxima del puente en la autopista (`4,20 metros`), y **el `MSS`** es la altura de las cajas que el cliente pide por teléfono en el primer llamado (**el paquete `TCP SYN`**). Si el cliente pide un camión de `4,60 metros` y nadie le avisa al depósito que en el camino hay un puente bajo (**bloqueo de ICMP PMTUD**), las motos chicas de mensajería (**los Pings**) pasan por debajo del puente sin problema, pero el camión grande con la mudanza (**la página HTTPS**) se queda **trabado contra el puente**.
- **El *TCP MSS Clamping*** es el empleado de la garita de salida que escucha el llamado telefónico inicial (`SYN`) y le corrige el pedido diciendo: *"No mandes camiones de más de 3,80 metros porque más adelante hay un puente bajo"*.
- **Y el NAT con *Conntrack*** es el recepcionista en la puerta del edificio corporativo: como las 100 oficinas internas no tienen dirección propia en la calle, cuando el empleado de la Oficina 51 manda un paquete a un proveedor externo, el recepcionista le pega en el remitente la dirección única del edificio + `#Interno 54111` y lo anota en su cuaderno (**Conntrack**) para saber exactamente a qué escritorio llevar la respuesta cuando llegue el correo.

---

## 🧪 Autoevaluación rápida (Active Recall)

Respondé mentalmente antes de desplegar cada respuesta; si dudás, volvé a la sección correspondiente del documento.

**1. Si el enlace WAN es PPPoE (`MTU = 1492`), ¿cuál es el `MSS` máximo que entra sin fragmentar y qué hace exactamente la regla de TCP MSS Clamping?**

<details>
<summary>👀 Ver respuesta explicada</summary>

El `MSS` es `1452 bytes` (`1492 − 20 B IP − 20 B TCP`). El MSS Clamping intercepta el primer paquete `TCP SYN` de la PC —que anuncia `MSS = 1460` heredado de la LAN de `1500`— y lo reescribe a un valor que cabe en el tubo real, usando `action=change-mss new-mss=clamp-to-pmtu`. Así el servidor remoto nunca envía segmentos que no entren en la PPPoE.

</details>

**2. Un usuario dice que "el ping anda y Google abre, pero las páginas HTTPS pesadas se congelan en blanco". ¿Cuál es el mecanismo detrás de ese síntoma y qué mensaje ICMP no debés bloquear nunca?**

<details>
<summary>👀 Ver respuesta explicada</summary>

Es el *agujero negro de MTU (PMTUD Blackhole)*: los paquetes chicos (ping, `SYN`) pasan, pero el paquete grande con el certificado TLS viene con el bit `DF=1` y no entra en el MTU reducido del túnel o PPPoE. El mensaje que jamás hay que bloquear es **`ICMP Type 3 Code 4 (Fragmentation Needed)`**, porque es el que avisa al emisor que debe bajar el tamaño de paquete.

</details>

**3. Publicaste un servidor interno por Port Forwarding (`DNAT`) y entra perfecto desde 4G, pero desde las PCs de la misma oficina del WiFi no carga. ¿Cómo se llama el problema y cuál es la solución?**

<details>
<summary>👀 Ver respuesta explicada</summary>

Es el *Triángulo Roto* que resuelve el **Hairpin NAT (*NAT Loopback*)**: el `DNAT` deja la IP origen interna intacta, el servidor contesta directo por Capa 2 y la PC rechaza la respuesta por venir de una IP distinta a la que consultó (`TCP RST`). La solución es aplicar `DNAT` + `SNAT` juntos (Hairpin NAT) o usar **Split-Horizon DNS** para que adentro resuelva a la IP privada.

</details>

---

## 🔗 Ver también

- [`osi-and-tcp-ip-models`](osi-and-tcp-ip-models.md) — El diagrama byte a byte donde se ve cómo encajan el Header IP (`20B`), el Header TCP (`20B`) y el Payload (`MSS = 1460B`) adentro del `MTU = 1500B`
- [`ipv4-addressing-subnetting-and-vlsm`](ipv4-addressing-subnetting-and-vlsm.md) — Diferencia entre IPs privadas (`RFC 1918`), IPs públicas y CGNAT (`100.64.0.0/10`)
- [`stateful-firewalls-and-zone-segmentation`](stateful-firewalls-and-zone-segmentation.md) — Cómo usa el Firewall Stateful esta misma tabla Conntrack para distinguir tráfico `ESTABLISHED,RELATED` de ataques externos y la diferencia vital entre `INPUT` y `FORWARD`
