⬅️ [Volver a Guías](../README.md)

# Captura de Paquetes en Vivo (`tcpdump`, `/tool sniffer` y Cisco EPC) — Guía práctica multi-vendor

**Dominio:** `01-fundamentals`
**Nivel:** 🔴 Avanzado
**Estándares:** `BPF (Berkeley Packet Filter)`, `TZSP (TaZmen Sniffer Protocol - UDP 37008)`, `PCAP`
**Concepto base:** [`osi-and-tcp-ip-models`](../../concepts/osi-and-tcp-ip-models.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Ver en vivo qué paquetes entran/salen de una interfaz o hacia una IP
/tool sniffer quick interface=ether1 ip-address=8.8.8.8
/tool sniffer quick ip-protocol=icmp

# Linux: Capturar paquetes mostrando cabeceras Ethernet + Etiquetas VLAN 802.1Q (-e) sin demorar en DNS (-n)
sudo tcpdump -ni eth0 -e 'icmp or arp'
sudo tcpdump -ni eth0 -e 'vlan 10 and port 443'

# Cisco IOS / IOS-XE: Ver capturas activas del Embedded Packet Capture (EPC)
show monitor capture
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

En ingeniería de redes hay un axioma supremo: **"Los usuarios mienten involuntariamente, las aplicaciones dan errores genéricos, los firewalls ocultan detalles, pero los paquetes en el cable NUNCA mienten (`Packets never lie`)"**.

Cuando dos equipos no se comunican y ambos administradores juran que su configuración está bien (*"yo te estoy mandando el tráfico por el túnel"*, *"a mí no me llega nada"*), abrir una **captura de paquetes en vivo** termina la discusión en 15 segundos:

- Si ves salir el paquete `SYN` (`direction=tx`) por la boca de tu router y **jamás entra un paquete de respuesta (`direction=rx`)**, tenés prueba irrefutable de que el problema está del otro lado o en el camino.
- Si usás `-e` en `tcpdump` o mirás la columna `VLAN` en el sniffer de MikroTik, ves con tus propios ojos **qué número de etiqueta VLAN (`802.1Q`)** trae pegada la trama al entrar o salir del cable.

> **🧠 Recordatorio del modelo mental:** Pensá en la captura de paquetes como **una cámara de alta velocidad con rayos X instalada en la cinta transportadora del correo**: te permite ver la caja mientras pasa a toda velocidad, leer qué etiqueta de camión (`MAC` y `VLAN`) tiene pegada afuera y qué dirección postal (`IP` y `Puerto`) lleva escrita adentro, antes y después de pasar por el aduanero (`NAT / Firewall`).

---

## 2. 🗺️ Topología de referencia

En todos los ejemplos diagnosticaremos el flujo de un paquete entre la PC (`10.1.10.50`) y un servidor remoto (`10.2.40.10`), además de enviar copias en tiempo real hacia **Wireshark** en la laptop del ingeniero (`10.1.20.50`):

```text
[PC: 10.1.10.50] ---> (ether2 / VLAN 10) [RTR-BORDE] (ether1-wan / wg0) ---> [Servidor: 10.2.40.10]
                                              |
                                              | Stream TZSP (UDP 37008) o Descarga .pcap
                                              v
                                   [Laptop Ingeniero: 10.1.20.50]
                                   (Wireshark abierto en vivo!)
```

| Herramienta | Dónde corre | Ventaja principal | Limitación a tener en cuenta |
|-------------|-------------|-------------------|------------------------------|
| **`/tool sniffer` (MikroTik)** | En cualquier Router/Switch RouterOS | Filtra en consola instantáneamente (`quick`), guarda `.pcap` o **transmite en vivo por red (`TZSP`) directo a tu Wireshark** | Si un switch tiene **Hardware Offload (`H`)** activo, el tráfico entre dos puertos L2 del mismo chip no sube a la CPU (usar *Port Mirroring* o apagar `hw-offload` temporalmente en ese puerto) |
| **`tcpdump` (Linux)** | Servidores, Routers Linux, Firewalls, Proxmox | El estándar más potente de filtros BPF (`vlan`, `arp`, `tcp[tcpflags]`) | Siempre usar **`-n`** (no resolver DNS) y **`-e`** (ver MACs y etiquetas VLAN) |
| **`monitor capture` / EPC (Cisco)** | Routers ISR/ASR y Switches Catalyst 9000/3850 | Captura en hardware en enlaces Cisco y exporta `.pcap` | Siempre definir un filtro ACL o `match` antes de iniciar para no llenar el buffer de memoria |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. MikroTik RouterOS v7 (`/tool sniffer` en consola, a archivo `.pcap` y streaming a Wireshark)

```text
# 1. MODO RÁPIDO EN CONSOLA (Ideal para el 90% de los diagnósticos en vivo):
#    Ver todo el tráfico ICMP (ping) que pasa hacia o desde 10.2.40.10 en cualquier interfaz:
/tool sniffer quick ip-address=10.2.40.10 ip-protocol=icmp

#    Ver si están llegando pedidos al puerto TCP 443 por la interfaz WAN:
/tool sniffer quick interface=ether1-wan ip-protocol=tcp port=443

#    Ver si están entrando tramas DHCP (puertos UDP 67 y 68) en la VLAN 10:
/tool sniffer quick interface=vlan10 ip-protocol=udp port=67,68

# 2. GUARDAR UN ARCHIVO .PCAP PARA ABRIRLO EN WIRESHARK:
/tool sniffer set \
    filter-interface=ether2 \
    filter-ip-address=10.1.10.50/32 \
    file-name=diagnostico-pc50.pcap \
    file-limit=10000KiB \
    memory-limit=2048KiB
/tool sniffer start
# ... reproducir la falla durante 15 segundos y detener la captura:
/tool sniffer stop
# (Luego descargás 'diagnostico-pc50.pcap' por SCP o desde el menú Files de WinBox)

# 3. MODO PRO: STREAMING EN TIEMPO REAL DIRECTO A TU WIRESHARK (Protocolo TZSP UDP 37008):
#    En tu laptop (10.1.20.50), abrí Wireshark, capturá en tu placa de red con el filtro 'udp.port == 37008'
#    y ejecutá esto en el MikroTik:
/tool sniffer set \
    filter-interface=ether1-wan \
    filter-ip-address=10.2.40.10/32 \
    streaming-enabled=yes \
    streaming-server=10.1.20.50:37008
/tool sniffer start
# ¡Wireshark decodifica automáticamente los paquetes del router remoto en tiempo real!
# Al terminar, SIEMPRE apagar el streaming:
/tool sniffer stop
/tool sniffer set streaming-enabled=no file-name=""
```

### B. Linux (`tcpdump` — Los comandos de campo imprescindibles para NetOps)

```bash
# 1. Regla de oro de flags en tcpdump:
#    -n : NO intentar resolver IPs a nombres DNS (evita que tcpdump se trabe si el DNS está caído)
#    -i : Interfaz a escuchar (o '-i any' para ver por qué interfaz entra y por cuál sale)
#    -e : Mostrar cabecera Capa 2 (MAC Origen -> MAC Destino, EtherType y etiqueta VLAN 802.1Q!)
#    -vv: Más detalle de protocolo (TTL, ID, opciones DHCP/DNS)

# 2. Ver si el tráfico llega con o sin etiqueta VLAN 802.1Q por el puerto eth0:
sudo tcpdump -ni eth0 -e 'vlan'

# 3. Filtrar específicamente el tráfico de la VLAN 100 hacia una cámara IP:
sudo tcpdump -ni eth0 -e 'vlan 100 and host 10.1.100.50'

# 4. Diagnosticar ARP (¿quién pregunta y quién contesta en Capa 2?):
sudo tcpdump -ni eth0 -e 'arp'

# 5. Diagnosticar DHCP completo (ciclo DORA en vivo con opciones desglosadas):
sudo tcpdump -ni eth0 -lenvvv 'udp port 67 or udp port 68'

# 6. Ver solo inicios/cierres de conexiones TCP (SYN, SYN-ACK, FIN, RST) y el MSS anunciado:
sudo tcpdump -ni eth0 'tcp[tcpflags] & (tcp-syn|tcp-fin|tcp-rst) != 0'

# 7. Guardar captura rotativa en archivo .pcap (máximo 5 archivos de 20 MB cada uno para no llenar el disco):
sudo tcpdump -ni eth0 -C 20 -W 5 -w /tmp/captura-red.pcap 'host 10.2.40.10'
```

### C. Cisco IOS / IOS-XE (*Embedded Packet Capture — EPC*)

```cisco
! 1. Definir qué tráfico queremos capturar (NUNCA capturar sin filtro en producción!)
monitor capture CAP-DIAG interface GigabitEthernet1/0/1 both
monitor capture CAP-DIAG match ipv4 host 10.1.10.50 host 10.2.40.10
monitor capture CAP-DIAG buffer size 10

! 2. Iniciar la captura, reproducir el problema y detenerla
monitor capture CAP-DIAG start
! ... hacer la prueba de conexión ...
monitor capture CAP-DIAG stop

! 3. Ver el resumen de paquetes directamente en la consola del Cisco:
show monitor capture CAP-DIAG buffer brief
show monitor capture CAP-DIAG buffer detailed

! 4. Exportar a un archivo .pcap por SCP para abrirlo en Wireshark y limpiar la memoria:
monitor capture CAP-DIAG export scp://netops@10.1.20.50/captura-cisco.pcap
no monitor capture CAP-DIAG
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/tool sniffer quick ip-address=1.1.1.1 ip-protocol=icmp`)

