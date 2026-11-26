⬅️ [Volver a Conceptos](README.md)

# Ethernet, Direcciones MAC y ARP (Capa 2) — Cómo piensa y conmuta un switch

**Capa OSI principal:** Capa 2 (Enlace de Datos) | **Estándares:** `IEEE 802.3`, `IEEE 802.1D`, `RFC 826 (ARP)`, `RFC 5227 (ACD)`

---

## 🧠 ¿Qué es?

Mientras que la Capa 3 (IP) sirve para viajar de una red a otra a través del mundo, la **Capa 2 (Ethernet)** es la encargada de entregar los datos **dentro de tu misma red local (LAN / VLAN)** de una placa de red a otra a través de los switches.

Para lograrlo sin que todos los equipos se pisen entre sí, la Capa 2 utiliza tres piezas fundamentales:

1. **La Trama Ethernet (*Frame*):** El "sobre físico" que envuelve al paquete IP con un chequeo matemático anticorrupción (`FCS/CRC32`).
2. **La Dirección MAC y la Tabla CAM del Switch:** La matrícula física de 48 bits de cada placa de red y la memoria ultrarrápida donde el switch anota en qué boca física está enchufado cada equipo.
3. **El Protocolo ARP (*Address Resolution Protocol*):** El traductor que pregunta en voz alta por toda la red local *"¿Quién tiene la IP `10.0.10.1`? ¡Necesito su dirección MAC para poder armar la trama Ethernet!"*.

---

## 🎯 ¿Por qué importa en el día a día?

No podés diagnosticar una red local, encontrar un equipo intruso ni entender qué es una VLAN si no tenés claro cómo el switch aprende direcciones MAC y cómo ARP traduce IPs en MACs.

- **En diseño:** Te explica por qué meter 1.000 equipos en una misma red plana sin VLANs satura a todos con tráfico **Broadcast** (ARP, DHCP, mDNS, NetBIOS).
- **En operación/mantenimiento:** Cruzando la **tabla ARP del router** (`IP ↔ MAC`) con la **tabla MAC del switch** (`MAC ↔ Puerto físico`), podés saber en 15 segundos **en qué boca exacta del rack está enchufada cualquier PC, cámara o impresora** sin caminar por el edificio siguiendo cables.
- **En troubleshooting:** Si el ping a una IP local falla pero en la tabla ARP ves la MAC resuelta (`COMPLETE`), sabés al instante que el equipo destino **está encendido y conectado en Capa 2**, pero su firewall local (ej. Firewall de Windows) está bloqueando el ping en Capa 3/4.

---

## ⚙️ Cómo funciona por dentro

### 1. Anatomía de una Trama Ethernet II (Byte a Byte)

```text
|<--- Sincronización --->|<------------------- TRAMA ETHERNET II (64 a 1518 bytes) ------------------->|
+--------------+---------+-----------------+-----------------+------------+------------------+---------+
|  Preámbulo   |   SFD   |   MAC Destino   |   MAC Origen    | EtherType  | Payload (Datos)  |   FCS   |
|  (7 bytes)   | (1 byte)|    (6 bytes)    |    (6 bytes)    | (2 bytes)  | (46 a 1500 bytes)| (4bytes)|
+--------------+---------+-----------------+-----------------+------------+------------------+---------+
  10101010...   10101011   AA:BB:CC:11:22:33 00:11:22:AA:BB:CC  0x0800=IPv4  Paquete IP o ARP   CRC-32
                                                                0x0806=ARP
                                                                0x8100=VLAN
                                                                0x86DD=IPv6
```

### Anatomía / Componentes clave

