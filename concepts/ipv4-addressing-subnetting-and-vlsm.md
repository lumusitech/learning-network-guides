⬅️ [Volver a Conceptos](README.md)

# Direccionamiento IPv4, Subnetting CIDR y VLSM — Diseño de redes sin dolor

**Capa OSI principal:** Capa 3 (Red) | **Estándares:** `RFC 791 (IPv4)`, `RFC 4632 (CIDR)`, `RFC 1918 (Privadas)`, `RFC 6598 (CGNAT)`, `RFC 3021 (/31)`

---

## 🧠 ¿Qué es?

Si la dirección MAC (Capa 2) es el número de documento físico de una placa de red para moverse dentro de una misma sala, la **dirección IPv4 (Capa 3)** es su **dirección postal jerárquica (`País → Provincia → Calle → Número de puerta`)** que permite a los routers del mundo saber exactamente a qué red y a qué edificio enviar un paquete sin tener que conocer las millones de placas individuales que existen.

Toda dirección IPv4 mide **32 bits** (escritos para humanos como 4 números de `0` a `255` separados por puntos, ej. `10.0.20.50`) y siempre va acompañada de una **Máscara de Subred (`CIDR`, ej. `/24`)**. La máscara es simplemente una línea divisoria que dice: **"De estos 32 bits, los primeros $N$ bits de la izquierda identifican al Barrio (la Red) y los bits restantes de la derecha identifican a la Casa dentro de ese barrio (el Host)"**.

---

## 🎯 ¿Por qué importa en el día a día?

Una decisión de direccionamiento mal pensada al principio persigue a una empresa durante años: cuando una subred `/24` se queda chica, cuando querés unir dos sucursales por VPN y **ambas usan `192.168.1.0/24`** (colisión de subredes), o cuando contratás un proveedor de fibra y no te anda ningún Port Forwarding porque te entregaron una IP de **CGNAT (`100.64.x.x`)**.

- **En diseño:** Un esquema jerárquico limpio (`10.<Sede>.<VLAN>.<Host>/24`) permite que cualquier técnico vea la IP `10.3.100.45` y sepa en 1 segundo que es la **Cámara 45 (`VLAN 100`) de la Sucursal 3 (`Sede 3`)**, además de permitir resumir toda la sucursal en una sola ruta `10.3.0.0/16`.
- **En operación/mantenimiento:** Dominar **VLSM (*Variable Length Subnet Mask*)** te permite no desperdiciar un bloque de 254 IPs (`/24`) en un enlace punto a punto entre dos routers que solo necesita 2 IPs (`/30` o `/31`).
- **En troubleshooting:** La mitad de los problemas del tipo *"le puse IP fija al servidor y llega a las PCs locales pero no sale a otras redes"* se deben a una máscara mal puesta (ej. poner `/16` donde iba `/24` o viceversa) que engaña al equipo sobre qué destinos están en su propio barrio y cuáles requieren ir al Default Gateway.

---

## ⚙️ Cómo funciona por dentro

### 1. Cómo decide un equipo si debe hablar directo (ARP) o ir al Router (Gateway)

Antes de enviar cualquier paquete, el sistema operativo toma su propia IP, la IP destino y **su propia máscara de subred** para responder una única pregunta: **"¿El destino vive en mi misma cuadra o en otro barrio?"**

```text
Tu PC:      10.0.10.50   con máscara /24 (255.255.255.0 -> los primeros 3 números son el Barrio)
Barrio:     10.0.10.x    (desde 10.0.10.0 hasta 10.0.10.255)

Caso A: Querés hablar con 10.0.10.200 (Impresora)
        ¿Empieza con 10.0.10.? -> ¡SÍ! Es mi mismo barrio.
        Acción: NO uso al router. Pido la MAC de 10.0.10.200 por ARP directo en Capa 2.

Caso B: Querés hablar con 10.0.40.10 (Servidor en otra VLAN) o 8.8.8.8 (Internet)
        ¿Empieza con 10.0.10.? -> ¡NO! Es otro barrio.
        Acción: Pido por ARP la MAC de mi DEFAULT GATEWAY (10.0.10.1) y le entrego el paquete al Router.
```

