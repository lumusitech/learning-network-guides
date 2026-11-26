⬅️ [Volver a Conceptos](README.md)

# Modelos OSI y TCP/IP en la vida real — Encapsulamiento, cabeceras y diagnóstico

**Capa OSI principal:** Capas 1–7 (Arquitectura completa) | **Estándares:** `ISO/IEC 7498-1`, `RFC 1122`, `IEEE 802.3`

---

## 🧠 ¿Qué es?

Los modelos **OSI (7 capas)** y **TCP/IP (4/5 capas)** son el lenguaje universal de las redes. No son teoría académica para aprobar un examen: dividen el complejo proceso de enviar datos desde una aplicación hasta un cable de cobre o fibra óptica en **etapas independientes y apiladas**.

Cada capa cumple una única responsabilidad y se comunica con la misma capa del equipo destino agregando una **cabecera (header)** con instrucciones precisas. Este proceso de envolver los datos de arriba hacia abajo se llama **encapsulamiento**, y el proceso inverso al recibirlos se llama **desencapsulamiento**.

---

## 🎯 ¿Por qué importa en el día a día?

En el trabajo real, todos los ingenieros hablan usando los números del modelo OSI: *"es un problema de Capa 2"*, *"hay un loop L2"*, *"necesitamos un switch Capa 3"*, *"el firewall filtra en Capa 7"*.

- **En diseño:** Te permite elegir el equipo correcto. Un switch **Capa 2** solo mira direcciones MAC y etiquetas VLAN (`802.1Q`); si necesitás enrutar entre VLANs a velocidad de cable sin saturar el router de borde, necesitás un switch **Capa 3**.
- **En operación/mantenimiento:** Te explica por qué cada etiqueta que agregás al tráfico (VLAN `802.1Q` de 4 bytes, PPPoE de 8 bytes, WireGuard de 60–80 bytes) achica el espacio útil del paquete (**MTU**) y puede romper aplicaciones si no lo calculás.
- **En troubleshooting:** Si entendés qué dato viaja en la cabecera de cada capa, sabés exactamente qué herramienta usar (`ethtool` para Capa 1, tabla MAC/ARP para Capa 2, `ping`/`traceroute` para Capa 3, `ss`/`nc` para Capa 4, `curl`/`dig` para Capa 7).

---

## ⚙️ Cómo funciona por dentro

### 1. Equivalencia entre OSI (7 capas) y TCP/IP Práctico (5 capas)

En el día a día profesional usamos un **modelo híbrido de 5 capas**: las capas 1 a 4 del modelo OSI intactas y las capas 5, 6 y 7 agrupadas como **Aplicación**:

| Capa OSI | Nombre de la Capa | PDU (Unidad de Datos) | Qué dirección o identificador usa | Equipos y componentes que operan aquí |
|:--------:|-------------------|-----------------------|-----------------------------------|---------------------------------------|
| **7** | **Aplicación** | Datos / Payload | URL, Hostname (`app.empresa.local`), URI | Navegadores, servidores web, DNS, DHCP, Proxy Reverso, WAF |
| **6** | **Presentación** | Datos | Formato (JSON, TLS/SSL, certificados X.509) | Motor TLS (OpenSSL), cifrado, compresión |
| **5** | **Sesión** | Datos | IDs de sesión, sockets de aplicación | APIs, RPC, sesiones SMB/NFS |
| **4** | **Transporte** | **Segmento** (TCP) / **Datagrama** (UDP) | **Puertos** origen y destino (`0–65535`, ej. TCP `443`, UDP `53`) | Firewalls Stateful (Conntrack), Balanceadores L4, NAT/PAT |
| **3** | **Red (Internet)** | **Paquete** (Packet) | **Direcciones IP** lógicas origen y destino (`IPv4` / `IPv6`) | **Routers**, Switches Capa 3 (SVIs), Túneles VPN L3 |
| **2** | **Enlace de Datos** | **Trama** (Frame) | **Direcciones MAC** físicas (`48 bits`) y **VLAN ID** (`802.1Q`) | **Switches L2**, Bridges, Puntos de Acceso WiFi (`802.11`), Placas NIC |
| **1** | **Física** | **Bits** (Señal eléctrica, óptica o RF) | Pines RJ45, longitud de onda láser (nm), canal de radio (MHz) | Cables UTP, Fibra óptica, Transceptores SFP, Inyectores PoE, Hubs |