```text
INTERFACE    TIME   NUM  DIR  SRC-MAC            DST-MAC            VLAN  SRC-ADDRESS          DST-ADDRESS          PROTOCOL  SIZE
vlan10       1.102    1  <-   AA:BB:CC:00:11:50  D4:CA:6D:01:02:03        10.1.10.50           1.1.1.1              ip:icmp     98
ether2       1.102    2  <-   AA:BB:CC:00:11:50  D4:CA:6D:01:02:03  10    10.1.10.50           1.1.1.1              ip:icmp    102
ether1-wan   1.102    3  ->   D4:CA:6D:01:02:01  00:11:22:33:44:55        190.210.50.10        1.1.1.1              ip:icmp     98
ether1-wan   1.108    4  <-   00:11:22:33:44:55  D4:CA:6D:01:02:01        1.1.1.1              190.210.50.10        ip:icmp     98
vlan10       1.108    5  ->   D4:CA:6D:01:02:03  AA:BB:CC:00:11:50        1.1.1.1              10.1.10.50           ip:icmp     98
ether2       1.108    6  ->   D4:CA:6D:01:02:03  AA:BB:CC:00:11:50  10    1.1.1.1              10.1.10.50           ip:icmp    102
```

### En Linux (`tcpdump -ni eth0 -e`)

