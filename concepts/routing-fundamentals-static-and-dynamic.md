⬅️ [Volver a Conceptos](README.md)

# Fundamentos de Enrutamiento (Capa 3) — Tablas de rutas, Longest Prefix Match, Inter-VLAN y OSPF/BGP

**Capa OSI principal:** Capa 3 (Red) | **Estándares:** `RFC 1812`, `RFC 2328 (OSPFv2)`, `RFC 4271 (BGP-4)`, `IEEE 802.1Q`

---

## 🧠 ¿Qué es?

El **Enrutamiento (*Routing*)** es el proceso por el cual un paquete IP viaja desde una subred de origen hasta una subred de destino a través de uno o más **Routers** (o Switches Capa 3).

A diferencia de un switch de Capa 2 (que solo mueve tramas dentro de una misma VLAN mirando direcciones MAC), un **Router es un puesto fronterizo entre redes distintas**: recibe una trama dirigida a su propia MAC, **arranca y destruye la cabecera Ethernet entrante**, extrae el paquete IP, mira únicamente la **Dirección IP Destino**, busca en su **Tabla de Enrutamiento** cuál es la mejor puerta de salida (*Next-Hop*), **resta `1` al campo `TTL`**, arma una **nueva cabecera Ethernet** y despacha el paquete hacia el siguiente salto.

---

## 🎯 ¿Por qué importa en el día a día?

Casi todos los cortes graves al crecer una red (cuando agregás una segunda conexión a Internet, una VPN hacia una sucursal o separás la empresa en VLANs) ocurren por no entender **cómo elige el router entre dos rutas posibles** o por olvidar que **los paquetes necesitan tanto ruta de ida como ruta de vuelta**.

- **En diseño:** Te permite decidir cuándo basta con un **Router-on-a-Stick (ROAS)** y cuándo el tráfico interno entre servidores y usuarios exige un **Switch Capa 3 (SVIs)** con enrutamiento en chip a `10 Gbps+`.
- **En operación/mantenimiento:** Entender la diferencia entre **Longest Prefix Match** (especificidad `/25` vs `/24`) y **Distancia Administrativa** te permite redirigir tráfico en vivo o armar un failover automático entre dos enlaces sin cortar ni un paquete.
- **En troubleshooting:** El error número 1 en redes con VPNs o múltiples routers es el **problema de la ruta de retorno**: el paquete llega perfecto al servidor destino, pero el servidor destino no sabe por qué router devolver la respuesta y la tira por su salida a Internet.

---

## ⚙️ Cómo funciona por dentro

### 1. Las 3 leyes de decisión de todo Router (En orden estricto de prioridad)