### 2. Diagrama real de encapsulamiento en el cable (Byte a Byte)

Cuando hacés una petición HTTPS (`https://10.0.40.10:443`), esto es lo que viaja realmente por el cable Ethernet dentro de una VLAN:

```text
+---------------------------------------------------------------------------------------------------+
|                                   TRAMA ETHERNET (CAPA 2)                                         |
|  1518 bytes estándar (1522 bytes con etiqueta VLAN 802.1Q)                                        |
+----------------+---------------+-----------+------------------------------------------+-----------+
| MAC Destino    | MAC Origen    | Tag 802.1Q|         PAQUETE IPv4 (CAPA 3)            | FCS / CRC |
| (6 bytes)      | (6 bytes)     | (4 bytes) |         MTU = 1500 bytes máx             | (4 bytes) |
+----------------+---------------+-----------+--------------------+---------------------+-----------+
                                 | EtherType | Header IP (20B)    | SEGMENTO TCP (L4)   |
                                 | 0x8100 -> | - IP Origen (4B)   | (1480 bytes)        |
                                 | VLAN 40   | - IP Destino (4B)  +----------+----------+
                                 | 0x0800 -> | - TTL (1B)         | Header   | DATOS L7 |
                                 | IPv4      | - Protocol=6 (TCP) | TCP (20B)| (TLS/HTTP|
                                 +-----------+--------------------+ - P.Orig |  MSS =   |
                                                                  | - P.Dest |  1460 B) |
                                                                  | - Flags  |          |
                                                                  +----------+----------+
```

### Anatomía / Componentes clave del encapsulamiento

| Cabecera (Header) | Tamaño típico | Campos críticos para diagnóstico | Qué pasa si está mal |
|-------------------|---------------|----------------------------------|----------------------|
| **Trama Ethernet II + 802.1Q (Capa 2)** | `18 bytes` (`14B` header + `4B` FCS) o `22 bytes` con VLAN | `MAC Destino`, `MAC Origen`, `VLAN ID (1–4094)`, `EtherType (0x0800=IPv4, 0x0806=ARP)`, `FCS (CRC32)` | Si el `FCS` no coincide al llegar, la placa o el switch **descarta la trama en silencio** y suma `+1` al contador `CRC/RX Errors`. Si el `VLAN ID` no está permitido en el puerto del switch, la trama muere en el puerto |
| **Paquete IPv4 (Capa 3)** | `20 bytes` (sin opciones) | `IP Origen`, `IP Destino`, `TTL (Time to Live)`, `Flags (DF = Don't Fragment)`, `Protocol (1=ICMP, 6=TCP, 17=UDP)` | Si el paquete supera la MTU del enlace y tiene `DF=1`, el router lo descarta. Si hay un bucle de rutas, el `TTL` llega a `0` y el router devuelve `ICMP Time Exceeded` |
| **Segmento TCP (Capa 4)** | `20 bytes` (hasta `60B` con opciones como `MSS`) | `Puerto Origen`, `Puerto Destino`, `Seq / Ack`, `Flags (SYN, ACK, FIN, RST)`, `Window Size` | Si el puerto destino está cerrado, el servidor responde `TCP RST`. Si un firewall intermedio hace `DROP`, el cliente queda en estado `SYN_SENT` hasta dar *Connection Timed Out* |
| **Datagrama UDP (Capa 4)** | `8 bytes` | `Puerto Origen`, `Puerto Destino`, `Length`, `Checksum` | No tiene handshake (`SYN`) ni retransmisión automática: es ideal para voz/video (RTSP/VoIP), DNS y WireGuard, pero si se pierde un paquete en Capa 1/2, UDP no lo reenvía |

### 3. Regla fundamental: ¿Qué cambia y qué se mantiene fijo en cada salto?

Esta es la pregunta más importante para entender cómo viaja un paquete a través de switches y routers:

```text
[PC: 10.0.10.50] ===(Switch L2)===> [Router: Gi0/1 (10.0.10.1) | Gi0/2 (10.0.40.1)] ===> [Servidor: 10.0.40.10]
 MAC: AA:AA:AA                       MAC Gi0/1: BB:BB:01        MAC Gi0/2: BB:BB:02      MAC: CC:CC:CC

 En el tramo 1 (VLAN 10):                               En el tramo 2 (VLAN 40):
 - L2 MAC Origen:  AA:AA:AA                             - L2 MAC Origen:  BB:BB:02  <-- ¡CAMBIÓ!
 - L2 MAC Destino: BB:BB:01 (Gateway)                   - L2 MAC Destino: CC:CC:CC  <-- ¡CAMBIÓ!
 - L3 IP Origen:   10.0.10.50                           - L3 IP Origen:   10.0.10.50 (Intacta, salvo NAT)
 - L3 IP Destino:  10.0.40.10                           - L3 IP Destino:  10.0.40.10 (Intacta)
 - L3 TTL:         64                                   - L3 TTL:         63        <-- ¡Restó 1!
```

