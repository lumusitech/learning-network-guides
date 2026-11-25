⬅️ [Volver a Guías](../README.md)

# Consola Serie (RS-232/USB) y Acceso Out-of-Band (OOB) — Guía práctica multi-vendor

**Dominio:** `01-fundamentals`
**Nivel:** 🟢 Básico
**Estándares:** `TIA/EIA-232-F (RS-232)`, `Yost Serial Pinout (Rollover)`
**Concepto base:** [`how-to-think-like-network-engineer`](../../concepts/how-to-think-like-network-engineer.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Linux: Identificar qué puerto USB-Serie fue detectado al enchufar el cable consola
dmesg | tail -n 15
ls -l /dev/ttyUSB* /dev/ttyACM*

# Conectar a un Switch/Router Cisco (9600 baudios, 8N1, sin control de flujo)
tio -b 9600 /dev/ttyUSB0
# Alternativa con screen:
screen /dev/ttyUSB0 9600

# Conectar a un Router/Switch MikroTik o Aruba moderno (115200 baudios, 8N1)
tio -b 115200 /dev/ttyUSB0
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

Cuando un switch o router nuevo sale de la caja sin dirección IP, cuando un error en el firewall `INPUT` o en las VLANs te deja afuera por SSH, o cuando el equipo ni siquiera termina de arrancar (quedando en el gestor de arranque **ROMMON** o **RouterBOOT**), la red TCP/IP no existe. Tu única puerta de entrada física y directa al procesador del equipo es el **Puerto de Consola Serie (`CONSOLE`)**.

Además, en salas de servidores o sitios remotos, conectar los cables de consola de tus switches y routers a un **Servidor de Consola Out-of-Band (OOB)** (o a un mini-nodo con módem 4G LTE independiente) te permite entrar como si estuvieras parado frente al rack aunque toda la fibra óptica principal de la empresa esté cortada.

> **🧠 Recordatorio del modelo mental:** Pensá en el acceso por SSH/WinBox sobre la red normal (*In-Band*) como **operarse a uno mismo mientras se está despierto**: si tocás la arteria equivocada (la VLAN o ruta por donde viaja tu propio SSH), te desmayás y no podés seguir operando. El cable de consola serie (**Out-of-Band**) es una **vía médica independiente** que nunca se corta aunque apagues todas las placas de red del equipo.

---

## 2. 🗺️ Topología de referencia

Todos los ejemplos de esta guía implementan este esquema de acceso directo desde una laptop Linux de campo (o un servidor de consola OOB en el rack) hacia los puertos `CONSOLE` de los equipos:

```text
+-----------------------------------+
| Laptop del Ingeniero / Nodo OOB   |
| (Linux: /dev/ttyUSB0, /dev/ttyACM0|
+-----------------------------------+
        |                   |
        | Cable USB-RJ45    | Cable USB-C / Micro-USB o RJ45 Rollover
        | (Chip FTDI)       |
        v                   v
[Puerto CONSOLE RJ45]   [Puerto CONSOLE RJ45 / USB]
+-------------------+   +-------------------------+
|  Cisco Catalyst   |   |  MikroTik CCR / CRS3xx  |
|  Baud: 9600 8N1   |   |  Baud: 115200 8N1       |
+-------------------+   +-------------------------+
```

| Fabricante / Familia | Velocidad por defecto (*Baud Rate*) | Bits de datos / Paridad / Stop | Control de flujo (*Flow Control*) | Tipo de conector físico común |
|----------------------|:-----------------------------------:|:------------------------------:|:---------------------------------:|-------------------------------|
| **Cisco IOS / Catalyst / Nexus** | **`9600`** | `8` / `None` / `1` (`8N1`) | **`None` (`OFF`)** | RJ45 Celeste (*Rollover*) o Mini-USB / USB-C |
| **MikroTik RouterOS (`RB / CCR / CRS`)** | **`115200`** | `8` / `None` / `1` (`8N1`) | **`None` (`OFF`)** | RJ45 (pinout Cisco) o DB9 |
| **Aruba / HP ProCurve / CX** | **`115200`** (o *Auto-sensing* `9600–115200`) | `8` / `None` / `1` (`8N1`) | **`None` (`OFF`)** | RJ45, Micro-USB o USB-C |
| **Ubiquiti EdgeSwitch / UniFi Pro / FortiGate** | **`115200`** (`9600` en modelos antiguos) | `8` / `None` / `1` (`8N1`) | **`None` (`OFF`)** | RJ45 (pinout Cisco) |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. Estación de Trabajo Linux (Preparación del cliente serie sin usar `sudo`)

```bash
# 1. Agregar tu usuario al grupo 'dialout' (Debian/Ubuntu) o 'uucp' (Arch Linux)
#    para acceder a /dev/ttyUSB0 sin necesitar sudo:
sudo usermod -aG dialout "$USER"

# 2. Instalar herramientas modernas de consola serie:
#    - 'tio': reconecta automáticamente si desenchufás y volvés a enchufar el USB
#    - 'minicom' y 'screen': clásicos universales disponibles en cualquier servidor
sudo apt install -y tio minicom screen

# 3. Conectarse con tio (Para salir de tio: presionar Ctrl+T y luego la tecla Q)
tio -b 9600 -d 8 -f none -s 1 -p none /dev/ttyUSB0      # Cisco
tio -b 115200 -d 8 -f none -s 1 -p none /dev/ttyUSB0    # MikroTik / Aruba / Fortinet

# 4. Conectarse con screen (Para salir de screen: presionar Ctrl+A y luego K)
screen /dev/ttyUSB0 115200
```

### B. Cisco IOS / Catalyst (Asegurar y optimizar el puerto `line con 0`)

```cisco
! 1. Entrar a la configuración de la consola física
configure terminal
line console 0

! 2. Evitar que los mensajes del log te corten por la mitad el comando que estás escribiendo
 logging synchronous

! 3. Cerrar la sesión automáticamente tras 10 minutos de inactividad (por si alguien olvida la laptop conectada)
 exec-timeout 10 0

! 4. Exigir usuario y contraseña local (definidos en 'username admin secret ...' o AAA)
 login local

! 5. (Opcional) No perder tiempo intentando resolver por DNS si tipeás mal un comando
 no ip domain-lookup (en modo global)

end
write memory
```

### C. MikroTik RouterOS (v7+)

```text
# 1. Ver los puertos serie físicos del equipo y quién los está usando
/port print
/system console print

# 2. Verificar o fijar la velocidad del puerto serie (serial0) en 115200 8N1 sin flow-control
/port set serial0 baud-rate=115200 data-bits=8 parity=none stop-bits=1 flow-control=none

# 3. Asegurar que la consola serie esté activa y pida login siempre
/system console enable [find port=serial0]

# 4. (Avanzado — Usar el MikroTik como servidor OOB para entrar al puerto consola de un Cisco vecino!)
#    Si conectás un cable USB-Serie FTDI al puerto USB del MikroTik, aparece como 'usb1' o 'serial1':
/system serial-terminal port=usb1 channel=0
# (Para salir de serial-terminal en MikroTik: presionar Ctrl+A y luego Q)
```

### D. Switches Gestionables (Aruba / HP)

```text
# 1. Fijar timeout de inactividad en consola y velocidad explícita
configure
console baud-rate speed-sense
console inactivity-timer 10
aaa authentication login privilege-mode
write memory
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En Linux al conectar el cable USB-Serie (`dmesg`)

```text
[ 1420.112045] usb 1-2: new full-speed USB device number 5 using xhci_hcd
[ 1420.264110] usb 1-2: New USB device found, idVendor=0403, idProduct=6001, bcdDevice= 6.00
[ 1420.264122] usb 1-2: Product: FT232R USB UART
[ 1420.268901] ftdi_sio 1-2:1.0: FTDI USB Serial Device converter detected
[ 1420.270112] usb 1-2: FTDI USB Serial Device converter now attached to ttyUSB0
```

### En MikroTik (`/port print` y `/system console print`)

```text
[admin@RTR-CORE] > /port print
Flags: I - inactive
Columns: NAME, CHANNELS, USED-BY, BAUD-RATE
# NAME     CHANNELS  USED-BY         BAUD-RATE
0 serial0         1  Serial Console  115200
1 usb2            1                  9600

[admin@RTR-CORE] > /system console print
Flags: X - disabled, U - used, F - free
#   PORT     TERM
0 F serial0  vt102
```

### Tabla de interpretación de columnas y flags

| Columna / Flag | Fabricante | Qué significa realmente | Estado sano vs Estado roto |
|----------------|------------|-------------------------|----------------------------|
| **`FT232R` → `ttyUSB0`** | Linux Kernel | El chip conversor USB-Serie (FTDI/CH340/CP2102) fue reconocido y mapeado a `/dev/ttyUSB0` | Si no aparece ningún `ttyUSB*`, estás usando un cable USB de "solo carga" o un chip Prolific PL2303 falso sin driver |
| **`USED-BY: Serial Console`** | MikroTik (`/port`) | El puerto serie físico está asignado a la terminal de login de RouterOS | Si querés usar ese puerto para conectar un módem GPS/UPS o salir hacia otro switch con `serial-terminal`, primero debés deshabilitar `/system console` en ese puerto |
| **`F` (*Free*) vs `U` (*Used*)** | MikroTik (`/system console`) | `F`: la consola serie está esperando que alguien se conecte. `U`: hay un administrador logueado ahora mismo por el cable consola | Permite auditar a distancia si hay un técnico conectado físicamente al rack en ese momento |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: La pantalla muestra caracteres basura ilegibles (`~x?@`)

1. **Causa raíz:** Tenés configurada una velocidad en baudios (**Baud Rate**) distinta a la que está hablando el equipo (por ejemplo, abriste a `9600` contra un MikroTik que habla a `115200`, o un Cisco al que alguien le cambió la velocidad en ROMMON a `115200` para subir una imagen IOS rápido).
2. **Corrección:** Cerrá la sesión (`Ctrl+T` luego `Q` en `tio`) y probá en este orden las velocidades estándar: **`115200` → `9600` → `38400` → `57600` → `19200`**.

### Síntoma 2: Ves el texto perfecto cuando el equipo arranca, pero cuando tecleás `Enter` no responde nada

1. **Causa raíz:** Tenés activado el **Hardware Flow Control (`RTS/CTS`)** en tu programa (`minicom` lo trae en `Yes` por defecto) o el pin `TX` de tu cable USB-RJ45 está roto.
2. **Corrección:** En `minicom` presioná `Ctrl+A` → `O` → *Serial port setup* → presioná la tecla **`F`** para cambiar *Hardware Flow Control* a **`No`**. (O usá `tio`, que desactiva el control de flujo por defecto).

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Truco de Oro — Usar un MikroTik del rack como Servidor OOB de emergencia:**
  - Si tenés un router MikroTik con puerto USB en una sucursal remota y al lado hay un switch Cisco al que tenés miedo de perder acceso al cambiar sus VLANs, dejá enchufado permanentemente un cable **USB-a-Consola RJ45** desde el puerto USB del MikroTik al puerto `CONSOLE` del switch Cisco.
  - Si cometés un error en el Cisco y pierde su IP, entrás por SSH/VPN al MikroTik y ejecutás `/system serial-terminal port=usb1 channel=0`: estás adentro de la consola física del Cisco a 500 km de distancia.
- **Rollback de velocidad de consola en Cisco:**
  - Si un técnico dejó la consola de un Cisco en `115200`, entrá a `115200` y ejecutá en `line con 0`: `speed 9600` (y si había cambiado el registro en ROMMON, `config-register 0x2102`).

---

## 7. ⚠️ Errores comunes en producción

- **❌ Confundir un cable de red Ethernet con el cable de Consola RJ45 Celeste:** Ambos tienen ficha RJ45, pero el puerto `CONSOLE` trabaja con voltajes serie RS-232 (`±12V`), no con Ethernet. Nunca enchufes un puerto PoE activo en un puerto `CONSOLE`.
- **❌ Dejar la sesión de consola logueada como `enable` (privilegiada) sin `exec-timeout`:** Si dejás `exec-timeout 0 0` (nunca expirar) y un técnico desconecta el cable consola sin escribir `exit`, **la sesión queda abierta eternamente**. El próximo que enchufe un cable consola en ese rack apretará `Enter` y estará adentro como administrador total sin que el equipo le pida contraseña.
- **❌ No activar `logging synchronous` en Cisco:** Cuando estás a mitad de escribir un comando delicado y salta un mensaje de log en la pantalla, el texto se mezcla con tu comando. Con `logging synchronous`, el router redibuja limpio tu comando abajo de cada mensaje de log.

---

## 8. ✅ Buenas prácticas profesionales

- **Llevar siempre en la mochila un cable USB-a-RJ45 con chip FTDI original:** Los cables con chip **FTDI (`FT232R`)** funcionan de forma nativa sin instalar drivers en Linux, macOS, Windows y dentro de MikroTik RouterOS (para usarlos como consola OOB).
- **Documentar en la etiqueta física del equipo si su baud rate no es el estándar:** Si un equipo fue cambiado de `9600` a `115200` o viceversa, volverlo siempre al estándar del fabricante (`9600` Cisco, `115200` MikroTik/Aruba).
- **Capturar toda la sesión de consola a un archivo de texto durante mantenimientos críticos:** Usar `tio --log --log-file mantenimiento-sw-core.log -b 115200 /dev/ttyUSB0` deja grabada toda la intervención por si el equipo muestra un *Kernel Panic* o error de arranque.

---

## 9. 🔗 Referencias internas

- [`how-to-think-like-network-engineer`](../../concepts/how-to-think-like-network-engineer.md) — Diferencia entre Plano de Gestión, Control y Datos
- [`ssh-hardening-and-management-plane`](ssh-hardening-and-management-plane.md) — El paso siguiente una vez que entraste por consola: configurar SSH seguro y VLAN de Management
- [`multivendor-cli-rosetta-stone`](../../reference/multivendor-cli-rosetta-stone.md) — Comandos base equivalentes una vez abierta la consola