Cuando un router tiene varias rutas en su memoria y llega un paquete hacia la IP `10.1.20.50`, **¿cómo decide cuál ruta usar?** Todo router del mundo (Cisco, MikroTik, Juniper, Fortinet o Linux) aplica estas **3 reglas en este orden exacto** (y la Regla #1 siempre aplasta a las demás):

```text
                  [Llega paquete con IP Destino: 10.1.20.50]
                                      |
                                      v
+---------------------------------------------------------------------------+
| REGLA 1 (SUPREMA): LONGEST PREFIX MATCH (La máscara más específica gana)  |
| ¿Tengo rutas que coincidan con 10.1.20.50?                                |
|   - Ruta A: 0.0.0.0/0      (Coinciden 0 bits)                             |
|   - Ruta B: 10.1.0.0/16    (Coinciden 16 bits)                            |
|   - Ruta C: 10.1.20.0/24   (Coinciden 24 bits)                            |
|   - Ruta D: 10.1.20.0/25   (Coinciden 25 bits) ---> ¡GANA LA /25 SIEMPRE! |
| (No importa si la /24 era estática y la /25 vino por OSPF: ¡/25 es más    |
|  específica y entra sola a la tabla de reenvío!)                          |
+---------------------------------------------------------------------------+
                                      |
            ¿Y si hay EMPATE en la misma máscara exacta (ej. dos rutas /24)?
                                      v
+---------------------------------------------------------------------------+
| REGLA 2: DISTANCIA ADMINISTRATIVA (AD — ¿Qué protocolo es más confiable?) |
| Si recibo exactamente 10.1.20.0/24 por Ruta Estática (AD=1) y también     |
| 10.1.20.0/24 por OSPF (AD=110) ---> ¡GANA LA DE MENOR AD (Estática = 1)!  |
+---------------------------------------------------------------------------+
                                      |
            ¿Y si hay EMPATE en la misma máscara (/24) Y el mismo protocolo (OSPF)?
                                      v
+---------------------------------------------------------------------------+
| REGLA 3: MÉTRICA / COSTO (¿Cuál camino del mismo protocolo es más corto?) |
| Entre dos caminos OSPF hacia 10.1.20.0/24, gana el de menor Costo (o si   |
| empatan en costo, hace balanceo ECMP — Equal-Cost Multi-Path).            |
+---------------------------------------------------------------------------+
```

### 2. Tabla de Distancia Administrativa (AD) Multi-Vendor

La **Distancia Administrativa** (`0` a `255`, donde **`0` es certeza absoluta y `255` es inalcanzable**) mide cuánto confía el router en la fuente de esa ruta cuando dos protocolos le anuncian **exactamente el mismo prefijo con la misma máscara**:

| Origen de la Ruta | AD en Cisco IOS | AD en MikroTik RouterOS v7 | AD en Linux / FRRouting | Por qué tiene esa prioridad |
|-------------------|:---------------:|:--------------------------:|:-----------------------:|-----------------------------|
| **Directly Connected (`C`)** | **`0`** | **`0`** | **`0`** | La interfaz tiene un cable puesto en esa subred: nadie sabe mejor que ella |
| **Static Route (`S`)** | **`1`** | **`1`** | **`1`** | El ingeniero humano la escribió a mano: le gana a cualquier protocolo dinámico |
| **eBGP (BGP Externo)** | **`20`** | **`20`** | **`20`** | Rutas acordadas directamente con otro Sistema Autónomo / ISP |
| **OSPF Interno (`O`)** | **`110`** | **`110`** | **`110`** | Protocolo estándar de estado de enlace para redes internas empresariales |
| **RIP (`R`)** | `120` | `120` | `120` | Protocolo antiguo por conteo de saltos |
| **iBGP (BGP Interno)** | **`200`** | **`200`** | **`200`** | Para evitar bucles dentro del propio AS (OSPF interno siempre debe ganarle) |
| **Ruta Flotante de Backup** | **`210` – `250`** (manual) | **`2` – `250`** (`distance=10`) | **`10` – `250`** (`metric`) | Ruta estática configurada a propósito con AD más alta para que quede dormida mientras viva la ruta principal |

---

### 3. Inter-VLAN Routing: Router-on-a-Stick (ROAS) vs Switch Capa 3 (SVI)

Una vez que separaste tu empresa en VLANs (`VLAN 10 Usuarios`, `VLAN 40 Servidores`), ¿quién hace que la PC de la VLAN 10 llegue a la base de datos de la VLAN 40? Tenés **dos arquitecturas**:

```text
ARQUITECTURA A: ROUTER-ON-A-STICK (ROAS)            ARQUITECTURA B: SWITCH CAPA 3 (SVIs en Hardware)
   +-----------------------+                           +-----------------------+
   |   Router / Firewall   |                           |   Router / Firewall   |
   |  eth0.10 (10.0.10.1)  |                           |    (Solo para WAN     |
   |  eth0.40 (10.0.40.1)  |                           |     e inspección)     |
   +-----------------------+                           +-----------------------+
             ||  1 solo cable Trunk                              | Enlace L3 (/30): 10.0.255.0/30
             ||  (El tráfico sube y baja                         v
             ||   por el mismo cable!)                 +-----------------------+
   +-----------------------+                           |    SWITCH CAPA 3      |
   |      SWITCH L2        |                           | SVI Vlan10: 10.0.10.1 | <-- ¡Enruta adentro
   +-----------------------+                           | SVI Vlan40: 10.0.40.1 |     del chip ASIC
      /                 \                              +-----------------------+     a 10/100 Gbps!
  [PC VLAN 10]     [Servidor VLAN 40]                     /                 \
                                                     [PC VLAN 10]     [Servidor VLAN 40]
```

| Criterio | A. Router-on-a-Stick (ROAS) | B. Switch Capa 3 (SVIs — *Switched Virtual Interfaces*) |
|----------|-----------------------------|---------------------------------------------------------|
| **Dónde vive el Default Gateway (`.1`) de las VLANs** | En subinterfaces VLAN del **Router / Firewall** (`Gi0/0.10`, `/interface vlan`) | Adentro del propio **Switch Core L3** (`interface Vlan10` en Cisco, `/interface vlan` con `l3-hw-offloading=yes` en MikroTik CRS3xx) |
| **Rendimiento entre VLANs internas** | Limitado por la CPU del router y por el ancho de banda del único cable Trunk (el paquete sube por el trunk en VLAN 10 y baja por el mismo cable en VLAN 40) | **Velocidad de cable (*Wire-Speed*, decenas de Gbps)** porque el chip ASIC del switch enruta en hardware sin subir al router |
| **Control de seguridad / Firewall entre VLANs** | 🏆 **Máximo:** Como todo cruza el Firewall, aplicás reglas Stateful fácilmente (`ESTABLISHED,RELATED`) | ⚠️ **Atención:** Un switch L3 enruta todo entre todas sus SVIs a máxima velocidad; para bloquear tráfico allí debés usar ACLs stateless de hardware (o dejar en el Firewall las VLANs críticas como DMZ/Invitados) |
| **Cuándo elegirlo** | PYMEs, sucursales o cuando querés filtrar cada VLAN en un único firewall central (MikroTik/FortiGate/pfSense) | Redes medianas/grandes con mucho tráfico Este-Oeste (copias a servidores NAS, backups, cámaras a NVR, virtualización) |

---

### 4. Enrutamiento Estático vs Dinámico (OSPF y BGP)

- **Rutas Estáticas:** Ideales cuando tenés 1 o 2 routers (ej. la ruta por defecto `0.0.0.0/0` hacia el ISP y una ruta hacia una sucursal). Son simples, predecibles y no consumen CPU.
- **OSPF (*Open Shortest Path First* — Protocolo IGP interno):** Cuando tenés 3 o más routers, enlaces redundantes o múltiples sucursales con túneles VPN. Los routers se mandan saludos (`Hello` cada 10s al multicast `224.0.0.5`), arman un mapa completo de la red (**LSDB**) y calculan con el algoritmo de **Dijkstra (SPF)** el camino más rápido. Si un enlace se corta, OSPF recalcula las rutas de toda la empresa en menos de 2 segundos.
- **BGP (*Border Gateway Protocol* — Protocolo EGP e infraestructura a gran escala):** El protocolo que mueve todo Internet (basado en **Sistemas Autónomos — AS** y sesiones `TCP puerto 179`) y que también se usa internamente en Data Centers modernos (*Leaf-Spine*), nubes (AWS/GCP Direct Connect) o cuando una empresa u hospital tiene su propio bloque de IPs públicas anunciado por dos proveedores de fibra distintos.

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

| Concepto de Capa 3 | Cisco IOS / Catalyst L3 | MikroTik RouterOS v7 | Aruba / HP L3 | Linux (`iproute2` / `FRRouting`) |
|--------------------|-------------------------|----------------------|---------------|----------------------------------|
| **Habilitar enrutamiento IP en el equipo** | `ip routing` (obligatorio en Switches L3) | Activo por defecto siempre (para ASIC en CRS3xx: `l3-hw-offloading=yes`) | `ip routing` | `sysctl -w net.ipv4.ip_forward=1` |
| **Ver tabla de enrutamiento (RIB)** | `show ip route` | `/ip route print` | `show ip route` | `ip route show` |
| **Preguntar qué ruta ganará para una IP** | `show ip route 10.2.10.50` / `show ip cef 10.2.10.50` | `/ip route check 10.2.10.50` | `show ip route 10.2.10.50` | `ip route get 10.2.10.50` |
| **Ruta por defecto (Default Gateway `0.0.0.0/0`)** | `ip route 0.0.0.0 0.0.0.0 203.0.113.1` | `/ip route add dst-address=0.0.0.0/0 gateway=203.0.113.1` | `ip route 0.0.0.0/0 203.0.113.1` | `ip route add default via 203.0.113.1` |
| **Ruta estática flotante (Backup con AD=10)** | `ip route 10.2.0.0 255.255.0.0 10.0.255.6 10` | `/ip route add dst-address=10.2.0.0/16 gateway=10.0.255.6 distance=10` | `ip route 10.2.0.0/16 10.0.255.6 distance 10` | `ip route add 10.2.0.0/16 via 10.0.255.6 metric 10` |
| **Ruta Blackhole / Null0 (descartar sin bucles)** | `ip route 10.1.0.0 255.255.0.0 Null0 250` | `/ip route add dst-address=10.1.0.0/16 blackhole distance=250` | `ip route 10.1.0.0/16 reject` | `ip route add blackhole 10.1.0.0/16` |

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Salida de `traceroute` / `mtr` hacia otra sede** | Avanza en 2 o 3 saltos limpios hasta la IP destino final | Repite infinitamente los mismos dos routers (`10.0.255.1 -> 10.0.255.2 -> 10.0.255.1`) hasta dar **`!H` / `TTL exceeded in transit`** | **Bucle de enrutamiento (*Routing Loop*):** el Router A apunta al Router B para esa red y el Router B apunta de vuelta al Router A (o a su default gateway hacia A) |
| **Ping desde el Router a la sucursal remota vs Ping desde una PC** | Ambos responden en el mismo tiempo (`15 ms`) | Desde la consola del Router A el ping a la Sucursal B **funciona**, pero desde las PCs detrás del Router A **no responde** | **Falta la ruta de retorno en el Router B:** cuando el Router A hace ping, usa como IP origen la del enlace (`/30`) que el Router B sí conoce; cuando hace ping una PC (`10.1.10.50`), el Router B recibe el paquete pero **no tiene ruta de vuelta hacia `10.1.10.0/24`** |
| **Estado de vecino OSPF (`show ip ospf neighbor`)** | **`Full/DR`**, **`Full/BDR`** o **`Full/-`** (en enlaces punto a punto) | Queda congelado en **`ExStart` / `Exchange`** o en **`Init`** | **`ExStart`**: Diferencia de **MTU** entre las dos interfaces de los routers. **`Init`**: Firewall bloqueando multicast `224.0.0.5` (protocolo IP 89) o enlace unidireccional |
| **Tráfico hacia una subred privada interna cuando cae su túnel VPN** | Si cae la VPN, el router devuelve `Network Unreachable` inmediato | Cuando cae la VPN, los paquetes hacia `10.2.10.50` salen por la boca WAN hacia el proveedor de Internet público | Falta una ruta **`blackhole / Null0`** de respaldo (con `distance=250`) para los bloques RFC 1918: al caer la ruta de la VPN, entra en acción el Default Gateway (`0.0.0.0/0`) y manda tráfico privado a Internet |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Olvidar que el enrutamiento es bidireccional (Ida + Vuelta):** Un paquete IP no lleva un hilo atado para saber cómo volver. El router de destino toma el paquete de respuesta, mira la IP de quien preguntó y **consulta su propia tabla de rutas desde cero**. Siempre que agregues una subred o VLAN nueva en un extremo de la red, preguntate: *"¿Todos los demás routers de la empresa saben por qué puerta volver hacia esta nueva subred?"*.
- **❌ Creer que si le ponés Distancia Administrativa `1` a una ruta `/16`, le va a ganar a una ruta `/24` de OSPF (AD `110`):** **Jamás.** La Regla 1 (*Longest Prefix Match*) se evalúa **antes** de mirar la Distancia Administrativa. Una ruta `/24` (aunque tenga AD `250`) siempre es más específica que una `/16` (aunque tenga AD `1`). La Distancia Administrativa **solo desempata cuando las dos rutas tienen exactamente la misma máscara**.
- **❌ Dejar OSPF enviando paquetes `Hello` por las VLANs donde están las PCs de los usuarios:** Si no configurás las interfaces de usuarios como **`passive-interface`** en OSPF, cualquier atacante en la oficina puede levantar un demonio OSPF en su laptop, formar vecindad con tu router principal e inyectar rutas falsas para interceptar todo el tráfico de la empresa. **OSPF solo debe hablar activamente en enlaces entre routers.**

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

Una empresa tiene su red central (`10.1.0.0/16`) conectada a la Sucursal Sur (`10.2.0.0/16`) mediante un enlace de fibra dedicada punto a punto (`10.0.255.0/30`), con una ruta estática `10.2.0.0/16` apuntando a la fibra. Como respaldo, instalan un túnel VPN sobre Internet y el administrador decide anunciar por OSPF únicamente la subred de servidores de la sucursal (`10.2.40.0/24`) por el túnel VPN, pensando: *"Como OSPF tiene Distancia Administrativa `110` y mi ruta estática por fibra tiene Distancia `1`, el tráfico a los servidores seguirá yendo por la fibra rápida y solo usará la VPN lenta si se corta la fibra"*.

Al día siguiente, todos se quejan de que el acceso a los servidores `10.2.40.x` de la sucursal va lentísimo, ¡aunque la fibra dedicada está 100% operativa!

### Análisis paso a paso por capas

1. **Síntoma observado:** El tráfico hacia `10.2.40.10` ignora la fibra rápida y se va por el túnel VPN lento.
2. **Hipótesis usando el modelo mental (Regla 1: Longest Prefix Match mata a Distancia Administrativa):**
   - Miramos la tabla de rutas del router central (`/ip route print where dst-address in 10.2.0.0/16`):
     - Ruta por fibra (Estática, `AD = 1`): **`10.2.0.0/16`**
     - Ruta por VPN (OSPF, `AD = 110`): **`10.2.40.0/24`**
3. **Evidencia que lo confirma:**
   - Ejecutamos `/ip route check 10.2.40.10` (o `show ip route 10.2.40.10` en Cisco). El router elige **`10.2.40.0/24` por la VPN**.
   - ¿Por qué? Porque `/24` (24 bits coincidentes) es un **prefijo más largo y específico** que `/16` (16 bits coincidentes). El router ni siquiera llegó a comparar la Distancia Administrativa `1` vs `110` porque la `/24` ganó en la Regla #1.
4. **Resolución arquitectónica:**
   - Hacemos que ambos caminos anuncien **exactamente la misma máscara** (`10.2.0.0/16` + `10.2.40.0/24`, o ambos por OSPF ajustando el `cost` de la interfaz VPN a `1000` y el de la fibra a `10`). Apenas igualamos la longitud del prefijo, el tráfico salta instantáneamente a la fibra de alta velocidad y la VPN queda como verdadero backup automático.

---

## 🧠 Modelo mental

Pensá en esto como **un sistema de carteles viales en las rotondas de una ruta nacional (donde cada rotonda es un Router)**:

- **La Tabla de Enrutamiento** son los carteles de salida de la rotonda, y **el *Longest Prefix Match* (Regla 1)** es la precisión de la dirección: si un cartel dice *"Salida 1: Hacia toda la Provincia de Córdoba (`/16`)"* y el cartel de al lado dice *"Salida 2: Hacia el Hospital Central de Córdoba, Calle Sarmiento 450 (`/24`)"*, si vos vas al Hospital Central **vas a tomar siempre la Salida 2 porque es más específica**, sin importar quién escribió el cartel.
- **La Distancia Administrativa (Regla 2)** recién importa cuando **dos carteles dicen exactamente el mismo destino con el mismo detalle** (*"Hospital Central (`/24`)"*): ahí sí le hacés caso al cartel oficial de Vialidad Nacional pintado en chapa (**Ruta Estática, `AD = 1`**) por encima de una indicación hablada por radio (**OSPF, `AD = 110`**).
- **Y la ruta de retorno** es recordar que para tener una conversación no alcanza con que exista una calle de ida hacia el hospital: el hospital también tiene que tener carteles en sus rotondas que indiquen cómo volver hasta tu casa.

---

## 🔗 Ver también

- [`ipv4-addressing-subnetting-and-vlsm`](ipv4-addressing-subnetting-and-vlsm.md) — Cómo diseñar bloques IP jerárquicos (`/16` y `/24`) para que las tablas de rutas sean limpias
- [`vlans-tagged-untagged-and-trunks`](vlans-tagged-untagged-and-trunks.md) — La base de Capa 2 sobre la que se apoya el enrutamiento Inter-VLAN (ROAS y SVI)
- [`first-hop-redundancy-vrrp-hsrp`](first-hop-redundancy-vrrp-hsrp.md) — Qué pasa si se quema la fuente del router que oficia de Default Gateway y cómo evitar el corte con VRRP/HSRP