### 2. Cálculo mental instantáneo de Subredes (CIDR y VLSM)

Una dirección IPv4 tiene `32 bits` (4 octetos de `8 bits` cada uno). Cuando escribís **`/N`** (notación **CIDR**), los bits que quedan libres para hosts son **`32 - N`**, y la cantidad total de direcciones del bloque es siempre **$2^{(32 - N)}$**.

En cada subred normal (de `/8` a `/30`), **siempre se restan 2 direcciones reservadas** que nunca se pueden asignar a una PC:

1. **La primera dirección del bloque (todos los bits de host en `0`):** Es la **Dirección de Red** (el nombre del barrio, ej. `10.0.10.0`).
2. **La última dirección del bloque (todos los bits de host en `1`):** Es la **Dirección de Broadcast** (el megáfono para gritarle a todos los vecinos del barrio a la vez, ej. `10.0.10.255`).

| Prefijo CIDR | Máscara Decimal | Total de IPs ($2^{32-N}$) | Hosts Útiles ($Total - 2$) | Uso real en arquitectura de redes |
|:------------:|-----------------|:-------------------------:|:--------------------------:|-----------------------------------|
| **`/32`** | `255.255.255.255` | `1` | `1` (Host exacto) | Interfaz **Loopback** de routers (OSPF/BGP Router-ID) y reglas de firewall a 1 sola IP |
| **`/31`** | `255.255.255.254` | `2` | `2` (`RFC 3021`) | Enlace punto a punto entre 2 routers sin desperdiciar IP de red ni broadcast |
| **`/30`** | `255.255.255.252` | `4` | `2` (`.1` y `.2`) | **El estándar clásico punto a punto** entre dos routers o túnel VPN Site-to-Site |
| **`/29`** | `255.255.255.248` | `8` | `6` (`.1` a `.6`) | Bloque pequeño de IPs públicas fijas de ISP o red entre firewalls en alta disponibilidad (VRRP) |
| **`/28`** | `255.255.255.240` | `16` | `14` (`.1` a `.14`) | Subred chica para sala de servidores, switches de gestión o enlaces de radio |
| **`/27`** | `255.255.255.224` | `32` | `30` (`.1` a `.30`) | Sucursal pequeña o VLAN de impresoras / control de acceso |
| **`/26`** | `255.255.255.192` | `64` | `62` (`.1` a `.62`) | Un cuarto de `/24`: piso de oficina mediano o VLAN de cámaras IP |
| **`/25`** | `255.255.255.128` | `128` | `126` (`.1–.126` o `.129–.254`) | Medio `/24`: departamento grande de 80–100 puestos |
| **`/24`** | `255.255.255.0` | `256` | **`254`** (`.1` a `.254`) | 🏆 **El estándar de oro en LANs corporativas:** fácil de leer a simple vista (1 VLAN = 1 tercer octeto) |
| **`/23`** | `255.255.254.0` | `512` | **`510`** | Dos `/24` pegados: ideal para **WiFi de Invitados o Eventos** donde entran 300+ celulares |
| **`/22`** | `255.255.252.0` | `1.024` | `1.022` | Cuatro `/24` pegados: campus universitario o WiFi público masivo |
| **`/16`** | `255.255.0.0` | `65.536` | `65.534` | **Resumen completo de una Sede o Sucursal** (`10.Sede.0.0/16`) que adentro contiene hasta 256 VLANs `/24` |

---

### 3. Los Bloques Especiales IPv4 que tenés que reconocer al instante

Cuando mirás la IP de una interfaz WAN o LAN, los primeros números te dicen inmediatamente qué tipo de red es:

| Bloque IPv4 | Estándar | Nombre Técnico | Cómo identificarlo y qué implica en producción |
|-------------|----------|----------------|------------------------------------------------|
| **`10.0.0.0/8`** (`10.0.0.0` – `10.255.255.255`) | `RFC 1918` | **Privada Clase A** | ✅ **El mejor bloque para empresas:** te da `16 millones` de IPs para estructurar `10.<Sede>.<VLAN>.<Host>/24` sin quedarte corto jamás |
| **`172.16.0.0/12`** (`172.16.0.0` – `172.31.255.255`) | `RFC 1918` | **Privada Clase B** | ✅ Ideal para redes internas de contenedores Docker/Kubernetes, túneles VPN o DMZ (`172.16.x.x` hasta `172.31.x.x`; ¡ojo que `172.32.x.x` ya es IP pública!) |
| **`192.168.0.0/16`** (`192.168.0.0` – `192.168.255.255`) | `RFC 1918` | **Privada Clase C** | ⚠️ **Evitar `192.168.0.0/24` y `192.168.1.0/24` en empresas:** todos los módems domésticos usan esa subred; cuando un empleado se conecte por VPN desde su casa, su red local chocará con la de la oficina |
| **`100.64.0.0/10`** (`100.64.0.0` – `100.127.255.255`) | `RFC 6598` | **CGNAT (*Carrier-Grade NAT*)** | 🚨 **Crítico en ISPs:** Si en la boca WAN de tu router ves una IP entre `100.64.x.x` y `100.127.x.x`, **NO tenés IP pública real**. Tu proveedor te metió detrás de un NAT gigante compartido con otros clientes. **Ningún Port Forwarding ni VPN entrante va a funcionar** (debés pedir IP pública al ISP o usar WireGuard/Tailscale saliente) |
| **`169.254.0.0/16`** | `RFC 3927` | **Link-Local / APIPA** | ❌ **Diagnóstico inmediato:** Cuando una PC o cámara pide IP por DHCP y **nadie le responde**, se autoasigna `169.254.x.x`. Siempre que veas `169.254.x.x`, falló el servidor DHCP o la VLAN en el switch |
| **`127.0.0.0/8`** (`127.0.0.1`) | `RFC 1122` | **Loopback local del host** | Tráfico interno del propio sistema operativo; nunca sale por la placa de red física |
| **`224.0.0.0/4`** (`224.x` a `239.x`) | `RFC 5771` | **Multicast** | Usado por protocolos de red para hablar entre routers sin molestar a las PCs: `224.0.0.5/6` (OSPF), `224.0.0.18` (VRRP), `224.0.0.102` (HSRP), `224.0.0.251` (mDNS) |

---

### 4. Patrón Profesional: Cómo diseñar el direccionamiento de una empresa multi-sede

Nunca asignes subredes al azar (`192.168.1.0/24`, `192.168.2.0/24`). Usá la fórmula **`10.<SEDE>.<VLAN>.<HOST>/24`** combinada con **VLSM** en un bloque de infraestructura:

```text
ESQUEMA CORPORATIVO ESCALABLE: 10.<SEDE>.<VLAN>.<HOST>
===================================================================================
Sede 1: Casa Central -> Todo su bloque es 10.1.0.0/16 (Se resume en 1 sola ruta /16)
  ├── 10.1.10.0/24   -> VLAN 10  (Administración / Staff)      Gateway: 10.1.10.1
  ├── 10.1.20.0/24   -> VLAN 20  (Sistemas / IT)               Gateway: 10.1.20.1
  ├── 10.1.40.0/24   -> VLAN 40  (Servidores Producción)       Gateway: 10.1.40.1
  ├── 10.1.99.0/24   -> VLAN 99  (Management Switches/APs)     Gateway: 10.1.99.1
  ├── 10.1.100.0/24  -> VLAN 100 (Cámaras IP / CCTV)           Gateway: 10.1.100.1
  └── 10.1.200.0/23  -> VLAN 200 (WiFi Invitados — 510 hosts!) Gateway: 10.1.200.1

Sede 2: Sucursal Norte -> Todo su bloque es 10.2.0.0/16
  ├── 10.2.10.0/24   -> VLAN 10  (Administración Sucursal 2)   Gateway: 10.2.10.1
  ├── 10.2.99.0/24   -> VLAN 99  (Management Sucursal 2)       Gateway: 10.2.99.1
  └── 10.2.100.0/24  -> VLAN 100 (Cámaras Sucursal 2)          Gateway: 10.2.100.1

Bloque de Enlaces Punto a Punto y Loopbacks (Sede 0 = Core / Backbone con VLSM):
  ├── 10.0.0.1/32, 10.0.0.2/32         -> Loopbacks de Routers (OSPF Router-ID)
  ├── 10.0.255.0/30  (.1 y .2)         -> Túnel VPN Casa Central <-> Sucursal 2
  └── 10.0.255.4/30  (.5 y .6)         -> Enlace Router Core <-> Firewall
```

