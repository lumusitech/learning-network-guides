⬅️ [Volver a Conceptos](README.md)

# VLANs (802.1Q), Tagged, Untagged, PVID y Trunks — El modelo mental unificado

**Capa OSI principal:** Capa 2 (Enlace de Datos) | **Estándares:** `IEEE 802.1Q`, `IEEE 802.1ad (QinQ)`

---

## 🧠 ¿Qué es?

Una **VLAN (*Virtual Local Area Network*)** es una partición lógica que divide un único switch físico en **múltiples switches virtuales completamente aislados entre sí en Capa 2**.

Si conectás una PC en el puerto 1 (asignado a la `VLAN 10 — Administración`) y una cámara IP en el puerto 2 (asignado a la `VLAN 100 — CCTV`) del mismo switch, **no se pueden ver, sus broadcasts ARP/DHCP no se cruzan y están tan aisladas como si hubieras comprado dos switches separados**. Para que el tráfico de múltiples VLANs pueda viajar de un switch a otro (o hacia un router) usando **un solo cable**, el estándar **IEEE 802.1Q** les inyecta una pequeña etiqueta (*Tag*) de **4 bytes** con el número de VLAN (`1` al `4094`).

---

## 🎯 ¿Por qué importa en el día a día?

Las VLANs son la columna vertebral de toda red profesional, pero también son **la principal fuente de confusión entre técnicos** porque **Cisco usa un vocabulario (`Access / Trunk / Native VLAN`) y MikroTik, Aruba, Ubiquiti y TP-Link usan otro (`Untagged / Tagged / PVID`)**.

- **En diseño:** Permite separar usuarios, servidores, cámaras CCTV, teléfonos VoIP, gestión de equipos (*Management*) y WiFi de invitados usando los mismos switches y el mismo cableado estructurado.
- **En operación/mantenimiento:** Si entendés el modelo de **Entrada (`Ingress / PVID`) vs Salida (`Egress / Tagged o Untagged`)**, podés conectar un switch Cisco contra un router MikroTik y un punto de acceso UniFi en 5 minutos sin que se pierda ninguna VLAN.
- **En troubleshooting:** El 90% de los problemas del tipo *"creé la VLAN nueva pero los equipos no reciben IP por DHCP"* se deben a que falta permitir esa VLAN como `tagged` en un puerto trunk intermedio o a que el `PVID` del puerto de acceso quedó en la VLAN 1.

---

## ⚙️ Cómo funciona por dentro

### 1. Qué le hace el estándar IEEE 802.1Q a la Trama Ethernet

Los dispositivos finales comunes (PCs, impresoras, Smart TVs, cámaras básicas) **no saben qué es una VLAN**: siempre envían y esperan recibir tramas Ethernet normales (**Untagged** — sin etiqueta).

Quien pone, lee y quita la etiqueta de 4 bytes es **el Switch** (o un Router / Hypervisor / Access Point empresarial):

```text
TRAMA NORMAL (UNTAGGED — lo que envía y recibe una PC común):
+-----------------+-----------------+------------+------------------+---------+
|   MAC Destino   |   MAC Origen    | EtherType  | Payload (Datos)  |   FCS   |
|    (6 bytes)    |    (6 bytes)    |  (0x0800)  | (46–1500 bytes)  | (4bytes)|
+-----------------+-----------------+------------+------------------+---------+

TRAMA ETIQUETADA (TAGGED 802.1Q — lo que viaja por el cable Trunk entre Switches/Routers):
+-----------------+-----------------+--------------------+------------+------------------+---------+
|   MAC Destino   |   MAC Origen    | TAG 802.1Q (4 B)   | EtherType  | Payload (Datos)  |Nuevo FCS|
|    (6 bytes)    |    (6 bytes)    | TPID=0x8100        |  (0x0800)  | (46–1500 bytes)  | (4bytes)|
+-----------------+-----------------+ PCP(3b)|DEI|VID=10 |------------+------------------+---------+
                                    +--------------------+
                                              ^
                                              |-- ¡Inyectado justo detrás de la MAC Origen!
                                                  (Y como la trama cambió, el switch recalcula el FCS)
```