```text
14:22:01.102400 aa:bb:cc:00:11:50 > d4:ca:6d:01:02:03, ethertype 802.1Q (0x8100), length 78: vlan 10, p 0, ethertype IPv4 (0x0800), 10.1.10.50.54111 > 10.2.40.10.443: Flags [S], seq 1001, win 64240, options [mss 1460], length 0
14:22:01.110850 d4:ca:6d:01:02:03 > aa:bb:cc:00:11:50, ethertype 802.1Q (0x8100), length 78: vlan 10, p 0, ethertype IPv4 (0x0800), 10.2.40.10.443 > 10.1.10.50.54111: Flags [R.], seq 0, ack 1002, win 0, length 0
```

### Tabla de interpretación de columnas y flags

| Columna / Flag | Herramienta | Qué significa realmente | Diagnóstico inmediato al verlo |
|----------------|-------------|-------------------------|-------------------------------|
| **`DIR: <-` vs `->`** | MikroTik Sniffer | `<-` (`rx`): el paquete **entró** al router por esa interfaz. `->` (`tx`): el paquete **salió** del router por esa interfaz | Si ves `<-` en `vlan10`, pero **nunca aparece `->` en `ether1-wan`**, el paquete murió adentro de TU router (tu propio firewall `forward` o tu tabla de rutas lo descartó) |
| **`SRC-ADDRESS` cambia en `ether1-wan`** | MikroTik Sniffer (filas 2 y 3) | En `vlan10` entró con origen `10.1.10.50` y por `ether1-wan` salió con origen `190.210.50.10` | ✅ Confirma visualmente que la regla de **Source NAT / Masquerade** se aplicó correctamente al salir a la WAN. *(Si saliera por la WAN todavía con `10.1.10.50`, te faltó el NAT!)* |
| **`VLAN: 10` y `SIZE: 102` vs `98`** | MikroTik Sniffer (filas 1 y 2) | En el cable físico `ether2` la trama mide `102 bytes` porque lleva puestos los **`4 bytes` de la etiqueta VLAN 10** | ✅ Confirma que el trunk `802.1Q` está etiquetando la VLAN 10 en el cable físico |
| **`Flags [S]`** | `tcpdump` | Paquete **`TCP SYN`** (intento de abrir conexión) con `options [mss 1460]` | Si ves repetirse varios `Flags [S]` (`1s, 3s, 7s`) sin ninguna respuesta, hay un `DROP` de firewall o falta la ruta de retorno |
| **`Flags [R.]` o `[R]`** | `tcpdump` | Paquete **`TCP RST` (*Reset*)** | **¡El paquete llegó hasta el destino y volvió!** Pero el servidor destino tiene el servicio apagado en ese puerto (`443`) o un firewall intermedio tiene una regla `action=reject` |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: "El túnel VPN está conectado, pero las PCs de la Sede A no llegan al servidor de la Sede B"

