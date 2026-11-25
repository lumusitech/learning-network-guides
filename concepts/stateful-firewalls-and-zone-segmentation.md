⬅️ [Volver a Conceptos](README.md)

# Firewalls Stateful y Segmentación por Zonas — Cadenas INPUT vs FORWARD y arquitectura Zero-Trust

**Capa OSI principal:** Capas 3, 4 y 7 | **Estándares:** `RFC 2979`, `NIST SP 800-41`, `Netfilter / Conntrack`

---

## 🧠 ¿Qué es?

Separar una red en VLANs (Capa 2) y darles un router que las comunique (Capa 3) no sirve de nada para la seguridad si el router permite que cualquier VLAN hable libremente con todas las demás. El **Firewall** es el aduanero que se para en el router e inspecciona cada paquete para decidir si lo deja pasar (`ACCEPT / permit`) o lo destruye (`DROP / deny`).

A diferencia de las antiguas listas de acceso (**ACLs Stateless**) de los switches Capa 3 —que miran cada paquete de forma aislada sin recordar si forma parte de una conversación previa—, un **Firewall Stateful** moderno consulta la tabla **Conntrack**: si vos permitís que una PC de Administración inicie una conexión hacia un servidor (`NEW`), el firewall **recuerda la conversación y deja volver automáticamente todas las respuestas de ese servidor (`ESTABLISHED, RELATED`)** sin que tengas que abrir agujeros permanentes en sentido inverso.

---

## 🎯 ¿Por qué importa en el día a día?

El 80% de los errores graves de seguridad o de cortes autoinfligidos al configurar un router MikroTik, Linux (`nftables`/`iptables`) o Cisco vienen de **confundir el tráfico que va dirigido AL propio router (`INPUT`) con el tráfico de los usuarios que ATRAVIESA el router (`FORWARD`)**.

- **En diseño:** Te permite armar una **Arquitectura por Zonas** donde las cámaras IP (`CCTV`), los dispositivos IoT y el WiFi de Invitados jamás puedan tocar los servidores de producción ni las PCs de finanzas, conteniendo cualquier ransomware o intrusión.
- **En operación/mantenimiento:** Poner las dos reglas universales (`accept established,related` y `drop invalid`) al tope de tus cadenas hace que el router solo evalúe con la CPU el **primer paquete (`SYN`)** de cada conexión y despache los miles de paquetes siguientes por vía rápida (**FastTrack / Hardware**).
- **En troubleshooting:** Si entendés cómo fluyen las cadenas y el orden de lectura de arriba hacia abajo (*First-Match*), podés mirar los contadores de paquetes de tu firewall y descubrir en 10 segundos qué regla exacta está frenando un servicio.

---

## ⚙️ Cómo funciona por dentro

### 1. El Mapa Mental Definitivo: `INPUT` vs `FORWARD` vs `OUTPUT`

En MikroTik RouterOS y en Linux (Netfilter / `nftables` / `iptables`), el nombre de la cadena **NO significa "por qué cable entra el paquete"**, sino **cuál es el destino final del paquete respecto del propio Router**:

```text
                                 +-----------------------------------+
                                 |     PROCESOS LOCALES DEL ROUTER   |
                                 |   (SSH:22, WinBox:8291, DNS:53,   |
                                 |    BGP:179, OSPF, VRRP, Ping)     |
                                 +-----------------------------------+
                                         ^                   |
                          Cadena: INPUT  |                   |  Cadena: OUTPUT
                     (¿El destino final  |                   |  (Paquetes nacidos
                      es una IP propia   |                   |   adentro del propio
                      de ESTE router?)   |                   |   router hacia afuera)
                                         |                   v
   [Entra paquete] ---> (¿Es para mí o sigue de largo?) -------------------> [Sale paquete]
   por cualquier                         |                                    por cualquier
   interfaz (WAN/LAN)                    +-----------> Cadena: FORWARD -----> interfaz (WAN/LAN)
                                                (Tráfico que ATRAVIESA el router:
                                                 PC LAN -> Internet, o
                                                 VLAN 10 -> VLAN 40)
```