### Anatomía del Tag 802.1Q (4 bytes = 32 bits)

| Subcampo del Tag | Tamaño | Valor típico | Función real | Qué pasa si está mal |
|------------------|--------|--------------|--------------|----------------------|
| **TPID (*Tag Protocol Identifier*)** | `16 bits` (`2 B`) | `0x8100` (`0x88a8` en QinQ) | Le avisa al switch receptor: *"¡Ojo! Esto no es el protocolo IP todavía, los próximos 2 bytes son una etiqueta VLAN"* | Si un puerto no espera tramas 802.1Q o tiene otro TPID configurado, descarta la trama |
| **PCP (*Priority Code Point*)** | `3 bits` | `0` a `7` (`802.1p` CoS) | Prioridad de calidad de servicio (QoS) en Capa 2 (ej. `5` para voz VoIP, `0` para tráfico normal) | Si no se preserva en los trunks, los paquetes de voz compiten igual que una descarga pesada |
| **DEI (*Drop Eligible Indicator*)** | `1 bit` | `0` o `1` | Indica si la trama puede descartarse primero en caso de congestión extrema | Rara vez se modifica manualmente |
| **VID (*VLAN Identifier*)** | `12 bits` | `1` a `4094` (`0` y `4095` reservados) | **El número de VLAN** ($2^{12} = 4096$ valores posibles). Define a qué dominio de broadcast pertenece la trama | Si ese `VID` no está dado de alta en la tabla de VLANs del switch receptor, el switch tira la trama en la puerta |

---

### 2. El Modelo Mental Definitivo: Qué pasa adentro del Switch (Ingress → Core → Egress)

Olvidate por un minuto de las marcas. **Adentro del chip de cualquier switch gestionable del planeta NO existen tramas "sin VLAN": adentro del switch TODA trama circula con un número de VLAN asignado.**

Por lo tanto, cada puerto físico del switch solo tiene que responder **dos preguntas**:

1. **Al ENTRAR al puerto (*Ingress*): "¿Si desde el cable me entra una trama desnuda (Untagged), qué número de camiseta (VLAN) le pongo?"**
   - Ese número por defecto de entrada se llama **PVID (*Port VLAN ID*)** (en Cisco: `access vlan` o `native vlan`).
2. **Al SALIR por el puerto (*Egress*): "¿Cuando una trama de la VLAN X quiere salir por este cable hacia afuera, le dejo la etiqueta puesta (`Tagged`) o se la arranco antes de entregarla (`Untagged`)?"**

```text
  [PC-1: Admin]                 [SWITCH GESTIONABLE A]                            [ROUTER / SWITCH B]
 (No entiende VLANs)     Puerto 2 (Access)      Puerto 1 (Trunk)                  (Entiende 802.1Q)
                         PVID = 10              Permitidas: 10, 20 (Tagged)
        |                                                                                 |
        | 1. Envía trama         2. INGRESS Pto 2:      3. EGRESS Pto 1:                  |
        |    DESNUDA (Untagged)     Entró desnuda ->       Sale por Trunk ->              |
        +-------------------------> Le clava VID=10 -----> Sale ETIQUETADA [Tag: VLAN 10]-+--> Recibe en eth0.10
        |                           (por su PVID=10)                                      |
        |                                                                                 |
        | 6. Recibe trama        5. EGRESS Pto 2:       4. INGRESS Pto 1:                 |
        |    DESNUDA (Untagged)     Pto 2 es Untagged ---> Entra con [Tag: VLAN 10] <-----+--- Envía con [Tag 10]
        |<------------------------- Le ARRANCA el Tag 10   El switch lee VID=10           |
```