1. **Verificación rápida en el Router de la Sede A:** `/tool sniffer quick ip-address=10.2.40.10` mientras hacés ping desde una PC.
2. **Qué buscar en la salida:**
   - Mirá con qué **`SRC-ADDRESS`** sale el paquete por la interfaz del túnel (`wg0`).
   - Si en `wg0` el paquete sale con `SRC-ADDRESS: 190.210.50.10` (tu IP pública WAN) en lugar de `10.1.10.50`, **tu regla de `masquerade` de Internet está mal hecha** (no le pusiste `out-interface-list=WAN`) y está enmascarando el tráfico que entra al túnel VPN.

### Síntoma 2: En un Switch MikroTik CRS3xx corrés `/tool sniffer quick interface=ether5` pero no muestra el tráfico de la PC

1. **Causa raíz:** En un switch con **Hardware Offloading (`H`)** activo, las tramas que van del puerto `ether5` al puerto `ether1` se conmutan directamente adentro del chip ASIC sin pasar por la CPU del MikroTik (donde vive `/tool sniffer`).
2. **Corrección para diagnóstico:** O bien filtrás tráfico que toque a la CPU (como un ping al propio router o ARP broadcast), o usás **Port Mirroring** en el chip de switch, o durante 30 segundos desactivás `hw=no` en ese puerto de acceso puntual para que sus tramas suban a la CPU, capturás y volvés a poner `hw=yes`.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Limpieza obligatoria post-captura:**
  - En MikroTik: verificar siempre que el sniffer haya quedado detenido (`/tool sniffer print` → `running: no`), desactivar `streaming-enabled=no` y borrar el archivo `.pcap` de `/file` una vez descargado para no dejar el disco flash lleno.
  - En Cisco: eliminar el punto de captura de la memoria RAM con `no monitor capture CAP-DIAG`.
  - En Linux: borrar los archivos `/tmp/*.pcap` al terminar.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Correr `tcpdump -i eth0` sin el flag `-n` cuando precisamente hay un problema de DNS o de salida a Internet:** Por defecto, `tcpdump` intenta hacer una consulta DNS inversa (`PTR`) por cada IP que captura antes de imprimir la línea en pantalla. Si el DNS está caído, `tcpdump` parece congelado durante 15 segundos por paquete. **Escribí siempre `tcpdump -ni ...` como un solo reflejo muscular.**
- **❌ Capturar sin filtros en un enlace troncal de `1 Gbps` o `10 Gbps`:** Si ejecutás `/tool sniffer start` o `monitor capture` sin filtrar por IP o protocolo en un router que mueve `800 Mbps`, vas a disparar la CPU al 100% y llenar la memoria en 2 segundos. **Siempre acotá la captura con `ip-address=` o `port=`.**
- **❌ Filtrar en `tcpdump` por `host 10.1.10.50` sobre una interfaz física Trunk sin recordar que el tráfico viene con tag VLAN:** En `tcpdump` (filtros BPF), cuando una trama trae etiqueta `802.1Q` en una interfaz física trunk (`eth0`), el offset de la cabecera IP se corre 4 bytes. Si capturás en la interfaz padre `eth0`, tenés que anteponer la palabra `vlan` en el filtro: **`tcpdump -ni eth0 -e 'vlan and host 10.1.10.50'`** (o bien capturar directamente sobre la subinterfaz `tcpdump -ni eth0.10 'host 10.1.10.50'`).

---

## 8. ✅ Buenas prácticas profesionales

- **Aprender a leer la secuencia `<-` (entra) y `->` (sale) en el router:** Es la forma más rápida de saber si un problema es culpa de tu router (entró y no salió) o culpa del equipo siguiente (salió por el cable correcto con la IP y MAC correctas y jamás volvió respuesta).
- **Usar filtros `BPF` exactos para aislar un problema en medio de miles de usuarios:** Combinar siempre `host <IP> and (port <N> or icmp)` para capturar únicamente la aguja en el pajar.

---

## 9. 🔗 Referencias internas

- [`osi-and-tcp-ip-models`](../../concepts/osi-and-tcp-ip-models.md) — Anatomía byte a byte de cada cabecera que ves en `tcpdump` y Wireshark
- [`vlans-tagged-untagged-and-trunks`](../../concepts/vlans-tagged-untagged-and-trunks.md) — Cómo se ve el tag `0x8100` de 4 bytes en la captura
- [`tcp-udp-mtu-and-nat-conntrack`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md) — Cómo se ven el handshake `SYN / SYN-ACK / ACK`, el `MSS` y la traducción de IPs del NAT