- **Un Switch Capa 2** **NO modifica** las direcciones MAC ni mira el TTL. Solo lee la MAC destino (y la etiqueta VLAN) para decidir por qué puerto sacar la trama.
- **Un Router (Capa 3)** **DESTRUYE la cabecera de Capa 2 entrante**, consulta su tabla de rutas mirando la IP destino, **resta 1 al TTL** y construye una **nueva cabecera de Capa 2** poniendo su propia MAC de salida como origen y la MAC del próximo salto como destino.

---

## 🔄 Diccionario Multi-Vendor (Inspección por Capa en cada Fabricante)

Cómo inspeccionás qué está pasando en cada capa del modelo según el equipo que tengas enfrente:

| Capa a verificar | Cisco IOS / Catalyst | MikroTik RouterOS | Aruba / Ubiquiti / TP-Link | Linux (`iproute2` / `bridge`) |
|------------------|----------------------|-------------------|----------------------------|-------------------------------|
| **Capa 1 (Física, SFP y errores CRC)** | `show interfaces Gi1/0/1` / `show interfaces transceiver` | `/interface ethernet monitor ether1` | `show interfaces 1` / `show tech transceivers` | `ethtool eth0` / `ip -s link show eth0` |
| **Capa 2 (Tabla MAC y VLANs)** | `show mac address-table` / `show vlan brief` | `/interface bridge host print` / `/interface bridge vlan print` | `show mac-address` / `show vlans` | `bridge fdb show` / `bridge vlan show` |
| **Capa 2↔3 (Tabla ARP: IP ↔ MAC)** | `show ip arp` | `/ip arp print` | `show arp` | `ip neigh show` |
| **Capa 3 (IPs y Tabla de Rutas)** | `show ip interface brief` / `show ip route` | `/ip address print` / `/ip route print` | `show ip` / `show ip route` | `ip -br addr` / `ip route show` |
| **Capa 4 (Conexiones y NAT/Firewall)** | `show ip nat translations` / `show access-lists` | `/ip firewall connection print` | `show access-list` | `ss -tulnp` / `conntrack -L` |
| **Captura de paquetes en vivo** | `monitor capture` (EPC) | `/tool sniffer quick interface=ether1` | Port Mirroring hacia host con Wireshark | `tcpdump -ni eth0 -e` |

---

## 📊 Señales normales vs anómalas (Diagnóstico por Capa)