> **💡 La prueba de fuego para nunca equivocarte de cadena:**
>
> - **Pregunta 1:** *"Quiero prohibir que desde Internet entren por SSH o WinBox a administrar mi router."* → ¿A quién quieren entrar? **Al propio router.** → Cadena **`INPUT`**.
> - **Pregunta 2:** *"Quiero prohibir que las PCs de la VLAN Invitados entren al Servidor NAS de la VLAN Administración."* → ¿El tráfico termina en el router o pasa de largo a través del router hacia el NAS? **Pasa de largo (atraviesa el router).** → Cadena **`FORWARD`**. *(Si pusieras esta regla en `INPUT`, los invitados seguirían entrando al NAS como si nada).*

---

### 2. Los 4 Estados de Conexión (*Connection States*) y el patrón de alto rendimiento

Un Firewall Stateful clasifica cada paquete en uno de estos **4 estados** antes de mirar siquiera las direcciones IP o los puertos:

| Estado Conntrack | Qué significa exactamente | Qué regla se le aplica siempre al principio del Firewall |
|------------------|---------------------------|----------------------------------------------------------|
| **`ESTABLISHED`** | El paquete pertenece a una conexión que **ya fue autorizada antes** y ya vio tráfico en ambas direcciones (ida y vuelta) | **Regla #1: `ACCEPT` (y `FastTrack` en MikroTik).** Como el 98% de los paquetes de una red son `ESTABLISHED`, al poner esta regla en el puesto #1 el router los aprueba en el acto sin leer las 50 reglas que siguen abajo |
| **`RELATED`** | Es una conexión nueva, pero **hija directa de una conexión `ESTABLISHED` existente** (ej. un aviso `ICMP Fragmentation Needed` de MTU sobre una sesión HTTPS activa, o el canal de datos de FTP) | **Se aprueba junto con `ESTABLISHED` (`connection-state=established,related`).** Si no permitís `RELATED`, rompés el diagnóstico de MTU y protocolos multimedios |
| **`INVALID`** | El paquete **no tiene sentido técnico**: ej. un paquete TCP `ACK` o `RST` suelto que no corresponde a ninguna sesión abierta en Conntrack (típico de escaneos furtivos o rutas asimétricas) | **Regla #2: `DROP`.** Se tira a la basura inmediatamente en la puerta para no ensuciar las reglas siguientes |
| **`NEW`** | Es el **primer paquete (`TCP SYN` o primer `UDP`/`ICMP`)** de alguien que pide abrir una conversación nueva | **Reglas #3 en adelante (Tus políticas de negocio):** Recién acá abajo escribís qué zonas o IPs tienen permiso para iniciar conexiones nuevas, y cerrás al final con un **`DROP ALL`** |

```text
ESTRUCTURA UNIVERSAL DE UNA CADENA STATEFUL (INPUT o FORWARD):
=============================================================================================
Regla 1: ¿Estado = ESTABLISHED o RELATED? ----(Sí, 98% del tráfico)----> [ACCEPT / FastTrack]
            | (No)
Regla 2: ¿Estado = INVALID? ------------------(Sí, basura o ataque)----> [DROP inmediato]
            | (No -> Entonces por descarte el paquete es 100% NEW!)
Regla 3: ¿Viene de LAN/Admin hacia donde tiene permiso? ---(Sí)--------> [ACCEPT (Crea estado)]
            | (No)
Regla Final: Cualquier otra cosa no autorizada explícitamente ---------> [DROP ALL (Default Deny)]
```

---

### 3. Arquitectura de Segmentación por Zonas (Matriz de Seguridad Empresarial)

En lugar de escribir cientos de reglas por IP suelta, agrupás tus interfaces/VLANs en **Zonas (Listas de Interfaces)** y definís quién puede **iniciar (`NEW`)** conversaciones hacia quién:

```text
                    +-------------------------------------------+
                    |            FIREWALL CENTRAL               |
                    +-------------------------------------------+
                      |       |          |         |          |
         +------------+       |          |         |          +------------+
         v                    v          v         v                       v
  [1. Zona WAN]      [2. Zona ADMIN] [3. STAFF] [4. SERVERS / DMZ]  [5. CCTV / IoT / GUEST]
   (Internet)          (VLAN 99/20)   (VLAN 10)    (VLAN 40 / 90)     (VLAN 100 / 200)
```