| Campo / Componente | Tamaño / Valor típico | Función real | Qué pasa si está mal |
|--------------------|-----------------------|--------------|----------------------|
| **MAC Destino y MAC Origen** | `6 bytes` (`48 bits`) c/u en hexadecimal | Los primeros 3 bytes son el **OUI** (identifica al fabricante: ej. `D4:CA:6D` = MikroTik, `9C:EB:E8` = Dahua) y los últimos 3 bytes son el número de serie único de la placa | Si dos equipos tienen la misma MAC clonada en la misma VLAN, el switch sufre *MAC Flapping* y la conexión se corta intermitentemente |
| **EtherType** | `2 bytes` | Le avisa al sistema operativo receptor qué protocolo hay adentro del sobre (`0x0800` = IPv4, `0x0806` = ARP, `0x8100` = Tag VLAN 802.1Q, `0x8863/8864` = PPPoE) | Si un switch no soporta un EtherType o recibe un tag `0x8100` en un puerto que solo admite tramas sin etiquetar, descarta la trama |
| **Payload (MTU = 1500 B)** | `46 a 1500 bytes` (hasta `9000B` en Jumbo Frames) | Contiene el paquete IP completo. Si el paquete mide menos de 46 bytes, Ethernet rellena con ceros (*Padding*) para que la trama total nunca baje de `64 bytes` | Las tramas menores a 64 bytes se llaman **Runts** (colisiones o fallas de placa) y las mayores a 1518/1522 bytes sin Jumbo activo se llaman **Giants** y son descartadas |
| **FCS (*Frame Check Sequence*)** | `4 bytes` (`CRC-32`) | Suma matemática calculada sobre toda la trama al salir. El switch o placa receptora recalcula el CRC-32 al recibirla | Si un solo bit cambió en el cable por ruido, el CRC no da igual: **la trama se destruye en el acto en Capa 2** (no existe retransmisión en Ethernet; de eso se encargará TCP en Capa 4 si hace falta) |

### 2. Las 3 acciones del Switch y su Tabla CAM / FDB

Un switch **jamás adivina ni pregunta**: toma todas sus decisiones en microsegundos usando su **Tabla de Direcciones MAC** (llamada memoria **CAM** en hardware o **FDB** — *Forwarding Database*).

```text
     [PC-A]                  [Switch L2 — Tabla CAM]                  [PC-B]              [PC-C]
MAC: AA:AA:AA:01           +----------+--------------+           MAC: BB:BB:BB:02    MAC: CC:CC:CC:03
   (Puerto 1)              |   MAC    | Puerto | VLAN|              (Puerto 2)          (Puerto 3)
       |                   +----------+--------+-----+                  |                   |
       | 1. Trama:         | AA:AA:01 | Port 1 |  1  | <-- ¡APRENDE!    |                   |
       | Orig=AA -> Dest=BB|          |        |     |                  |                   |
       +------------------>| ¿Dónde está BB:BB:02?   |                  |                   |
                           | No está en la tabla:    |                  |                   |
                           | ¡FLOODING a todos menos1|----------------->| (Recibe y contesta|
                           |                         |------------------------------------->| (La ignora)
```

Cada vez que una trama entra por un puerto de un switch, ocurren dos pasos independientes:

1. **Paso 1 — Aprender (*Learning*, siempre mira la `MAC Origen`):**
   - El switch mira la **MAC Origen** de la trama que acaba de entrar por el Puerto 1 y anota en su tabla CAM: *"La MAC `AA:AA:AA:01` vive en el Puerto 1 (VLAN 1)"*, reiniciando su cronómetro de vencimiento (**Aging Time = 300 segundos / 5 minutos** por defecto).
2. **Paso 2 — Decidir qué hacer (*Forwarding / Flooding / Filtering*, siempre mira la `MAC Destino`):**
   - **Forwarding (Unicast conocido):** Si la `MAC Destino` ya figura en la tabla CAM (ej. en el Puerto 2), el switch envía la trama **exclusivamente por el Puerto 2**. El Puerto 3 ni se entera.
   - **Flooding (Inundación):** Si la `MAC Destino` es **Broadcast (`FF:FF:FF:FF:FF:FF`)**, Multicast o un **Unicast desconocido** (todavía no habló y no está en la tabla CAM), el switch **clona y saca la trama por todos los puertos de esa misma VLAN**, excepto por el puerto por donde entró.
   - **Filtering (Descarte):** Si la `MAC Destino` está en el mismo puerto por donde entró la trama, o si el `FCS/CRC` está corrupto, el switch la descarta.

### 3. El Protocolo ARP: El puente entre Capa 3 (IP) y Capa 2 (MAC)