| Capa | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|:----:|----------------------------------|------------------------|-------------------------|
| **L1** | `Link: Up`, `1000Mbps Full`, `0` CRC/FCS errors, potencia óptica RX entre `-3 dBm` y `-18 dBm` | `Link Down`, `100Mbps Half`, errores `CRC/runts` subiendo, potencia RX `< -26 dBm` (`LOS`) | Cable roto, patchcord de fibra estrangulado, SFP incompatible o sucio |
| **L2** | MAC de cada host aprendida en un único puerto estable; ARP resuelve la MAC del gateway (`COMPLETE` / `DC`) | La misma MAC salta entre dos puertos (*MAC Flapping*); ARP muestra `INCOMPLETE` o entrada vacía | **MAC Flapping** = Bucle físico de Capa 2. **ARP Incomplete** = VLAN incorrecta en el switch o equipo destino apagado |
| **L3** | `ping` al gateway `< 1 ms`; `traceroute` avanza salto a salto hasta el destino sin bucles | `Destination Host Unreachable`, `TTL expired in transit`, o `ping -s 1472 -M do` falla con `Frag needed` | Falta ruta de ida o de vuelta (asimetría), bucle de rutas estáticas, o cuello de botella de **MTU** en túnel/PPPoE |
| **L4** | `SYN → SYN-ACK → ACK` en milisegundos; conexión `ESTABLISHED` | El cliente envía `SYN` repetidos sin respuesta (`Timeout`) o recibe `RST` inmediato | **`SYN` sin respuesta** = Firewall haciendo `DROP` o falta de ruta de retorno. **`RST` inmediato** = El host llegó pero el servicio no está escuchando en ese puerto ( o firewall con `REJECT`) |
| **L7** | `dig` devuelve la IP en `< 30 ms`; `curl -I` devuelve `HTTP 200 / 301` con certificado TLS válido | `ping` a la IP funciona perfecto, pero por nombre da `NXDOMAIN`/`SERVFAIL`, o TLS falla por fecha/SNI | Servidor DNS caído o bloqueado (UDP/TCP 53), reloj NTP desincronizado en el equipo, o certificado expirado |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Creer que un Switch Capa 2 "ve" o asigna direcciones IP a las PCs:** Un switch L2 puro solo tiene **una** dirección IP para su propio plano de gestión (para que entres por SSH o web). El switch conmuta el tráfico de los usuarios mirando **únicamente direcciones MAC y etiquetas VLAN**, sin abrir jamás la cabecera IP.
- **❌ Confundir `Connection Refused` (`TCP RST`) con `Connection Timed Out` (Silencio):**
  - Si recibís **`Connection Refused`**, es una excelente noticia para el ingeniero de red: significa que **las Capas 1, 2 y 3 funcionan de ida y de vuelta**, llegaste hasta el servidor destino, y fue el propio sistema operativo del servidor (o una regla explícita `reject`) quien te contestó *"acá estoy, pero nadie escucha en ese puerto"*.
  - Si recibís **`Connection Timed Out`**, el paquete se perdió en el camino (ruta faltante, VLAN rota o firewall intermedio haciendo `DROP` silencioso) o la respuesta del servidor se perdió al volver.
- **❌ Olvidar que ARP está entre Capa 2 y Capa 3:** Si dos PCs están en la misma subred (`192.168.10.10/24` y `192.168.10.20/24`), **nunca pasan por el router (Capa 3)**. La primera PC manda un `ARP Request` en broadcast L2 (`FF:FF:FF:FF:FF:FF`) preguntando *"¿quién tiene 192.168.10.20?"* y se hablan directamente a través del switch por MAC.

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

Un técnico instala una cámara IP nueva (`10.0.100.50/24`) en la VLAN 100 (CCTV), conectada al puerto 8 de un switch MikroTik con RouterOS. Desde el servidor NVR (`10.0.150.10/24`, en la VLAN 150) intenta abrir el stream RTSP (`rtsp://10.0.100.50:554`) y no conecta. El técnico dice: *"El firewall del router está bloqueando el puerto 554"*.

### Análisis paso a paso por capas

1. **Síntoma observado:** El NVR (VLAN 150) no conecta al puerto TCP 554 de la cámara (VLAN 100).
2. **Hipótesis usando el modelo mental (No saltar a Capa 4 sin validar Capa 2 y 3):**
   - Desde el propio router (que es el Default Gateway de ambas VLANs: `10.0.100.1` y `10.0.150.1`), probamos un `ping 10.0.100.50`. **No responde.**
   - Si el propio router en la misma subred `10.0.100.0/24` no llega a la cámara, **no es el firewall inter-VLAN (Capa 4)**: el problema está en **Capa 1 o Capa 2** dentro de la VLAN 100.
3. **Evidencia que lo confirma:**
   - Miramos laCapa 1 en el switch (`/interface ethernet monitor ether8`): `status: link-ok`, `rate: 100Mbps`, `full-duplex: yes` (normal para una cámara IP que suele traer placa de 100 Mbps). Capa 1 está sana.
   - Miramos la tabla ARP en el router (`/ip arp print where address=10.0.100.50`): figura incompleta (sin dirección MAC).
   - Miramos la tabla MAC del switch (`/interface bridge host print where on-interface=ether8`): **la MAC de la cámara aparece aprendida en la `VID 1` en lugar de la `VID 100`**.
   - El técnico había agregado el puerto `ether8` a la lista de VLANs, pero olvidó cambiarle el **`pvid=100`** en `/interface bridge port`. Como la cámara envía tramas sin etiquetar (*untagged*), el switch las estaba metiendo en la VLAN 1 por defecto.
4. **Resolución arquitectónica:**
   - Configuramos `pvid=100` en `ether8`. Instantáneamente el router resuelve ARP en la VLAN 100, el ping responde en `0.4 ms` y el NVR levanta el video RTSP por el puerto 554. El firewall nunca tuvo la culpa.

---

