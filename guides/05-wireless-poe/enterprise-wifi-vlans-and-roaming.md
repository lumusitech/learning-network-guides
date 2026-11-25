⬅️ [Volver a Guías](../README.md)

# WiFi Corporativo: Múltiples SSIDs por VLAN, Planificación de Canales y Roaming (802.11k/v/r) — Guía práctica

**Dominio:** `05-wireless-poe`
**Nivel:** 🟡 Intermedio
**Estándares:** `IEEE 802.11ax/be (WiFi 6/6E/7)`, `IEEE 802.1Q`, `IEEE 802.11k/v/r (Fast Roaming)`, `WPA2/WPA3-Enterprise (802.1X)`
**Concepto base:** [`vlans-tagged-untagged-and-trunks`](../../concepts/vlans-tagged-untagged-and-trunks.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Ubiquiti UniFi (Por SSH dentro del AP): Ver estado de adopción, radios, canal, potencia TX y clientes
info
mca-cli-op dump-short

# MikroTik RouterOS v7 (WiFi / WiFiWave2 / CAPsMAN): Ver interfaces WiFi, clientes registrados (RSSI) y canales
/interface wifi print
/interface wifi registration-table print stats

# Aruba / Cisco WLC: Ver resumen de APs registrados, canales, potencia y clientes asociados
show ap summary
show ap radio-summary

# Linux (Desde una laptop de auditoría WiFi): Ver BSSID del AP conectado, canal, ancho MHz y señal en dBm
iw dev wlan0 link
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

Instalar WiFi en una empresa con 10 puntos de acceso no tiene nada que ver con poner un router WiFi fuerte en una casa. Si ponés los 10 puntos de acceso con la **potencia al 100% (`High / Auto`)** y anchos de canal gigantes (`80 MHz` en `2.4 GHz`), creás un desastre llamado **Clientes Pegados (*Sticky Clients*) e Interferencia Co-Canal**:

1. **La asimetría de potencia (AP gritando vs Celular susurrando):** Un AP empresarial puede gritar a `26 dBm` (`400 mW`), pero la pequeña antena y batería de un celular o laptop solo transmite a **`14 dBm` (`25 mW`)**. Si ponés el AP a máxima potencia, el celular a 40 metros de distancia ve "4 rayitas de WiFi" (porque escucha el grito del AP lejano) y **se niega a soltarlo para saltar al AP nuevo que tiene arriba de su cabeza**, pero cuando el celular intenta contestar con su susurro de `14 dBm`, el AP lejano no lo escucha y el usuario dice *"tengo WiFi lleno pero no carga nada"*.
2. **Segmentación de SSIDs por VLAN (`802.1Q`):** Cómo hacer que un mismo AP emita `"Empresa-Staff"` (conectado directo a la `VLAN 10`), `"Empresa-IoT"` (`VLAN 100`) y `"Empresa-Invitados"` (`VLAN 200` aislado) sobre un único cable Trunk/Híbrido hacia el switch.

> **🧠 Recordatorio del modelo mental:** Pensá en una red de múltiples APs WiFi como **poner parlantes de música funcional en las distintas salas de un museo**: si ponés 1 solo parlante a todo volumen en el pasillo central, en todas las salas se escucha un eco aturdidor y nadie puede conversar. En una red WiFi profesional ponés **muchos parlantes a volumen moderado/bajo (`12–15 dBm` en 2.4GHz y `18–20 dBm` en 5GHz)** en canales distintos para que, apenas camines de la Sala 1 a la Sala 2, tu oído deje de escuchar el parlante 1 y sintonice limpio el parlante 2 (**Roaming `802.11k/v/r`**).

---

## 2. 🗺️ Topología de referencia

Conectaremos puntos de acceso empresariales (**Ubiquiti UniFi, MikroTik WiFi v7 o Aruba**) a un switch gestionable que sube al router principal:

```text
   [RTR-BORDE: DHCP/Gateway VLANs 10, 99, 200]       [Controlador UniFi / CAPsMAN]
                        ||                                 (10.1.99.5 / VLAN 99)
                        || Trunk (10, 99, 200)                       |
                        v                                            |
         +-----------------------------------------------------------+
         |                         SW-ACCESO                         |
         +-----------------------------------------------------------+
            | (Puerto 4: Híbrido -> PVID/Native=99, Tagged=10, 200)
            v
   +-------------------------------------------------------+
   |                 ACCESS POINT EMPRESARIAL              |
   |  - Gestión del propio AP: IP 10.1.99.51 (Untagged 99) |
   |  - SSID "Empresa-Staff"  --> Etiqueta en VLAN 10      |
   |  - SSID "Empresa-Guest"  --> Etiqueta en VLAN 200     |
   +-------------------------------------------------------+
```

### Parámetros de Radiofrecuencia (RF) Estándar para Oficinas

| Banda de Frecuencia | Canales permitidos sin solapamiento | Ancho de Canal (*Channel Width*) | Potencia TX recomendada (`EIRP`) | Por qué se configura así |
|---------------------|-------------------------------------|:--------------------------------:|:--------------------------------:|--------------------------|
| **`2.4 GHz`** | **SOLO `1`, `6` u `11`** *(¡Jamás usar canal 2, 3, 4, 5, 7, 8, 9 o 10!)* | **`20 MHz`** *(Prohibido 40 MHz en 2.4G)* | **`10 a 14 dBm`** (*Low / Medium*) | `2.4 GHz` atraviesa paredes y llega muy lejos: hay que **bajarle la potencia** para que sea `6 dB` menor que `5 GHz` y los celulares prefieran siempre `5 GHz` (*Band Steering*) |
| **`5 GHz`** | `36, 40, 44, 48` (UNII-1), `52–64, 100–144` (DFS), `149–165` (UNII-3) | **`40 MHz`** (o `20 MHz` en auditorios densos; `80 MHz` solo con pocos APs) | **`17 a 20 dBm`** (*Medium / High*) | `5 GHz` tiene mucha más velocidad y menos interferencia, pero se atenúa más rápido al cruzar paredes |
| **`6 GHz` (WiFi 6E/7)** | Canales limpios de `160 / 80 MHz` | `80 MHz` / `160 MHz` | `18 a 21 dBm` | Exige obligatoriamente seguridad **`WPA3` (`802.11w PMF`)** |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. Paso 1 Obligatorio: Configurar el Puerto del Switch donde se enchufa el Access Point

Antes de tocar el WiFi, el puerto del switch donde va enchufado el AP (`Puerto 4`) debe entregarle la **VLAN de Gestión (`99`) sin etiqueta (`Untagged / PVID 99`)** y las **VLANs de los SSIDs (`10` y `200`) etiquetadas (`Tagged`)**:

```text
# En Switch Cisco IOS:
interface GigabitEthernet1/0/4
 description AP_WIFI_CORPORATIVO
 switchport mode trunk
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,99,200
 spanning-tree portfast trunk

# En Switch MikroTik RouterOS v7:
/interface bridge port set [find interface=ether4] pvid=99 frame-types=admit-all ingress-filtering=yes edge=yes
/interface bridge vlan set [find vlan-ids=10]  tagged=ether1,ether4
/interface bridge vlan set [find vlan-ids=200] tagged=ether1,ether4
/interface bridge vlan set [find vlan-ids=99]  tagged=bridge1,ether1 untagged=ether4

# En Switch Aruba:
vlan 99  untagged 4
vlan 10  tagged 4
vlan 200 tagged 4
```

---

### B. MikroTik RouterOS v7 (Paquete moderno `/interface wifi` — WiFi 6 / WiFiWave2 con VLANs y Fast Roaming `802.11k/v/r`)

En RouterOS v7.13+, el menú unificado **`/interface wifi`** soporta roaming `802.11r/k/v` nativo (`ft=yes`) y asignación de VLANs por datapath:

```text
# 1. Definir los perfiles de Seguridad (con Fast Roaming 802.11r 'ft=yes' y 'ft-over-ds=yes' activos!):
/interface wifi security
add name=sec-staff authentication-types=wpa2-psk,wpa3-psk passphrase="PasswordStaffCorporativo!2026" ft=yes ft-over-ds=yes
add name=sec-guest authentication-types=wpa2-psk,wpa3-psk passphrase="PasswordInvitados!2026"        ft=yes ft-over-ds=yes

# 2. Definir los Datapaths que conectan cada SSID con su VLAN dentro del bridge1 (y client-isolation en Invitados):
/interface wifi datapath
add name=dp-vlan10-staff  bridge=bridge1 vlan-id=10  client-isolation=no
add name=dp-vlan200-guest bridge=bridge1 vlan-id=200 client-isolation=yes

# 3. Configurar las radios físicas (2.4 GHz a 20MHz canal 1 con potencia moderada 13dBm; 5 GHz a 40MHz canal 36 con 19dBm):
/interface wifi
set [find default-name=wifi1] name=wifi1-5ghz \
    configuration.ssid="Empresa-Staff" configuration.mode=ap configuration.country=Argentina \
    channel.band=5ghz-ax channel.width=20/40mhz-Ce channel.frequency=5180 channel.tx-power=19 \
    security=sec-staff datapath=dp-vlan10-staff disabled=no

set [find default-name=wifi2] name=wifi2-2ghz \
    configuration.ssid="Empresa-Staff" configuration.mode=ap configuration.country=Argentina \
    channel.band=2ghz-ax channel.width=20mhz channel.frequency=2412 channel.tx-power=13 \
    security=sec-staff datapath=dp-vlan10-staff disabled=no

# 4. Crear los SSIDs virtuales adicionales para Invitados (VLAN 200) sobre ambas radios:
add name=wifi1-5ghz-guest master-interface=wifi1-5ghz configuration.ssid="Empresa-Invitados" security=sec-guest datapath=dp-vlan200-guest disabled=no
add name=wifi2-2ghz-guest master-interface=wifi2-2ghz configuration.ssid="Empresa-Invitados" security=sec-guest datapath=dp-vlan200-guest disabled=no

# 5. Agregar las interfaces WiFi como tagged en sus VLANs dentro del bridge1:
/interface bridge vlan
set [find vlan-ids=10]  tagged=ether1,wifi1-5ghz,wifi2-2ghz
set [find vlan-ids=200] tagged=ether1,wifi1-5ghz-guest,wifi2-2ghz-guest
```

---

### C. Ubiquiti UniFi (Adopción Capa 3 por SSH y Configuración de Redes/Perfiles en UniFi Network)

Cuando conectás un AP UniFi nuevo en la `VLAN 99` y el controlador UniFi (`10.1.40.15`) está en otra VLAN (o en un VPS en la nube), así lo adoptás por SSH en 10 segundos:

```bash
# 1. Entrar por SSH al AP UniFi recién conectado (credenciales de fábrica antes de adoptar: ubnt / ubnt)
ssh ubnt@10.1.99.51

# 2. Ver estado actual ('Status: Not Adopted' o 'Server Reject')
info

# 3. Apuntar el AP hacia la IP o dominio de tu controlador UniFi (Adopción Capa 3):
set-inform http://10.1.40.15:8080/inform
# -> Ir a la interfaz web del controlador UniFi, hacer clic en "Adopt", y volver a correr 'set-inform' si lo pide.
```

**Parámetros exactos a configurar en el Controlador UniFi (*Settings → WiFi & Networks*):**

1. **Networks:** Crear `VLAN 10 - Staff` (*VLAN-Only / Third-Party Gateway*, `VLAN ID = 10`) y `VLAN 200 - Guest` (`VLAN ID = 200`).
2. **WiFi `"Empresa-Staff"`:** Asociar a `Network: VLAN 10`, activar **Fast Roaming (`802.11r`)** y **BSS Transition (`802.11v`)**.
3. **WiFi `"Empresa-Invitados"`:** Asociar a `Network: VLAN 200`, activar **Client Device Isolation** (impide que un invitado escanee a otro invitado en el mismo AP).
4. **Radios (APs):** Desactivar *Nightly Channel Optimization* automático si causa cortes; fijar en `2.4 GHz` ancho **`20 MHz`**, canales alternados **`1, 6, 11`** y potencia **`Low / Custom 13 dBm`**; fijar en `5 GHz` ancho **`40 MHz`** y potencia **`Medium / Custom 19 dBm`**.

---

## 4. 🔑 Salida clave e interpretación de flags

### En Ubiquiti UniFi por SSH (`info`)

```text
Model:       U6-Pro
Version:     6.6.73.15402
MAC Address: 74:83:c2:99:88:77
IP Address:  10.1.99.51
Hostname:    AP-RECEPCION
Uptime:      421500 seconds
NTP:         Synchronized
Status:      Connected (http://10.1.40.15:8080/inform)
```

### En MikroTik (`/interface wifi registration-table print stats`)

```text
[netops@AP-PISO1] > /interface wifi registration-table print stats
Columns: INTERFACE, SSID, MAC-ADDRESS, UPTIME, SIGNAL, TX-RATE, RX-RATE
# INTERFACE   SSID           MAC-ADDRESS        UPTIME   SIGNAL  TX-RATE    RX-RATE
0 wifi1-5ghz  Empresa-Staff  A4:83:E7:11:22:33  1h25m    -54     864.7Mbps  720.6Mbps
1 wifi1-5ghz  Empresa-Staff  3C:22:FB:44:55:66  12m10s   -81     24.0Mbps   6.0Mbps
```

### Tabla de interpretación de Niveles de Señal WiFi (`RSSI` en `dBm`)

| Señal (`SIGNAL / RSSI`) | Calidad de Conexión | Velocidad esperada (`TX/RX Rate`) | Diagnóstico e interpretación en campo |
|:-----------------------:|---------------------|-----------------------------------|---------------------------------------|
| **`-35 dBm` a `-60 dBm`** | 🏆 **Excelente** | `400 – 1200 Mbps` (`MCS 9–11`) | Cobertura ideal en la misma sala con línea de vista al AP |
| **`-61 dBm` a `-67 dBm`** | ✅ **Muy Buena (Límite VoIP)** | `150 – 400 Mbps` | **`-67 dBm` es el umbral de diseño profesional para voz/videollamadas sin cortes** |
| **`-68 dBm` a `-74 dBm`** | 🟡 **Aceptable (Solo navegación)** | `54 – 144 Mbps` | Empiezan las retransmisiones de capa 2; el cliente ya debería buscar otro AP más cercano |
| **`-75 dBm` a `-85 dBm`** | ❌ **Mala (*Sticky Client*)** | `6 – 24 Mbps` (`1 Mbps` en 2.4G) | 🚨 **Este único cliente en `-81 dBm` enlentece a TODOS los demás clientes de ese AP** porque consume todo el tiempo de aire (*Airtime*) transmitiendo a `6 Mbps`! |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: El usuario conecta al WiFi `"Empresa-Staff"`, le acepta la contraseña WiFi al instante, pero queda en *"Obteniendo dirección IP..."* y termina sin Internet (`169.254.x.x`)

1. **Diagnóstico inmediato en 10 segundos:**
   - Que acepte la contraseña WiFi significa que la **radio del AP y la autenticación WPA2/WPA3 están 100% sanas**.
   - Que falle en *"Obteniendo dirección IP..."* significa que el AP etiquetó el paquete `DHCP Discover` del celular con la **`VLAN 10` (`802.1Q`)** y lo mandó por su cable Ethernet hacia el switch, **pero el puerto del switch donde está enchufado ese AP no tiene permitida la `VLAN 10` como `Tagged`**.
2. **Corrección:** Entrar al switch, revisar el puerto de ese AP (`show interfaces Gi1/0/4 switchport` / `/interface bridge vlan print`) y agregar la VLAN 10 como `tagged` (`allowed vlan add 10`).

### Síntoma 2: En el controlador UniFi un AP pasa de `Online` a `Adoption Failed` o `Offline` pero los usuarios conectados a ese AP siguen navegando por Internet normalmente

1. **Por qué los usuarios siguen navegando:** Porque en UniFi (y en Aruba Instant / MikroTik local forwarding), el plano de datos es autónomo: una vez que el AP descargó su configuración, aunque el servidor del Controlador UniFi se apague, el AP sigue funcionando y pasando tráfico entre los SSIDs y las VLANs del switch.
2. **Por qué figura `Adoption Failed` / `Offline`:** El AP (`10.1.99.51`) perdió comunicación con el puerto **`TCP 8080`** (y `UDP 3478` STUN) del servidor del controlador (`10.1.40.15`), o cambió la IP del servidor donde corre el controlador. Entrá por SSH al AP (`ssh admin@10.1.99.51`), mirá la última línea de `info` (`Status:`) y actualizá `set-inform http://<IP-CONTROLADOR>:8080/inform`.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Resguardar las credenciales SSH de Dispositivos en Controladoras (UniFi / Omada):**
  - Cuando un controlador adopta un AP, le cambia automáticamente su contraseña SSH (`ubnt/ubnt`) por un usuario y clave generados por el controlador (visibles en *Settings → System → Advanced → Device SSH Authentication*). Guardá siempre esas credenciales en tu gestor de contraseñas: si algún día se corrompe la máquina virtual del controlador y no tenés el backup ni la clave SSH de los APs, tendrías que subirte con una escalera al techo a presionar el botón físico `RESET` de cada uno de los 30 APs.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Poner el mismo canal (ej. todos en canal 6) o usar canales intermedios (`2, 3, 4, 8, 9`) en `2.4 GHz`:** En `2.4 GHz`, cada canal de `20 MHz` ocupa el ancho de 5 números de canal.Si ponés un AP en el canal `1` y otro en el canal `3`, sus espectros se pisan parcialmente y **se destruyen mutuamente como ruido e interferencia (*Adjacent-Channel Interference*)**, lo cual es mucho peor que compartir el mismo canal. **En `2.4 GHz` solo existen tres canales en el universo: `1`, `6` y `11`.**
- **❌ Crear más de 3 o 4 SSIDs distintos en los mismos APs (*Management Frame / Beacon Overhead*):** Cada SSID que creás obliga al AP a transmitir 10 tramas *Beacon* por segundo a la velocidad más baja (`1 Mbps` / `6 Mbps`). Si creás 6 u 8 SSIDs por radio (`Gerencia`, `Ventas`, `RRHH`, `Deposito`, `Invitados`, `Impresoras`), **más del 40% de todo el aire disponible se desperdicia solo anunciando los nombres de las redes WiFi** antes de transmitir un solo byte de datos. Usá como máximo **2 o 3 SSIDs** (`Corporativo`, `Invitados` e `IoT`).

---

## 8. ✅ Buenas prácticas profesionales

- **Regla de potencia `2.4 GHz` vs `5 GHz`:** Configurá siempre la potencia de transmisión de `2.4 GHz` entre **`6 dB` y `7 dB` más baja** que la de `5 GHz` (por ejemplo: `13 dBm` en `2.4 GHz` y `19 dBm` en `5 GHz`). Como la física hace que `2.4 GHz` se propague ~6 dB mejor en el aire que `5 GHz`, al restarle 6 dB a `2.4 GHz` lográs que ambas celdas tengan el mismo tamaño físico y que todas las laptops modernas elijan `5 GHz` de forma natural.
- **Usar el mismo nombre de SSID y contraseña en `2.4 GHz` y `5 GHz` con `802.11k/v/r` activos** para los usuarios corporativos, y si tenés dispositivos IoT baratos (ESP32, balanzas, impresoras viejas) que se confunden con redes dual-band, habilitá el SSID `"Empresa-IoT"` **únicamente en la radio de `2.4 GHz`**.

---

## 9. 🔗 Referencias internas

- [`vlans-8021q-access-trunk-pvid`](../02-switching-l2/vlans-8021q-access-trunk-pvid.md) — Configuración exacta del Puerto 4 (Híbrido) del switch para conectar el AP
- [`poe-budgeting-and-switch-management`](poe-budgeting-and-switch-management.md) — Cómo alimentar y reiniciar eléctricamente los APs desde el switch PoE
- [`ieee-and-ietf-networking-standards`](../../reference/ieee-and-ietf-networking-standards.md) — Referencia rápida de los estándares de roaming `802.11k`, `802.11v`, `802.11r` y seguridad `802.11w`
