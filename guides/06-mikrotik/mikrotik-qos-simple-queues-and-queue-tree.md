⬅️ [Volver a Guías](../README.md)

# MikroTik QoS y Control de Ancho de Banda: Simple Queues, PCQ y Queue Tree — Guía práctica

**Dominio:** `06-mikrotik`
**Nivel:** 🔴 Avanzado
**Estándares:** `HTB (Hierarchical Token Bucket)`, `PCQ (Per Connection Queue)`, `FQ-CoDel / Cake (RouterOS v7)`, `DSCP (RFC 2474)`
**Concepto base:** [`tcp-udp-mtu-and-nat-conntrack`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Ver consumo en tiempo real de las colas, tipos de cola (PCQ/Cake/FQ-CoDel) y marcas Mangle
/queue simple print stats
/queue tree print stats
/queue type print
/ip firewall mangle print stats
```

---

## 📑 Índice

1. [¿Qué resuelve y cuándo usarlo?](#1--qué-resuelve-y-cuándo-usarlo)
2. [Topología de referencia](#2-️-topología-de-referencia)
3. [Configuración paso a paso por fabricante](#3-️-configuración-paso-a-paso-por-fabricante)
4. [Salida clave e interpretación de flags](#4--salida-clave-e-interpretación-de-flags)
5. [Uso en troubleshooting](#5--uso-en-troubleshooting)
6. [Mantenimiento, backup y rollback seguro](#6-️-mantenimiento-backup-y-rollback-seguro)
7. [Errores comunes en producción](#7-️-errores-comunes-en-producción)
8. [Buenas prácticas profesionales](#8--buenas-prácticas-profesionales)
9. [Referencias internas](#9--referencias-internas)

---

## 1. 🧠 ¿Qué resuelve y cuándo usarlo?

En cualquier oficina o colegio ocurre el mismo fenómeno: tenés un enlace a Internet de `300 Mbps`, pero cuando un solo empleado pone a descargar una actualización de Windows, un ISO o sube un backup pesado a Google Drive, **llena el buffer del módem del proveedor (*Bufferbloat*), la latencia del ping salta de `10 ms` a `600 ms` y a todos los demás empleados se les entrecortan las videollamadas de Zoom/Teams y el teléfono IP**.

El motor de **Calidad de Servicio (QoS) de MikroTik RouterOS v7** resuelve esto con tres herramientas extraordinarias:

1. **Colas Igualitarias `PCQ` (*Per Connection Queue*) o `FQ-CoDel / Cake`:** Reparten automáticamente el ancho de banda en partes iguales entre todos los usuarios activos sin que tengas que crear 200 colas individuales a mano.
2. **Garantía (`limit-at` / CIR) vs Tope Máximo (`max-limit` / MIR) con Prioridades (`1` a `8`):** Asegura que la telefonía VoIP o los servidores tengan ancho de banda garantizado siempre, mientras que la red de Invitados solo use lo que sobre.
3. **La regla de oro de *FastTrack Bypass*:** Cómo hacer que las colas funcionen sin apagar el FastTrack para el resto del tráfico interno.

> **🧠 Recordatorio del modelo mental:** Pensá en un enlace a Internet sin QoS como **un buffet libre sin platos donde el primero que llega con una pala mecánica se lleva toda la comida**. Una cola **PCQ con árbol jerárquico (HTB)** es el maître del restaurante:
>
> - Primero reserva el **`5%` de margen libre** (`max-limit = 95%` del ISP) para que nunca se forme cola en la puerta de la calle (*Bufferbloat*).
> - Le sirve primero y sin espera a la mesa de emergencia (**Prioridad 1: VoIP / DNS / ICMP**).
> - Y al resto de los comensales (**PCQ**), si hay 1 sola persona comiendo le deja repetir todo lo que quiera, pero si entran 50 personas al mismo tiempo, **divide la fuente en 50 porciones exactamente iguales en tiempo real**.

---

## 2. 🗺️ Topología de referencia

En una empresa con un enlace simétrico de **`200 Mbps` reales**, vamos a controlar el tráfico de las VLANs garantizando caudales, repartiendo equitativamente entre usuarios con **PCQ** y eliminando la latencia (*Bufferbloat*) con **`fq-codel`**:

```text
                [ISP Fibra: 200 Mbps Subida / 200 Mbps Bajada]
                                     |
           +---------------------------------------------------+
           |  COLA PADRE GLOBAL: max-limit = 190M / 190M (95%) |
           |  (Tomamos el control del cuello de botella!)      |
           +---------------------------------------------------+
                  /                  |                   \
                 v                   v                    v
  +--------------------+  +-----------------------+  +-----------------------+
  | 1. Hija: VoIP/Crít |  | 2. Hija: Staff VLAN10 |  | 3. Hija: Guest VLAN200|
  | Prioridad: 1 (Máx) |  | Prioridad: 4          |  | Prioridad: 8 (Mínima) |
  | Garantizado: 20M   |  | Garantizado: 140M     |  | Garantizado: 10M      |
  | Máximo:      50M   |  | Máximo:      190M     |  | Máximo:      40M      |
  | Cola: fq-codel     |  | Cola: PCQ (Reparto =) |  | Cola: PCQ (Max 5M c/u)|
  +--------------------+  +-----------------------+  +-----------------------+
```

| Parámetro en MikroTik Queues | Nombre Técnico en Telecom | Qué hace realmente |
|------------------------------|---------------------------|--------------------|
| **`limit-at` (`Upload / Download`)** | **CIR (*Committed Information Rate*)** | **Caudal MÍNIMO GARANTIZADO:** este ancho de banda está asegurado para esta cola aunque toda la empresa esté al 100% *(la suma de los `limit-at` de los hijos nunca debe superar el `max-limit` del padre!)* |
| **`max-limit` (`Upload / Download`)** | **MIR (*Maximum Information Rate*)** | **Tope MÁXIMO prestado:** si sobra ancho de banda libre en el padre, esta cola puede crecer hasta este techo |
| **`priority` (`1` a `8`)** | Prioridad HTB | Quién recibe primero el ancho de banda sobrante por encima del `limit-at`: **`1` es la prioridad MÁS ALTA** y **`8` es la MÁS BAJA** *(¡solo actúa en colas hijas que tienen una cola `parent`!)* |

---

## 3. 🛠️ Configuración paso a paso en MikroTik RouterOS v7

### A. Paso 1 Crítico: Excluir de `FastTrack` el tráfico que quieras controlar con Simple Queues

> **🚨 La trampa número 1 en MikroTik:** Por diseño, los paquetes que entran en la regla `action=fasttrack-connection` del firewall **saltean por completo el motor de *Simple Queues* y *Queue Tree (global)***.
> Si querés limitar a la `VLAN 200 (Invitados)` con una Simple Queue sin perder FastTrack en tus servidores rápidos, simplemente excluís a `10.1.200.0/23` de la regla de FastTrack (o si vas a aplicar QoS global a todo el enlace WAN de `200 Mbps` en un `RB5009 / CCR`, desactivás la regla de FastTrack WAN porque la CPU maneja `200 Mbps` con `< 5%` de carga).

```text
# Opción A: Si solo querés aplicar Simple Queue a la red de Invitados (10.1.200.0/23),
#           modificá o agregá una regla ANTES del FastTrack para que Invitados no entre en FastTrack:
/ip firewall filter
add chain=forward src-address=10.1.200.0/23 connection-state=established,related action=accept place-before=[find action=fasttrack-connection] comment="Bypass FastTrack para QoS Invitados"
add chain=forward dst-address=10.1.200.0/23 connection-state=established,related action=accept place-before=[find action=fasttrack-connection] comment="Bypass FastTrack para QoS Invitados"

# Opción B: Si vas a controlar el 100% del enlace WAN con la jerarquía de colas completa,
#           deshabilitá la regla de fasttrack-connection:
/ip firewall filter disable [find action=fasttrack-connection]
```

---

### B. Configurar Tipos de Cola Modernos (`fq-codel` anti-latencia y `PCQ` igualitario)

RouterOS v7 incorporó **`fq-codel`** y **`cake`**, los algoritmos modernos que eliminan el *Bufferbloat* manteniendo el ping en `< 5 ms` incluso cuando el enlace está saturado al 100%:

```text
# 1. Crear una cola FQ-CoDel para baja latencia en llamadas y tráfico interactivo
/queue type
add name=fq-codel-wan kind=fq-codel fq-codel-limit=1024 fq-codel-quantum=300

# 2. Configurar colas PCQ que dividen automáticamente el ancho de banda en partes iguales por cada IP interna
#    - pcq-rate=0 significa: "Dividí el total disponible exactamente entre la cantidad de IPs activas ahora mismo"
#    - Si ponés pcq-rate=5M (ej. para invitados), además de repartir, ninguna IP individual superará 5 Mbps!
/queue type
add name=pcq-down-staff kind=pcq pcq-classifier=dst-address pcq-rate=0
add name=pcq-up-staff   kind=pcq pcq-classifier=src-address pcq-rate=0
add name=pcq-down-guest kind=pcq pcq-classifier=dst-address pcq-rate=5M
add name=pcq-up-guest   kind=pcq pcq-classifier=src-address pcq-rate=5M
```

---

### C. Crear el Árbol Jerárquico en `Simple Queues` (Padre + 3 Hijos con Prioridad y PCQ)

> **💡 Por qué el Padre se configura al `90–95%` de la velocidad real del ISP (`190M` sobre `200M`):** Si tu proveedor te da `200 Mbps` y vos ponés `max-limit=200M` (o no ponés padre), cuando el tráfico llega a `200M` la cola se arma en el **módem del proveedor** (que tiene un buffer bobo FIFO gigante sin prioridades). Al poner el freno en **`190M`** en tu MikroTik, el cuello de botella pasa a estar en **tu router**, donde vos decidís quién pasa primero.

```text
# 1. (Importante) Para que las Simple Queues solo limiten la salida a Internet y NO frenen
#    las copias a 1 Gbps entre la VLAN 10 y tus Servidores de la VLAN 40, creamos primero una
#    regla #0 sin límite para el tráfico puramente interno (RFC 1918 -> RFC 1918):
/queue simple
add name="0-TRAFICO-INTERNO-LAN-A-LAN-SIN-LIMITE" \
    target=10.0.0.0/8 \
    dst=10.0.0.0/8 \
    max-limit=10G/10G \
    comment="El trafico interno entre VLANs no pasa por el limite WAN"

# 2. COLA PADRE GLOBAL HACIA INTERNET (95% de los 200 Mbps reales = 190M/190M)
add name="1-PADRE-TOTAL-WAN" \
    target=10.1.0.0/16 \
    max-limit=190M/190M \
    queue=fq-codel-wan/fq-codel-wan \
    comment="Techo total WAN (95% de 200M para eliminar Bufferbloat)"

# 3. HIJA 1: Telefonía VoIP (VLAN 30) — Prioridad 1 (Máxima), 20M garantizados, hasta 50M
add name="1.1-VOIP-PRIORIDAD-MAXIMA" \
    parent="1-PADRE-TOTAL-WAN" \
    target=10.1.30.0/24 \
    priority=1/1 \
    limit-at=20M/20M \
    max-limit=50M/50M \
    queue=fq-codel-wan/fq-codel-wan

# 4. HIJA 2: Staff y Servidores (VLAN 10 y 40) — Prioridad 4, 140M garantizados, hasta 190M con reparto PCQ
add name="1.2-STAFF-CORPORATIVO-PCQ" \
    parent="1-PADRE-TOTAL-WAN" \
    target=10.1.10.0/24,10.1.40.0/24 \
    priority=4/4 \
    limit-at=140M/140M \
    max-limit=190M/190M \
    queue=pcq-up-staff/pcq-down-staff

# 5. HIJA 3: WiFi Invitados (VLAN 200) — Prioridad 8 (Mínima), 10M garantizados, tope 40M (máx 5M por celular)
add name="1.3-WIFI-INVITADOS-PCQ" \
    parent="1-PADRE-TOTAL-WAN" \
    target=10.1.200.0/23 \
    priority=8/8 \
    limit-at=10M/10M \
    max-limit=40M/40M \
    queue=pcq-up-guest/pcq-down-guest
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/queue simple print stats`)

```text
[netops@RTR-BORDE] > /queue simple print stats
Flags: X - disabled, I - invalid; D - dynamic
Columns: NAME, TARGET, UPLOAD-AVG-RATE, DOWNLOAD-AVG-RATE, DROPPED
# NAME                                    TARGET          UPLOAD-AVG-RATE  DOWNLOAD-AVG-RATE  DROPPED
0 0-TRAFICO-INTERNO-LAN-A-LAN-SIN-LIMITE  10.0.0.0/8      45.2Mbps         612.4Mbps          0/0
1 1-PADRE-TOTAL-WAN                       10.1.0.0/16     18.4Mbps         188.9Mbps          0/1420
2 1.1-VOIP-PRIORIDAD-MAXIMA               10.1.30.0/24    1.8Mbps          1.8Mbps            0/0
3 1.2-STAFF-CORPORATIVO-PCQ               10.1.10.0/24    15.1Mbps         177.1Mbps          0/890
4 1.3-WIFI-INVITADOS-PCQ                  10.1.200.0/23   1.5Mbps          10.0Mbps           0/530
```

### Tabla de interpretación de colores, columnas y estados

| Indicador / Color en WinBox | Qué significa realmente | Diagnóstico inmediato |
|-----------------------------|-------------------------|-----------------------|
| **Icono Verde (`0–50%` del límite)** | La cola está holgada y por debajo de su caudal garantizado (`limit-at`) | Tráfico fluido normal |
| **Icono Amarillo (`50–75%`) / Rojo (`75–100%`)** | La cola llegó a su techo (`max-limit`) y **está reteniendo/descartando paquetes (`DROPPED`) para proteger al resto de la red** | ✅ **Un icono rojo en la cola de Invitados NO es un error:** significa que los invitados intentaron pedir más de `40M` (o el Staff está usando los `177M`) y la cola les aplicó el freno correctamente |
| **`DROPPED: 0/0` en la fila `1.1-VOIP`** | Cero paquetes descartados en la cola de Prioridad 1 aunque el Padre esté al `100%` (`188.9M / 190M`) | ✅ Confirma que la priorización HTB funciona: cuando el enlace se llena, el router frena a Invitados (Prioridad 8) y Staff (Prioridad 4) sin tocar un solo paquete de VoIP (Prioridad 1) |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Creaste las Simple Queues, los usuarios están descargando a `180 Mbps`, pero todas las colas marcan **`0 bps`**

1. **Causa raíz (99,9% de los casos):** Tenés activa la regla **`action=fasttrack-connection`** en `/ip firewall filter` para ese tráfico.
2. **Corrección:** Desactivar o agregar la excepción en la regla de FastTrack como se mostró en el Paso 1A, y limpiar las conexiones existentes (o esperar a que abran una conexión nueva) para que empiecen a pasar por las colas.

### Síntoma 2: Pusiste una Simple Queue para limitar a la VLAN 10 a `100 Mbps` de Internet, y ahora los usuarios de la VLAN 10 también copian archivos súper lento hacia el Servidor NAS local de la VLAN 40

1. **Causa raíz:** Las Simple Queues evalúan el campo `target=10.1.10.0/24` sin distinguir si el paquete va hacia Internet o hacia otra VLAN interna, a menos que pongas arriba la regla #0 de bypass LAN-a-LAN.
2. **Corrección:** Asegurate de tener en el **puesto #0 (arriba de todo en `/queue simple`)** la regla `target=10.0.0.0/8 dst=10.0.0.0/8 max-limit=10G/10G` (las Simple Queues se leen en orden secuencial de arriba hacia abajo igual que el firewall).

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **¿Cómo apagar todo el QoS en 1 segundo para probar si un problema de velocidad es culpa del proveedor o de tus colas?**
  - Simplemente deshabilitás la cola Padre y sus hijas: `/queue simple disable [find]` y hacés un test de velocidad directo. Luego las reactivás con `/queue simple enable [find]`.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Configurar `priority=1` en una Simple Queue suelta que NO tiene una cola `parent`:** En el algoritmo HTB de MikroTik, **el parámetro `priority` (`1` a `8`) NO HACE ABSOLUTAMENTE NADA si la cola no es hija de una cola `parent` que tenga definido el `max-limit` total del enlace**. ¿Por qué? Porque si el router no sabe cuántos megas totales tiene el caño de Internet (en la cola padre), no tiene forma de saber cuándo se llenó el caño para empezar a priorizar a la cola 1 sobre la cola 8.
- **❌ Invertir los clasificadores `src-address` y `dst-address` en PCQ:**
  - En la **Subida (`Upload`)**, quien envía es la PC interna → el clasificador PCQ debe ser **`src-address`**.
  - En la **Bajada (`Download`)**, quien recibe es la PC interna → el clasificador PCQ debe ser **`dst-address`**.
  - Si los ponés al revés (`src-address` en la bajada), el router agrupará por la IP del servidor de Internet (Google/Netflix) en lugar de dividir en partes iguales entre tus PCs internas.
- **❌ Hacer que la suma de los `limit-at` (garantizados) de las colas hijas supere el `max-limit` de la cola padre:** En nuestro ejemplo, `20M (VoIP) + 140M (Staff) + 10M (Guest) = 170M`, que es menor que los `190M` de la cola padre. Si garantizás más megas de los que realmente existen en el enlace físico, rompés la matemática de garantías de HTB.

---

## 8. ✅ Buenas prácticas profesionales

- **Usar `fq-codel` o `cake` en RouterOS v7 en lugar de las colas `default-small` (`pfifo` de 10 paquetes) antiguas:** Las colas FIFO chicas antiguas de RouterOS v6 cortaban abruptamente las ráfagas TCP. `fq-codel` y `cake` en RouterOS v7 gestionan la latencia por flujo de forma inteligente y mantienen las videollamadas impecables.
- **Re-medir la velocidad real del ISP trimestralmente:** Si el proveedor sufre degradación y pasa de entregarte `200 Mbps` a entregarte `120 Mbps`, tu cola padre de `190M` dejará de actuar. Ajustá siempre el `max-limit` de la cola padre al `90–95%` del caudal real medido.

---

## 9. 🔗 Referencias internas

- [`routeros-v7-first-setup-and-hardening`](routeros-v7-first-setup-and-hardening.md) — Configuración base de firewall y FastTrack donde se integra este árbol de colas
- [`snmp-syslog-and-netflow-monitoring`](../08-operations/snmp-syslog-and-netflow-monitoring.md) — Cómo usar `/tool torch` y NetFlow para identificar qué tráfico priorizar o limitar
- [`tcp-udp-mtu-and-nat-conntrack`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md) — Cómo reacciona la ventana de congestión de TCP cuando una cola QoS aplica control de caudal