## 🧠 Modelo mental

Pensá en esto como **enviar una carta confidencial en papel desde el gerente de una empresa en Buenos Aires al gerente de otra empresa en Madrid**:

- **Capa 7 (Aplicación):** Es la carta escrita en español con el pedido comercial.
- **Capa 4 (Transporte — TCP/Puertos):** Es meter la carta en un sobre interno que dice *"De: Oficina de Compras (Puerto 51432) → Para: Oficina de Ventas (Puerto 443), Página 1 de 3, requiere acuse de recibo"*.
- **Capa 3 (Red — IP):** Es meter ese sobre dentro del sobre postal de cartón con la **dirección geográfica final**: *"Origen: Av. Corrientes 1200, Buenos Aires (`10.0.10.50`) → Destino: Calle Gran Vía 45, Madrid (`10.0.40.10`)"*. **Esta dirección de origen y destino no cambia en todo el viaje.**
- **Capa 2 (Enlace — Ethernet/MAC):** Es la etiqueta de código de barras del **camión o avión actual** que lleva la caja únicamente desde la sucursal de correo hasta el aeropuerto de Ezeiza (*"De: Camión Local AA → Para: Centro Distribución BB"*). En cada escala (cada **Router**), le arrancan la etiqueta del camión viejo y le pegan la etiqueta del avión siguiente, pero la dirección postal de Madrid adentro (la IP) jamás se toca.
- **Capa 1 (Física):** Es el asfalto de la ruta, el camión o la pista de aterrizaje por donde se mueve físicamente la caja.

Si el camión tiene una rueda pinchada en la autopista (Capa 1) o lo cargaron en el depósito equivocado (Capa 2 — VLAN mal puesta), no sirve de nada revisar si la carta adentro tenía faltas de ortografía (Capa 7).

---

## 🧪 Autoevaluación rápida (Active Recall)

Respondé mentalmente antes de desplegar cada respuesta; si dudás, volvé a la sección correspondiente del documento.

**1. Un paquete cruza un router entre dos VLANs. ¿Qué campos de la cabecera cambian y cuáles se mantienen intactos?**

<details>
<summary>👀 Ver respuesta explicada</summary>

El router **destruye la cabecera de Capa 2**: cambian la **MAC Origen** (pasa a ser la de la interfaz de salida) y la **MAC Destino** (el próximo salto). En Capa 3 se mantienen la **IP Origen y la IP Destino** (salvo NAT) y el **TTL resta 1**. El switch L2, en cambio, no toca MACs ni mira el TTL.

</details>

**2. Un servicio responde `Connection Refused` y otro da `Connection Timed Out`. ¿Qué te dice cada síntoma sobre las capas?**

<details>
<summary>👀 Ver respuesta explicada</summary>

**`Connection Refused`** es un `TCP RST`: las Capas 1, 2 y 3 funcionan de ida y vuelta y llegaste al host, pero nadie escucha en ese puerto. **`Connection Timed Out`** es silencio: el paquete se perdió (ruta faltante, VLAN rota o firewall haciendo `DROP`) y el cliente queda en `SYN_SENT`.

</details>

**3. El router no hace ping a una cámara en su propia VLAN y su MAC aparece aprendida en `VID 1` en vez de `VID 100`. ¿Causa raíz y solución?**

<details>
<summary>👀 Ver respuesta explicada</summary>

El puerto se agregó a la lista de VLANs pero **no se le cambió el `pvid`**. Como la cámara manda tramas *untagged*, el switch las metió en la VLAN 1 por defecto y el router nunca resuelve ARP en la VLAN correcta. Se corrige con `pvid=100` en `/interface bridge port`; el firewall no tenía nada que ver.

</details>

---

## 🔗 Ver también

- [`how-to-think-like-network-engineer`](how-to-think-like-network-engineer.md) — Metodología de diagnóstico y los 3 planos (Datos, Control y Gestión)
- [`physical-layer-cables-fiber-poe`](physical-layer-cables-fiber-poe.md) — Capa 1 en detalle: cobre, fibra óptica, SFP y PoE
- [`ethernet-mac-and-arp`](ethernet-mac-and-arp.md) — Capa 2 en detalle: trama Ethernet, tabla MAC y protocolo ARP
- [`vlans-tagged-untagged-and-trunks`](vlans-tagged-untagged-and-trunks.md) — Capa 2: etiquetas 802.1Q, PVID y equivalencia multi-vendor