### 3. Los 3 tipos de puertos explicados sin confusión

Con esa regla de Entrada (PVID) y Salida (Tagged/Untagged), los 3 tipos de puertos que existen en todas las marcas son simplemente combinaciones de lo mismo:

| Tipo de Puerto | Qué se conecta ahí | Regla de Entrada (Ingress) | Regla de Salida (Egress) |
|----------------|--------------------|----------------------------|--------------------------|
| **1. Puerto Access** (Puerto de usuario) | Una PC, impresora, servidor sin VLANs, cámara IP o Smart TV | Tiene **`PVID = X`** (ej. `10`). Toda trama desnuda que entra recibe la VLAN `10` | Saca la VLAN `10` como **`Untagged`** (le quita la etiqueta para que la PC la entienda). No deja salir ninguna otra VLAN |
| **2. Puerto Trunk Puro** (Enlace entre switches o hacia un Router) | Otro Switch, un Router (`Router-on-a-Stick`) o un servidor Proxmox/VMware | Solo acepta tramas que ya vengan con su etiqueta puesta (`admit-only-vlan-tagged`) | Saca múltiples VLANs (ej. `10, 20, 30, 99`) todas como **`Tagged`** conservando su etiqueta de 4 bytes |
| **3. Puerto Híbrido** (Trunk con Native VLAN / APs UniFi / Teléfonos IP) | Un Access Point (ej. UniFi que pide gestión sin etiqueta y SSIDs con etiqueta) o un Teléfono IP + PC | Si entra una trama desnuda, le asigna el **`PVID / Native VLAN`** (ej. `99`). Si entra con etiqueta (`10, 20`), respeta la etiqueta que trae | Saca **una sola VLAN** como **`Untagged`** (la que coincide con su `PVID / Native VLAN`, ej. `99`) y saca las demás (`10, 20`) como **`Tagged`** |

> **💡 Regla física inquebrantable:** Por un mismo puerto físico pueden salir **100 VLANs como `Tagged`**, pero **SOLO PUEDE SALIR UNA ÚNICA VLAN COMO `Untagged`** (y su PVID debe coincidir con ella). ¿Por qué? Porque si sacaras las VLANs 10 y 20 sin etiqueta por el mismo cable, cuando lleguen al switch vecino desnudas, ¡el vecino no tendría forma de adivinar cuál era de la 10 y cuál era de la 20!

---

## 🔄 Diccionario Multi-Vendor (La tabla que te salva la vida)

Así se traduce exactamente la misma configuración entre las 4 familias de equipos:

| Qué querés hacer | Cisco IOS / Catalyst | MikroTik RouterOS v7 (`Bridge VLAN Filtering`) | Aruba / Ubiquiti / TP-Link | Linux (`iproute2` / `bridge`) |
|------------------|----------------------|------------------------------------------------|----------------------------|-------------------------------|
| **Puerto para una PC en la VLAN 10** | `switchport mode access` + `switchport access vlan 10` | En `bridge port`: `pvid=10 frame-types=admit-only-untagged-and-priority-tagged` | **Untagged** en VLAN `10` + **`PVID = 10`** (o *Port Profile: VLAN 10*) | `bridge vlan add dev eth1 vid 10 pvid untagged` |
| **Puerto Trunk puro (VLANs 10, 20 y 30 etiquetadas)** | `switchport mode trunk` + `switchport trunk allowed vlan 10,20,30` | En `bridge vlan`: `vlan-ids=10,20,30 tagged=ether1` (y en `port`: `frame-types=admit-only-vlan-tagged`) | **Tagged** en VLANs `10, 20, 30` (sin Untagged) | `bridge vlan add dev eth0 vid 10` (repetir `20, 30`) |
| **Puerto Híbrido (Gestión en VLAN 99 sin etiqueta + WiFi en 10 y 20 con etiqueta)** | `switchport mode trunk` + `switchport trunk native vlan 99` + `allowed vlan 10,20,99` | En `bridge port`: `pvid=99` + En `bridge vlan`: `vlan-ids=10,20 tagged=ether5` | **Untagged** en `99` (`PVID=99`) + **Tagged** en `10, 20` | `bridge vlan add dev eth5 vid 99 pvid untagged` + `vid 10, 20` |
| **Crear una interfaz IP (Capa 3) del equipo dentro de la VLAN 99** | `interface Vlan99` + `ip address 10.0.99.2 255.255.255.0` | `/interface vlan add interface=bridge1 vlan-id=99` (+ agregar `bridge1` como **tagged** en la VLAN 99) | `vlan 99` → `ip address 10.0.99.2/24` | `ip link add link br0 name br0.99 type vlan id 99` |

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Coincidencia de Native VLAN / PVID en los dos extremos de un Trunk** | Ambos switches tienen el mismo `PVID / Native VLAN` (ej. `99` o trunk puro tagged) | Alerta `%CDP-4-NATIVE_VLAN_MISMATCH: Native VLAN mismatch discovered on Gi1/0/1 (1), with Switch2 (99)` | **Native VLAN Mismatch**: el Switch A saca la VLAN 1 sin etiqueta y el Switch B tiene `PVID=99`, por lo que todo el tráfico desnudo de la VLAN 1 se "filtra" adentro de la VLAN 99 |
| **Aprendizaje de MACs por VLAN en un Trunk** | En `show mac address-table vlan 20` se ven las MACs tanto de los puertos locales como del puerto Trunk hacia el router | Las PCs de la VLAN 20 se ven entre sí en el mismo switch, pero no ven la MAC del router gateway | Te olvidaste de agregar la VLAN 20 a la lista de VLANs permitidas (`allowed vlan` / `tagged`) en el puerto Trunk que sube al router |
| **Acceso a la IP de gestión del propio switch MikroTik al activar `vlan-filtering=yes`** | El switch responde por SSH/WinBox en la IP de su VLAN de gestión (`vlan99`) | Apenas ponés `vlan-filtering=yes`, **perdés conexión inmediata con el switch** | Te olvidaste de incluir al propio **`bridge1` (la CPU del switch)** dentro de la lista `tagged=bridge1,ether1` de la VLAN de gestión en `/interface bridge vlan` |
| **Puerto de acceso en switch TP-Link / Aruba / D-Link** | El puerto figura `Untagged` únicamente en la VLAN `10` y su `PVID` es `10` | Pusiste el puerto como `Untagged` en la VLAN `10`, pero te olvidaste de cambiar el menú de **`PVID`** (quedó en `PVID = 1`) | **Falla asimétrica clásica en switches web:** las tramas de la VLAN 10 salen hacia la PC, pero cuando la PC contesta, sus respuestas entran a la VLAN 1 y nunca vuelven |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Dejar toda la infraestructura de producción y la administración de switches en la `VLAN 1` por defecto:** La VLAN 1 viene activa en todos los puertos de fábrica, transporta protocolos de control (CDP, VTP, PAgP) y es el blanco de ataques de *VLAN Hopping*. En una red profesional, la administración va en su propia VLAN (ej. `VLAN 99 Management`), los usuarios en sus VLANs (`10, 20, 30`) y los puertos libres sin uso se apagan (`shutdown` / `disabled`) y se mandan a una VLAN "agujero negro" sin salida (ej. `VLAN 999 Parking`).
- **❌ Creer que porque creaste la interfaz `/interface vlan` o `interface Vlan20`, la VLAN ya existe en el chip de Capa 2 del switch:**
  - En **Cisco**, crear `interface Vlan20` (la interfaz Capa 3 SVI) **NO crea la VLAN 20 en la base de datos de Capa 2**; la interfaz queda `line protocol is down` hasta que entrás a configuración global y ejecutás `vlan 20`.
  - En **MikroTik**, `/interface vlan` es la pata de Capa 3 (CPU), mientras que `/interface bridge vlan` es la tabla del switch de Capa 2. Necesitás ambas si el equipo va a enrutar o tener IP en esa VLAN.