| Zona Origen (Quién inicia `NEW`) ↓ \ Zona Destino → | 1. WAN (Internet) | 2. Admin / IT (VLAN 20/99) | 3. Staff / Usuarios (VLAN 10) | 4. Servidores Internos (VLAN 40) | 5. Cámaras CCTV / IoT (VLAN 100) | 6. WiFi Invitados (VLAN 200) |
|-----------------------------------------------------|:-----------------:|:--------------------------:|:-----------------------------:|:--------------------------------:|:--------------------------------:|:----------------------------:|
| **1. WAN (Internet)** | — | ❌ `DROP` | ❌ `DROP` | ⚠️ Solo puertos `DNAT` a DMZ | ❌ `DROP` | ❌ `DROP` |
| **2. Admin / IT (VLAN 20)** | ✅ `ACCEPT` | ✅ `ACCEPT` | ✅ `ACCEPT` (Soporte) | ✅ `ACCEPT` (`SSH/HTTPS`) | ✅ `ACCEPT` (Gestión cámaras) | ✅ `ACCEPT` |
| **3. Staff / Usuarios (VLAN 10)** | ✅ `ACCEPT` (`80/443`) | ❌ `DROP` | ✅ `ACCEPT` | ⚠️ Solo puertos de Apps (`443/445`) | ❌ `DROP` | ❌ `DROP` |
| **4. Servidores (VLAN 40)** | ⚠️ Solo updates | ❌ `DROP` *(¡pero sí vuelve `ESTABLISHED`!)* | ❌ `DROP` | ✅ `ACCEPT` | ✅ Solo el NVR a las cámaras (`554/37777`) | ❌ `DROP` |
| **5. Cámaras CCTV / IoT (VLAN 100)** | ❌ **`DROP`** *(Las cámaras no deben salir solas a Internet)* | ❌ `DROP` | ❌ `DROP` | ❌ `DROP` *(El NVR las consulta a ellas, no al revés)* | ❌ `DROP` (Aisladas) | ❌ `DROP` |
| **6. WiFi Invitados (VLAN 200)** | ✅ `ACCEPT` (`80/443/DNS`) | ❌ `DROP` | ❌ `DROP` | ❌ `DROP` | ❌ `DROP` | ❌ `DROP` (*Client Isolation*) |

> **🔥 Observá la fila 5 (Cámaras CCTV / IoT):** Las cámaras IP y dispositivos IoT suelen tener vulnerabilidades de firmware. Si les prohibís iniciar conexiones (`NEW`) tanto hacia Internet como hacia tu LAN, **el grabador NVR (en la VLAN Servidores) sigue pudiendo conectarse a las cámaras por RTSP (`554`) sin ningún problema** porque las respuestas de video de las cámaras vuelven como tráfico **`ESTABLISHED`**, pero si una cámara es hackeada no puede escanear tu red ni conectarse a un servidor de comando y control externo.

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