**Orden interno dentro de cada `/24`:**

- **`.1`** → Siempre el **Default Gateway** (o IP Virtual VRRP; `.2` y `.3` para los routers físicos).
- **`.2` a `.49`** → IPs estáticas de infraestructura (servidores, switches, impresoras, NVR).
- **`.50` a `.99`** → Reservas estáticas DHCP (`dhcp-host` / `Make Static`).
- **`.100` a `.240`** → Pool dinámico DHCP para usuarios.
- **`.241` a `.254`** → Libres para diagnóstico o crecimiento temporal.

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

| Operación de Capa 3 | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Aruba / Ubiquiti / TP-Link | Linux (`iproute2`) |
|---------------------|----------------------|----------------------|----------------------------|--------------------|
| **Formato al escribir IP y máscara** | Máscara decimal separada: `ip address 10.1.10.1 255.255.255.0` | Notación CIDR directa: `/ip address add address=10.1.10.1/24 interface=vlan10` | CIDR o decimal: `ip address 10.1.10.1/24` | Notación CIDR directa: `ip addr add 10.1.10.1/24 dev eth0.10` |
| **Máscara invertida en ACLs** | **Wildcard Mask**: `0.0.0.255` (`255.255.255.255 - máscara`) | No usa wildcard; usa CIDR normal `10.1.10.0/24` | Wildcard `0.0.0.255` en ACLs estilo Cisco | Usa CIDR normal `10.1.10.0/24` |
| **Ver todas las IPs configuradas** | `show ip interface brief` | `/ip address print` | `show ip` | `ip -br addr show` |
| **Crear interfaz Loopback (`/32`)** | `interface Loopback0` + `ip address 10.0.0.1 255.255.255.255` | `/interface bridge add name=lo0` (o usar `lo` nativo en v7.14+) + `/ip address add address=10.0.0.1/32` | `interface loopback 0` | `ip addr add 10.0.0.1/32 dev lo` |