- **❌ Conectar dos puertos Access de distintas VLANs entre dos switches con un patchcord:** Si conectás el puerto 5 del Switch A (`Access VLAN 10`) con el puerto 5 del Switch B (`Access VLAN 20`), como por los puertos Access las tramas salen **desnudas (sin etiqueta)**, estás puenteando y mezclando la VLAN 10 con la VLAN 20 sin que ningún switch se dé cuenta (y además podés causar un loop de Spanning Tree).

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

Una empresa compra 4 puntos de acceso **Ubiquiti UniFi** y los conecta a un switch **Cisco Catalyst** (puertos `Gi1/0/11` al `14`), el cual sube por el puerto `Gi1/0/1` a un router **MikroTik**. El controlador UniFi está en la `VLAN 10` (`10.0.10.5`). Quieren que los APs emitan dos redes WiFi: `"Empresa-Staff"` (en la `VLAN 20`) y `"Empresa-Invitados"` (en la `VLAN 200`).

### Análisis paso a paso por capas

1. **Cómo trabaja el Access Point UniFi (Por qué necesita un puerto Híbrido o Trunk):**
   - Por defecto, un AP UniFi recién sacado de la caja pide su propia IP de administración y busca al controlador enviando tramas **sin etiquetar (`Untagged`)**, mientras que al tráfico de los clientes WiFi de cada SSID sí le estampa la etiqueta **`Tagged 802.1Q`** correspondiente (`VID 20` para Staff y `VID 200` para Invitados).
2. **Diseño de los puertos en el Switch Cisco (`Gi1/0/11-14` hacia los APs):**
   - Necesitamos que en esos puertos la trama desnuda del AP caiga en la `VLAN 10` (donde vive el controlador UniFi) y que por el mismo cable pasen etiquetadas las VLANs `20` y `200`:
   - En terminología Cisco: **Puerto Trunk con `native vlan 10` y `allowed vlan 10,20,200`**.
   - En terminología MikroTik / Aruba: **`PVID = 10` (`Untagged` en VLAN 10) + `Tagged` en VLANs `20` y `200`**.
3. **Diseño del enlace ascendente Switch Cisco (`Gi1/0/1`) ↔ Router MikroTik (`ether2`):**
   - Entre el switch y el router viajan todas las VLANs (`10, 20, 200`). Para evitar cualquier riesgo de *Native VLAN Mismatch*, configuramos el enlace como **Trunk etiquetado para las tres VLANs** (`10, 20 y 200 Tagged` en ambos lados) y creamos las subinterfaces VLAN `10`, `20` y `200` en el MikroTik con sus respectivos servidores DHCP y reglas de firewall.
4. **Resultado:**
   - Los 4 APs levantan IP en `10.0.10.x`, son adoptados por el controlador inmediatamente, los empleados en `"Empresa-Staff"` reciben IP `10.0.20.x` y los visitantes en `"Empresa-Invitados"` reciben IP `10.0.200.x` aislados de la red interna.

---

## 🧠 Modelo mental

Pensá en esto como **un centro logístico de correo (el Switch) que maneja paquetes de tres empresas distintas (`VLAN 10 Roja`, `VLAN 20 Azul` y `VLAN 30 Verde`) bajo el mismo techo sin que jamás se mezclen**:

- **Las PCs comunes** son clientes daltónicos en la ventanilla de atención al público (**Puerto Access**): entregan su caja de cartón marrón sin ningún sticker (**Untagged**). Apenas el empleado de la ventanilla 2 recibe la caja, mira el cartel de su mostrador (**`PVID = 10`**) y le pega en la frente el **sticker `VLAN 10 Roja`** para que circule adentro del galpón.
- **Cuando la caja tiene que viajar en camión a otra sucursal del correo (Puerto Trunk entre switches)**, la suben al camión **con el sticker rojo pegado (`Tagged 802.1Q`)**, porque en ese mismo camión también viajan cajas con sticker azul (`VLAN 20`) y verde (`VLAN 30`).
- **Cuando la caja llega al mostrador de entrega donde espera otra PC daltónica (Egress en Puerto Access de la VLAN 10)**, el empleado verifica que sea roja, **le arranca el sticker (`Untagged`)** y se la entrega en mano a la PC como una caja marrón normal.

Si entendés quién pega el sticker al entrar (**`PVID`**), quién lo conserva en el camión (**`Tagged / Trunk`**) y quién lo despega al entregarlo (**`Untagged / Access`**), podés configurar VLANs en cualquier marca del mundo con los ojos cerrados.

---

## 🧪 Autoevaluación rápida (Active Recall)

Respondé mentalmente antes de desplegar cada respuesta; si dudás, volvé a la sección correspondiente del documento.

**1. Por un mismo puerto físico pueden salir 100 VLANs etiquetadas, pero ¿por qué SOLO puede salir una única VLAN como `Untagged`, y qué debe cumplir su `PVID`?**

<details>
<summary>👀 Ver respuesta explicada</summary>

Porque si salieran dos VLANs sin etiqueta por el mismo cable, el switch vecino no tendría forma de saber cuál trama era de la VLAN 10 y cuál de la 20 al recibirlas desnudas. La única VLAN `Untagged` de un puerto debe coincidir con su `PVID` (en Cisco, su `native vlan`); las demás siempre viajan `Tagged` conservando sus 4 bytes de 802.1Q.

</details>

**2. En el caso de los 4 APs UniFi conectados a un switch Cisco, ¿por qué el puerto hacia cada AP debe ser híbrido (trunk con `native vlan 10`) y no un trunk puro?**

<details>
<summary>👀 Ver respuesta explicada</summary>

Porque un AP UniFi recién instalado pide su IP de administración y busca al controlador enviando tramas **Untagged**, mientras que al tráfico de cada SSID le estampa su etiqueta (`VID 20` Staff, `VID 200` Invitados). Por eso se configura `PVID = 10` con `Untagged` en la VLAN 10 (donde vive el controlador) y `Tagged` en las VLANs 20 y 200 por el mismo cable.

</details>

**3. En MikroTik, ¿por qué apenas activás `vlan-filtering=yes` podés perder la conexión con el propio equipo, y qué olvido en `/interface bridge vlan` lo causa?**

<details>
<summary>👀 Ver respuesta explicada</summary>

Porque el propio switch MikroTik (representado por `bridge1`, la CPU) necesita estar incluido como `tagged` en la VLAN de gestión dentro de `/interface bridge vlan`. Si te olvidás de agregar `bridge1` a la lista (`tagged=bridge1,ether1`), al activar el filtrado las tramas hacia la CPU de gestión se descartan y perdés SSH/WinBox de inmediato. Ayuda el mismo patrón en Cisco: crear `interface Vlan20` no crea la VLAN 20 en la base de Capa 2 hasta ejecutar `vlan 20`.

</details>

---

## 🔗 Ver también

- [`ethernet-mac-and-arp`](ethernet-mac-and-arp.md) — Cómo funciona la tabla MAC del switch dentro de cada VLAN por separado
- [`spanning-tree-and-loop-prevention`](spanning-tree-and-loop-prevention.md) — Cómo proteger tus VLANs contra bucles de Capa 2
- [`routing-fundamentals-static-and-dynamic`](routing-fundamentals-static-and-dynamic.md) — Cómo hacer que dos VLANs distintas se comuniquen pasando por Capa 3 (Inter-VLAN Routing)