| Concepto de Firewall | Cisco IOS / Catalyst (ACL & ZBFW) | MikroTik RouterOS v7 | Linux (`nftables` / `iptables`) | Firewalls UTM (FortiGate / pfSense) |
|----------------------|-----------------------------------|----------------------|---------------------------------|-------------------------------------|
| **Tráfico hacia el propio Router** | `access-class` en `line vty` + CoPP (*Control Plane Policing*) | Cadena **`input`** en `/ip firewall filter` | Cadena **`input`** | *Local-In Policy* (FortiGate) / Reglas sobre la IP del firewall |
| **Tráfico que cruza entre redes** | `ip access-group <N> in/out` en la interfaz o `Zone-Pair` | Cadena **`forward`** en `/ip firewall filter` | Cadena **`forward`** | Políticas entre Interfaces o Zonas (`From Zone A -> To Zone B`) |
| **Agrupación de interfaces en Zonas** | `zone security LAN` | `/interface list` (`WAN`, `LAN`, `TRUSTED`) | `define LAN_IFS = { eth1, eth2 }` en `nftables` | *Security Zones* (`LAN`, `WAN`, `DMZ`) |
| **Agrupación de IPs en listas dinámicas** | `object-group network` | `/ip firewall address-list` (soporta `timeout=` automático) | `nftables sets` / `ipset` | *Address Objects / Groups* |
| **Aceleración de conexiones `ESTABLISHED`** | Hardware TCAM (en ACLs stateless) / ASIC | **`action=fasttrack-connection`** (saltea colas/firewall en CPU) | `flowtable` (`nftables hardware/software offload`) | NP (*Network Processor* ASIC en FortiGate) |

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Contadores de paquetes en la regla #1 (`established,related`)** | Acumula el `95% – 99%` de todos los paquetes y bytes de la cadena | El contador está en `0` o una regla `drop` fue colocada **arriba** de `established,related` | Las reglas se leen de arriba hacia abajo: si ponés las reglas pesadas antes de `established,related`, desperdiciás CPU o cortás respuestas legítimas |
| **Contador de la regla `drop invalid` en `forward`** | Crece muy despacio (algunos paquetes huérfanos ocasionales) | Sube de a miles por segundo y las conexiones internas entre dos subredes se cortan a los 30s | **Enrutamiento Asimétrico (*Asymmetric Routing*):** el paquete `SYN` de ida no pasó por el firewall (fue directo por un switch L3), y cuando el `SYN-ACK` de vuelta sí pasa por el firewall, Conntrack no conoce la sesión y la mata como `INVALID` |
| **Rendimiento de colas QoS (*Simple Queues*) en MikroTik** | Las colas limitan y miden el tráfico según lo configurado | Configurás una *Simple Queue* para limitar a una VLAN, pero **la cola marca `0 bps` y el usuario descarga a máxima velocidad** | Tenés activa la regla de **`FastTrack`** para esa subred: por diseño, los paquetes marcados con `fasttrack-connection` **saltean el motor de Simple Queues y Mangle** para ahorrar CPU |
| **Acceso SSH/WinBox al router tras agregar `drop all` al final de `input`** | Los administradores en la VLAN de Management entran sin problemas | Apenas activás la regla final `chain=input action=drop`, **te quedás afuera del router** | Te olvidaste de poner **arriba** del `drop` la regla que permite `in-interface-list=LAN` (o tu VLAN Management) en la cadena `input` *(¡por eso siempre se usa Safe Mode antes de tocar el firewall!)* |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Usar la lógica de *"Permitir todo por defecto y solo bloquear lo malo (Blacklist)"*:** Si al final de tu cadena `forward` o `input` no hay un bloqueo explícito de todo lo no autorizado (*Default Deny*), cada vez que agregues una VLAN nueva (ej. VLAN 250 para proveedores externos), por defecto tendrá acceso total a todos tus servidores internos hasta que te acuerdes de escribir una regla para bloquearla. **La seguridad profesional siempre es *Whitelist*: permitir explícitamente lo necesario y bloquear el resto al final.**
- **❌ Olvidar que cuando bloqueás el tráfico entre VLANs en `FORWARD`, las PCs siguen necesitando consultar el DNS y el gateway en `INPUT`:** Si una PC de la VLAN Invitados (`10.1.200.50`) usa como servidor DNS al propio router (`10.1.200.1`), esa consulta DNS (`UDP/TCP 53`) va dirigida a una IP del router, por lo tanto entra por la cadena **`INPUT`**, no por `FORWARD`. Debés permitir `UDP/TCP 53` (y `UDP 67` DHCP) desde las VLANs internas en `INPUT`, mientras bloqueás SSH/WinBox (`22`, `8291`, `80`, `443`) desde la VLAN Invitados en `INPUT`.
- **❌ Confundir `DROP` (Descartar en silencio) con `REJECT` (Rechazar avisando):**
  - Hacia **Internet (`WAN`)**, usá siempre **`DROP`**: si un bot escanea tus puertos públicos, el silencio absoluto lo obliga a esperar el timeout de cada puerto y no revela que tu IP está viva.
  - Hacia **redes internas (`LAN`)**, cuando quieras bloquear un puerto que una aplicación intenta abrir sin éxito, usar **`REJECT` (`icmp-admin-prohibited` o `tcp-reset`)** hace que la aplicación falle instantáneamente sin quedarse colgada 30 segundos esperando un timeout.

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