> **⚠️ Error clásico en MikroTik:** Si en `/ip address add` escribís `address=10.1.10.1` **y te olvidás de poner `/24` al final**, RouterOS asume automáticamente **`/32` (un solo host)**. El router responderá al ping a sí mismo, pero **ninguna PC de la red `10.1.10.0/24` podrá usarlo como gateway** porque el router creerá que su red empieza y termina en `.1`.

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Parámetro `network` en `/ip address print` de MikroTik** | `address=10.1.10.1/24 network=10.1.10.0` | `address=10.1.10.1/32 network=10.1.10.1` | Te olvidaste de escribir `/24` al cargar la IP en MikroTik y quedó como `/32` |
| **IP recibida por una PC o cámara en DHCP** | `10.1.10.105/24`, Gateway `10.1.10.1` | `169.254.45.12/16` (sin Default Gateway) | **APIPA:** El cliente nunca recibió respuesta del servidor DHCP (revisar PVID/Trunk de la VLAN o pool DHCP lleno) |
| **IP en interfaz WAN vs IP vista en `ifconfig.me`** | Ambas muestran la misma IP pública (ej. `190.210.x.x`) | La WAN del router tiene `100.72.14.88` y `ifconfig.me` muestra `181.45.x.x` | **Estás detrás de CGNAT (`100.64.0.0/10`)** del proveedor de Internet (doble NAT). No podrás abrir puertos entrantes directamente |
| **Ping dentro de la LAN ok, pero falla hacia una subred específica** | `10.1.10.50/24` llega a `10.1.20.10` a través del gateway | `10.1.10.50` llega a Internet pero **no llega a `10.1.20.10`** | Alguien configuró en `10.1.10.50` la máscara equivocada **`/16` (`255.255.0.0`)** en vez de `/24`: la PC cree que `10.1.20.10` está en su mismo cable Capa 2 y manda un ARP directo en vez de enviarlo al router |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Usar `192.168.1.0/24` o `192.168.0.0/24` para la red interna de una empresa o servidor:** Funciona bien en la oficina hasta el primer día que configurás una VPN de teletrabajo (*Roadwarrior*). Cuando el gerente se conecta a la VPN desde el WiFi de su casa (cuyo módem Movistar/Claro/Fibertel también usa `192.168.1.0/24`), su laptop quiere ir al servidor `192.168.1.10` de la empresa y **busca el paquete en el living de su propia casa en vez de mandarlo por el túnel VPN**.
- **❌ Creer que una dirección terminada en `.0` o `.255` jamás puede ser un host válido:** Eso solo es cierto en una máscara **`/24`** (o más chica). En una red **`/23`** (que va de `10.1.200.0` a `10.1.201.255`), la dirección de red es `10.1.200.0` y el broadcast es `10.1.201.255`, por lo tanto **`10.1.200.255` y `10.1.201.0` están justo en la mitad del bloque y son dos IPs de host 100% válidas y utilizables**.
- **❌ Desperdiciar una `/24` (254 IPs) para unir dos routers:** Si usás `10.1.255.0/24` para un cable entre dos routers donde solo hay 2 puntas (`.1` y `.2`), además de desperdiciar 252 direcciones, abrís la puerta a ataques de *ARP exhaustion* en ese enlace si alguien escanea las 252 IPs vacías. Usá siempre **`/30`** (o **`/31`**).

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

Una empresa adquiere una nueva sucursal en Córdoba y contrata un enlace de fibra óptica para instalar cámaras y acceso remoto al ERP. El administrador configura un túnel VPN IPsec y un Port Forwarding en el router MikroTik de Córdoba hacia el grabador NVR (`TCP 37777`). Sin embargo, **desde Casa Central nadie puede conectarse a la IP pública de Córdoba ni levanta la VPN entrante**, aunque en Córdoba navegan a `500 Mbps` sin problemas.

### Análisis paso a paso por capas

1. **Síntoma observado:** Salida a Internet perfecta desde la sucursal, pero **cero conexiones entrantes** desde el exterior a cualquier puerto del router.
2. **Hipótesis usando el modelo mental (Capa 3 — Verificación de IP WAN contra bloques RFC):**
   - Antes de culpar a las reglas de firewall o de `dst-nat`, miramos qué dirección IP le entregó por DHCP o PPPoE el módem del proveedor de fibra a la interfaz `ether1-wan` del MikroTik (`/ip address print where interface=ether1-wan`).
3. **Evidencia que lo confirma:**
   - La interfaz WAN tiene asignada la IP **`100.89.112.45/22`**.
   - `100.89.x.x` cae exactamente dentro del bloque **`100.64.0.0/10` (RFC 6598 — Carrier-Grade NAT / CGNAT)**.
   - El proveedor de Internet de Córdoba no le entregó una IP pública real a la sucursal: los paquetes que alguien envía desde afuera a la IP pública que muestra Google (`186.12.x.x`) mueren en el router de borde del ISP porque esa IP pública la comparten 64 hogares y el ISP no sabe a cuál reenviarle el puerto 37777.
4. **Resolución arquitectónica:**
   - **Solución inmediata sin esperar al ISP:** Como Casa Central sí tiene una IP pública fija real, configuramos el túnel **WireGuard Site-to-Site** para que sea el router de Córdoba quien **inicie la conexión saliente** hacia Casa Central (`persistent-keepalive=25s`). Una vez establecido el túnel saliente, Casa Central accede al NVR y a toda la red de Córdoba (`10.2.0.0/16`) por rutas internas privadas sin necesitar abrir ni un solo puerto público en Córdoba.