Cuando tu PC (`10.0.10.50`) quiere enviarle un paquete a `10.0.10.1` (su Default Gateway), sabe la **IP destino**, pero no puede poner la trama en el cable porque el campo `MAC Destino` de Ethernet está vacío. Entonces ejecuta el ciclo **ARP**:

```text
[PC: 10.0.10.50 (AA:AA:01)]                        [Router Gateway: 10.0.10.1 (BB:BB:99)]
            |                                                        |
            |  1. ARP Request (BROADCAST L2 a FF:FF:FF:FF:FF:FF)     |
            |     "¿Quién tiene la IP 10.0.10.1? Dígaselo a 10.0.10.50"
            +------------------------------------------------------->| (Todas las PCs de la VLAN lo
            |                                                        |  escuchan, pero solo 10.0.10.1
            |  2. ARP Reply (UNICAST L2 directo a AA:AA:01)          |  responde)
            |     "10.0.10.1 está en la MAC BB:BB:99"                |
            |<-------------------------------------------------------+
            |
   [Guarda en Caché ARP: 10.0.10.1 -> BB:BB:99]
   [Ahora sí arma la Trama Ethernet con MAC Destino = BB:BB:99 y envía el paquete IP]
```

> **🔥 ¿Qué es un Gratuitous ARP (ARP Gratuito)?** Es un anuncio ARP en broadcast donde un equipo anuncia su propia IP y MAC **sin que nadie le haya preguntado** (*"¡Atención a todos! La IP `10.0.10.1` ahora tiene la MAC `BB:BB:99`"*). Cumple dos funciones críticas en producción:
>
> 1. **Detectar IPs duplicadas:** Si al arrancar alguien contesta a tu Gratuitous ARP, significa que esa IP ya está ocupada en la red.
> 2. **Alta disponibilidad (Failover VRRP/HSRP/Cluster):** Cuando el router principal muere y el router de backup toma la IP virtual, dispara un Gratuitous ARP para que todos los switches y PCs actualicen sus tablas al instante sin esperar 5 minutos a que venza la caché.

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

| Concepto Capa 2 | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Aruba / Ubiquiti / TP-Link | Linux (`iproute2` / `bridge`) |
|-----------------|----------------------|----------------------|----------------------------|-------------------------------|
| **Ver tabla MAC del switch** | `show mac address-table` | `/interface bridge host print` | `show mac-address` | `bridge fdb show` |
| **Ver tiempo de expiración MAC (Aging)** | `show mac address-table aging-time` (300s) | `/interface bridge print` (`ageing-time=5m`) | `show mac-address` (300s) | `ip -d link show br0` (`ageing_time 30000`) |
| **Ver tabla ARP (IP ↔ MAC)** | `show ip arp` | `/ip arp print` | `show arp` | `ip neigh show` |
| **Limpiar caché ARP para forzar re-aprendizaje** | `clear ip arp 10.0.10.50` | `/ip arp remove [find address=10.0.10.50]` | `clear arp` | `ip neigh flush dev eth0` |
| **Dominio de Broadcast L2 virtual en software** | `Vlan1` / `bridge-domain` | `/interface bridge` | `VLAN` | `ip link add br0 type bridge` |

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Cantidad de MACs por puerto de acceso** | `1` MAC (PC sola) o `2` MACs (Teléfono IP + PC detrás) | `15` a `200` MACs en una boca de escritorio | Alguien conectó un switch no gestionable o un Access Point WiFi en esa boca de pared |
| **Estabilidad de la tabla MAC** | Cada MAC permanece fija en su puerto asignado | La misma MAC cambia de `Gi1/0/5` a `Gi1/0/24` varias veces por segundo (**MAC Flapping**) | **Bucle físico de Capa 2** (las tramas en broadcast están girando en círculo y entrando por dos puertos distintos) o dos equipos con la misma MAC clonada |
| **Estado de una entrada en la tabla ARP** | `COMPLETE` (Linux), flags `DC` (MikroTik), edad en minutos (Cisco) | `INCOMPLETE` / `FAILED` (Linux) o entrada ARP sin dirección MAC en MikroTik | La IP destino no existe, está apagada, tiene el cable desconectado o está en **otra VLAN** distinta y su `ARP Request` en broadcast no llega |
| **Cambio repentino de la MAC del Default Gateway en una PC** | La MAC del gateway (`10.0.10.1`) nunca cambia (salvo failover VRRP) | La MAC de `10.0.10.1` cambia por la MAC de una laptop de la oficina | **Ataque de ARP Spoofing / Man-in-the-Middle** o alguien le configuró por error la IP `10.0.10.1` estática a su propia PC |
| **Tráfico Broadcast en puertos de usuarios** | `< 1%` del tráfico total (pocos paquetes por segundo) | Miles de paquetes broadcast por segundo (`100 Mbps+`) | **Broadcast Storm** por bucle L2 sin Spanning Tree o placa de red en cortocircuito inyectando basura |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Creer que "un switch bloquea los broadcasts":** Al contrario: **por definición, un switch tiene la obligación de reenviar todo paquete Broadcast (`FF:FF:FF:FF:FF:FF`) por absolutamente todos los puertos de esa misma VLAN**. Lo único que frena un broadcast es un **Router (Capa 3)** o dividir el switch en **VLANs separadas**.
- **❌ Buscar en la tabla MAC de un switch un equipo que hace 20 minutos no transmite nada:** Como la tabla CAM tiene un `aging-time` de **5 minutos (300 segundos)**, si una impresora o PC está encendida pero en completo silencio, el switch borra su MAC para ahorrar memoria. **Truco profesional:** hacé primero un `ping` a la IP del equipo (aunque tenga firewall, responderá al ARP en Capa 2) y recién ahí consultá la tabla MAC del switch.
- **❌ Creer que la MAC de origen que ve un servidor en su tabla ARP es la MAC real de una PC que está en otra VLAN/subred:** Como vimos en el modelo OSI, las direcciones MAC **jamás cruzan un router**. Si la PC `10.0.10.50` (VLAN 10) se conecta al servidor `10.0.40.10` (VLAN 40), el servidor solo verá en su tabla ARP la **MAC de la pata del Router en la VLAN 40 (`10.0.40.1`)**.

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