Una fábrica instala 40 cámaras IP nuevas en la `VLAN 100` (`10.1.100.0/24`) y el servidor grabador NVR en la `VLAN 40` de Servidores (`10.1.40.25/24`). Por auditoría de ciberseguridad, piden que **las cámaras no tengan salida a Internet ni puedan iniciar conexiones hacia ninguna red de la empresa**. Un técnico junior agrega en el router MikroTik la regla: `chain=forward src-address=10.1.100.0/24 action=drop` y la mueve al **puesto #1** arriba de todo en el firewall. En ese mismo segundo, **las 40 cámaras se ponen en negro en las pantallas de seguridad del NVR**.

### Análisis paso a paso por capas

1. **Síntoma observado:** Al poner el `drop` de origen `10.1.100.0/24` en el puesto #1 de la cadena `forward`, el NVR (`10.1.40.25`) pierde toda comunicación con las cámaras.
2. **Hipótesis usando el modelo mental (Orden de reglas Stateful: `ESTABLISHED` vs `NEW`):**
   - El NVR (`10.1.40.25`) es quien inicia la conexión (`TCP SYN` al puerto `554` RTSP de la cámara `10.1.100.50`). Ese primer paquete de ida tiene origen `10.1.40.25`, así que pasa sin tocar la regla del técnico.
   - Pero un milisegundo después, **la cámara tiene que contestar el saludo (`SYN-ACK`) y enviar el video con IP Origen `10.1.100.50`**.
3. **Evidencia que lo confirma:**
   - Como el técnico puso su regla `src-address=10.1.100.0/24 action=drop` en el **puesto #1 (arriba de la regla `accept established,related`)**, el firewall mató los paquetes `SYN-ACK` de respuesta de las cámaras antes de fijarse que eran respuestas legítimas (`ESTABLISHED`) a una pregunta iniciada por el NVR.
4. **Resolución arquitectónica:**
   - Movemos la regla `src-address=10.1.100.0/24 action=drop` **debajo** de las reglas `accept established,related` y `drop invalid`.
   - Resultado inmediato: las 40 cámaras vuelven a verse en vivo en el NVR (porque el NVR inicia el pedido y el video vuelve por la regla #1 `ESTABLISHED`), pero si alguien conecta una laptop en la boca de una cámara en la VLAN 100 e intenta abrir Internet o hacer ping al servidor contable, su paquete es `NEW`, cae hasta la regla de bloqueo de la VLAN 100 y es descartado.

---

## 🧠 Modelo mental

Pensá en esto como **la seguridad de un edificio corporativo con recepción en Planta Baja y oficinas en los pisos**:

- **La cadena `INPUT`** es la puerta blindada de la **cabina de los propios guardias de seguridad** (el Router): solo el jefe de seguridad (`Zona Admin`) tiene llave para entrar a esa cabina a cambiar las reglas. Los visitantes (`Zona Invitados`) nunca pueden entrar a la cabina de los guardias.
- **La cadena `FORWARD`** es el **molinete del hall central** por donde pasa la gente que va de una oficina a otra o sale a la calle.
- **Una ACL Stateless antigua** es un guardia sin memoria en el molinete que te pide dni y autorización escrita tanto para entrar como para volver a salir del baño. **Un Firewall Stateful (Conntrack)** es un guardia inteligente con memoria: cuando un gerente autorizado de la empresa sale a buscar a un técnico a otra sala (`NEW`), el guardia lo anota en su planilla; cuando vuelven caminando juntos conversando (`ESTABLISHED, RELATED`), el guardia los saluda y les abre el molinete sin detenerlos.

---

## 🔗 Ver también

- [`tcp-udp-mtu-and-nat-conntrack`](tcp-udp-mtu-and-nat-conntrack.md) — Cómo funciona por dentro la tabla Conntrack sobre la que se apoya el Firewall Stateful
- [`vlans-tagged-untagged-and-trunks`](vlans-tagged-untagged-and-trunks.md) — Cómo aislar en Capa 2 cada zona de seguridad para que ningún paquete pueda esquivar al Firewall
- [`dhcp-dns-and-network-services`](dhcp-dns-and-network-services.md) — Qué servicios esenciales de red (DHCP, DNS, NTP) debés permitir en tus zonas para que los usuarios puedan trabajar