---

## 🧠 Modelo mental

Pensá en esto como **el código postal y la numeración de lotes de un barrio cerrado**:

- **La Dirección IP (`10.1.10.50`)** es tu dirección completa, y **la Máscara CIDR (`/24`)** es el límite del alambrado del barrio: te dice hasta dónde llega tu propio vecindario (`10.1.10.1` al `.254`) donde podés caminar directo a tocarle el timbre a un vecino (**ARP en Capa 2**), y a partir de qué número tenés que ir sí o sí a la garita de salida principal (**el Default Gateway en `.1`**) para que te lleve a otra ciudad.
- **La primera casa (`.0` — Dirección de Red)** es el cartel con el nombre del barrio en la entrada, y **la última casa (`.255` — Broadcast)** es el altoparlante de la plaza central que se escucha en todas las casas del barrio al mismo tiempo. Por eso nadie puede mudarse a vivir al `.0` ni al `.255`.
- **VLSM** es lotear con sentido común: usar una manzana entera de 254 terrenos (`/24`) para un edificio de oficinas lleno de gente, pero usar un pasillo chiquito de solo 2 lugares (`/30`) para el puente que une las dos garitas de seguridad.

---

## 🧪 Autoevaluación rápida (Active Recall)

Respondé mentalmente antes de desplegar cada respuesta; si dudás, volvé a la sección correspondiente del documento.

**1. Tenés que unir dos routers con un cable punto a punto. ¿Por qué conviene un `/30` o `/31` en vez de gastar un `/24`?**

<details>
<summary>👀 Ver respuesta explicada</summary>

Porque el enlace solo necesita 2 puntas (`.1` y `.2`). Un `/30` da 4 direcciones (2 útiles) y un `/31` (`RFC 3021`) ofrece 2 útiles sin reservar red ni broadcast. Un `/24` desperdicia `252` direcciones y abre la puerta a *ARP exhaustion* si alguien escanea esas IPs vacías.

</details>

**2. Una cámara IP recién instalada aparece con una IP `169.254.x.x` y sin Default Gateway. ¿Qué está pasando y dónde mirás?**

<details>
<summary>👀 Ver respuesta explicada</summary>

Es **APIPA** (`RFC 3927`): el cliente pidió IP por DHCP y nadie respondió, así que se autoasignó una dirección link-local `169.254.0.0/16`. Hay que revisar el servidor DHCP o el **PVID/Trunk** de la VLAN en el switch (una trama *untagged* cayendo en la VLAN equivocada explica el fallo).

</details>

**3. En MikroTik escribís `/ip address add address=10.1.10.1 interface=vlan10` y el gateway "no anda". ¿Cuál es el error y cómo lo detectás?**

<details>
<summary>👀 Ver respuesta explicada</summary>

Te olvidaste el `/24` al final, por lo que RouterOS asume **`/32`** (un solo host): el router se hace ping a sí mismo pero cree que su red termina en `.1`, así que ninguna PC de `10.1.10.0/24` lo usa como gateway. Lo detectás cuando `/ip address print` muestra `address=10.1.10.1/32 network=10.1.10.1` en vez de `network=10.1.10.0`.

</details>

---

## 🔗 Ver también

- [`osi-and-tcp-ip-models`](osi-and-tcp-ip-models.md) — Cómo el paquete IPv4 de Capa 3 viaja adentro de la trama Ethernet de Capa 2
- [`routing-fundamentals-static-and-dynamic`](routing-fundamentals-static-and-dynamic.md) — Cómo usa el Router estas máscaras CIDR para decidir por qué camino mandar cada paquete (*Longest Prefix Match*)
- [`tcp-udp-mtu-and-nat-conntrack`](tcp-udp-mtu-and-nat-conntrack.md) — Cómo funciona el NAT que permite que 254 IPs privadas (`RFC 1918`) salgan a Internet compartiendo 1 sola IP pública