El área de Contabilidad reporta un problema rarísimo: **"La impresora de red (`10.0.10.200`) imprime 2 hojas, después deja de responder durante 3 minutos, luego vuelve a imprimir sola y mientras no imprime sí responde al ping desde algunas PCs pero desde otras no"**.

### Análisis paso a paso por capas

1. **Síntoma observado:** Conectividad intermitente con una IP específica (`10.0.10.200`) dentro de la misma LAN. Algunas PCs llegan y otras no al mismo tiempo.
2. **Hipótesis usando el modelo mental (Capa 2 — Conflicto de IP duplicada en ARP):**
   - Cuando una IP "funciona a ratos y desde algunas PCs sí y otras no", la sospecha número 1 es que **dos dispositivos distintos tienen puesta la misma IP `10.0.10.200`** y se están peleando a gritos mediante respuestas ARP.
3. **Evidencia que lo confirma:**
   - Entramos al router MikroTik de la oficina y ejecutamos `/ip arp print where address=10.0.10.200` dos veces seguidas tras limpiar la entrada:
     - Primero aparece la MAC `00:17:C8:AA:11:22` (OUI `00:17:C8` = **Kyocera**, la impresora real).
     - Segundos después, la misma IP `10.0.10.200` cambia a la MAC `DC:A6:32:99:88:77` (OUI `DC:A6:32` = **Raspberry Pi**).
   - Consultamos en el switch principal dónde está cada MAC (`show mac address-table address DC:A6:32:99:88:77`): nos dice que está enchufada en el puerto **`Gi1/0/18`**.
   - Alguien de Sistemas había conectado una Raspberry Pi en el puerto 18 con IP fija `10.0.10.200` sin revisar la planilla de direccionamiento.
4. **Resolución arquitectónica:**
   - Apagamos o cambiamos la IP de la Raspberry Pi del puerto 18, reservamos el rango `.1` al `.99` para IPs fijas/reservas DHCP documentadas y movemos el pool dinámico DHCP de `.100` a `.240`.

---

## 🧠 Modelo mental

Pensá en esto como **una oficina grande de planta abierta (la VLAN) donde cada empleado tiene un nombre de puesto que puede cambiar (`la IP: "El Contador"`) y un número de DNI tatuado de fábrica (`la MAC`)**:

- **ARP** es cuando entrás a la oficina con una carpeta para `"El Contador"` (`10.0.10.200`), pero no sabés quién es físicamente: pegás un grito al aire (**Broadcast `FF:FF:FF:FF:FF:FF`**) diciendo *"¡¿Quién es El Contador?!"*, y solo esa persona levanta la mano y te dice en privado (**Unicast**) *"Soy yo, DNI `00:17:C8...`"*.
- **El Switch y su Tabla CAM** es el recepcionista silencioso sentado en el pasillo con un anotador: cada vez que alguien habla, el recepcionista anota en qué escritorio está sentado ese DNI. Si le llega un paquete para un DNI que ya tiene anotado, se lo lleva en mano sin molestar a nadie (**Forwarding**). Si todavía no tiene anotado ese DNI, fotocopia el mensaje y lo tira en todos los escritorios (**Flooding**) hasta que el dueño conteste. Y si alguien se queda callado durante **5 minutos (300s)**, le borra el nombre con goma para hacer lugar en la hoja.

---

## 🧪 Autoevaluación rápida (Active Recall)

Respondé mentalmente antes de desplegar cada respuesta; si dudás, volvé a la sección correspondiente del documento.

**1. Cuando una trama entra a un switch, ¿qué campo usa para aprender y qué campo usa para decidir el reenvío, y cuándo hace Flooding?**

<details>
<summary>👀 Ver respuesta explicada</summary>

El switch **aprende siempre mirando la `MAC Origen`** y anota en su tabla CAM en qué puerto y VLAN vive esa MAC. Luego **decide mirando la `MAC Destino`**: si ya la conoce, hace Forwarding solo por ese puerto; si es Broadcast, Multicast o un **Unicast desconocido** (aún no está en la tabla), hace **Flooding** por todos los puertos de la VLAN menos el de entrada. Si el destino está en el mismo puerto de entrada o el FCS está corrupto, descarta la trama.

</details>

**2. ¿Por qué puede desaparecer de la tabla MAC del switch un equipo que sigue encendido y conectado, y qué truco usás para localizarlo?**

<details>
<summary>👀 Ver respuesta explicada</summary>

La tabla CAM tiene un **Aging Time de 300 segundos (5 minutos)** por defecto: si un equipo permanece en silencio, el switch borra su entrada para ahorrar memoria. Por eso una impresora o PC inactiva no aparece. El truco es hacer primero un `ping` a su IP (aunque tenga firewall responderá al ARP en Capa 2) y recién después consultar la tabla MAC, que ya tendrá la entrada refrescada.

</details>

**3. En ARP, ¿por qué el `Request` es Broadcast y el `Reply` es Unicast, y para qué sirve un Gratuitous ARP en un failover?**

<details>
<summary>👀 Ver respuesta explicada</summary>

El `ARP Request` debe ir en Broadcast (`FF:FF:FF:FF:FF:FF`) porque quien pregunta no conoce la MAC del dueño de la IP, y solo el destinatario responde con un `ARP Reply` en Unicast directo a la MAC del solicitante. El **Gratuitous ARP** es un anuncio no solicitado con el que un equipo declara su propia IP y MAC; en failover VRRP/HSRP lo dispara el router que asume la IP virtual para que switches y PCs actualicen sus tablas al instante en lugar de esperar hasta 5 minutos.

</details>

---

## 🔗 Ver también

- [`physical-layer-cables-fiber-poe`](physical-layer-cables-fiber-poe.md) — Capa 1: cómo llegan físicamente las tramas Ethernet al puerto del switch
- [`vlans-tagged-untagged-and-trunks`](vlans-tagged-untagged-and-trunks.md) — Cómo dividir un switch en múltiples oficinas aisladas con etiquetas 802.1Q
- [`spanning-tree-and-loop-prevention`](spanning-tree-and-loop-prevention.md) — Qué pasa con el Flooding de Capa 2 cuando hay un cable conectado en bucle
