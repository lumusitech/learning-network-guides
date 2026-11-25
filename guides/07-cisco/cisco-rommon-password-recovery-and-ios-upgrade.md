⬅️ [Volver a Guías](../README.md)

# Cisco ROMMON: Recuperación de Contraseñas (`0x2142`) y Rescate de Imagen IOS — Guía práctica

**Dominio:** `07-cisco`
**Nivel:** 🟡 Intermedio
**Estándares:** `Cisco ROMMON / Bootloader`, `Configuration Register (0x2102 vs 0x2142)`
**Concepto base:** [`how-to-think-like-network-engineer`](../../concepts/how-to-think-like-network-engineer.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS (Con el equipo encendido normalmente): Verificar el registro de configuración al final de 'show version'
show version | include Configuration register
show boot

# En el prompt de emergencia ROMMON de un Router ('rommon 1 >') o Switch ('switch:'):
dir flash:
set
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

Tarde o temprano en tu carrera te vas a enfrentar a una de estas dos situaciones críticas frente a un rack con equipos Cisco:

1. **Recuperación de Contraseña (*Password Recovery*) sin perder la configuración:** Heredás la red de una empresa cuyo administrador anterior se fue sin dejar las contraseñas (o compraron un router/switch usado bloqueado). Si lo reseteás de fábrica perdés las 400 líneas de VLANs, rutas y ACLs que hacen funcionar la empresa. Aquí aprenderás cómo entrar al gestor de arranque (**ROMMON**) por cable de consola, **decirle al equipo que arranque ignorando el archivo `startup-config` por una sola vez**, copiar la configuración intacta a la memoria RAM, cambiar la contraseña y volver a guardar sin perder ni una sola VLAN ni ruta.
2. **Rescate cuando el equipo cae en `switch:` o `rommon 1 >` porque alguien borró o corrompió la imagen IOS `.bin`:** Cómo arrancar desde una imagen de respaldo o copiar un sistema operativo nuevo por USB / consola / TFTP desde ROMMON.

> **🧠 Recordatorio del modelo mental:** Pensá en el **Configuration Register (`0x2102` vs `0x2142`)** o en la variable `SWITCH_IGNORE_STARTUP_CFG=1` como **el menú BIOS/GRUB de una PC Linux**: el archivo con las contraseñas y la configuración (`startup-config` en la NVRAM) sigue guardado intacto en el disco; nosotros solo le decimos al bootloader *"esta vez arrancá en blanco sin leer el archivo de inicio"*, y una vez que ya estamos adentro como administradores (`#`), abrimos ese archivo desde la NVRAM, le pisamos la línea de la contraseña por una nueva y lo volvemos a guardar.

---

## 2. 🗺️ Topología de referencia

Conexión física obligatoria en el rack mediante cable de consola serie (`9600 8N1`) y un pendrive USB formateado en `FAT32` con la imagen IOS por si hay que rescatar el sistema operativo:

```text
+-----------------------------------+
| Laptop del Ingeniero              |
| Consola Serie: 9600 8N1 (tio)     |
+-----------------------------------+
                 |
                 | Cable Consola RJ45 / Mini-USB (Obligatorio acceso físico!)
                 v
+-----------------------------------------------------------------------+
|  Router Cisco ISR (rommon 1 >)   O   Switch Cisco Catalyst (switch:)  |
|  - Registro Normal:  0x2102          - Variable: SWITCH_IGNORE_...=0  |
|  - Registro Rescate: 0x2142          - Rescate:  SWITCH_IGNORE_...=1  |
+-----------------------------------------------------------------------+
```

| Familia de Equipo Cisco | Cómo se entra al Bootloader al encender | Comando para ignorar la `startup-config` | Valor Normal de Producción |
|-------------------------|-----------------------------------------|------------------------------------------|:--------------------------:|
| **Routers Cisco ISR / ASR** (`2900`, `4300`, `1100`, etc.) | Enviar señal **`Break`** desde el programa serie en los primeros 30 segundos del encendido | **`confreg 0x2142`** seguido de `reset` | **`0x2102`** (`config-register 0x2102`) |
| **Switches Catalyst Clásicos** (`2960`, `3560`, `3750`) | Mantener presionado el botón físico frontal **`MODE`** mientras enchufás el cable de corriente (~15 seg hasta que el LED `SYST` quede fijo) | **`flash_init`** y renombrar `rename flash:config.text flash:config.old` | `flash:config.text` |
| **Switches Catalyst Modernos IOS-XE** (`Catalyst 9200 / 9300 / 3850 / 3650`) | Presionar el botón frontal **`MODE`** durante el arranque hasta entrar a `switch:` | **`SWITCH_IGNORE_STARTUP_CFG=1`** seguido de `boot` | **`SWITCH_IGNORE_STARTUP_CFG=0`** (`no system ignore startupconfig switch all`) |

---

## 3. 🛠️ Procedimiento paso a paso

### A. Caso 1: Recuperar contraseña en un **Router Cisco (`confreg 0x2142`)** sin perder la configuración

```text
! 1. Conectar el cable de consola a 9600 8N1, apagar y encender el router, y enviar la señal BREAK
!    (En 'tio': presionar Ctrl+T y luego la tecla B; en 'screen': Ctrl+A y luego Ctrl+B; en PuTTY: Clic derecho -> Special Command -> Break).
!    El router detiene el arranque y muestra el prompt:
rommon 1 >

! 2. Cambiar el registro de configuración a 0x2142 (el bit '4' le ordena ignorar la NVRAM startup-config!) y reiniciar:
rommon 1 > confreg 0x2142
rommon 2 > reset

! 3. El router arranca en blanco y pregunta: "Would you like to enter the initial configuration dialog? [yes/no]:"
!    ¡RESPONDER SIEMPRE 'no'! (Si respondés 'yes' y guardás, pisarás tu configuración vieja).
Would you like to enter the initial configuration dialog? [yes/no]: no

! 4. Entrar a modo privilegiado (¡no te pide contraseña porque arrancó en blanco!):
Router> enable
Router#

! 5. PASO MÁS IMPORTANTE: Copiar tu configuración original desde la NVRAM hacia la memoria RAM activa!
!    (¡OJO: Es 'copy startup-config running-config', NUNCA al revés!):
Router# copy startup-config running-config
Destination filename [running-config]? [Enter]

!    ¡Magia! El prompt cambia inmediatamente al hostname real de la empresa (ej. RTR-CENTRAL#)
!    y ya tenés todas tus rutas, VLANs y ACLs cargadas en la memoria RAM.

! 6. Definir tu nueva contraseña de enable y de usuario administrador:
RTR-CENTRAL# configure terminal
RTR-CENTRAL(config)# enable algorithm-type scrypt secret NuevaClaveRecuperada!2026
RTR-CENTRAL(config)# username netops privilege 15 algorithm-type scrypt secret NuevaClaveRecuperada!2026

! 7. (En un router que arrancó en blanco, las interfaces vienen en 'shutdown'; encender las que estaban en uso):
RTR-CENTRAL(config)# interface GigabitEthernet0/0
RTR-CENTRAL(config-if)# no shutdown
RTR-CENTRAL(config-if)# exit

! 8. OBLIGATORIO: Devolver el registro de configuración a su valor normal 0x2102!
!    (Si te olvidás este paso, en el próximo corte de luz el router volverá a arrancar en blanco!):
RTR-CENTRAL(config)# config-register 0x2102
RTR-CENTRAL(config)# end

! 9. Ahora sí, guardar la configuración con las contraseñas nuevas en la NVRAM y verificar:
RTR-CENTRAL# write memory
RTR-CENTRAL# show version | include Configuration register
```

---

### B. Caso 2: Recuperar contraseña en un **Switch Cisco Catalyst Moderno (`9200 / 9300 / 3850`)**

```text
! 1. En el prompt del bootloader 'switch:' (obtenido presionando el botón MODE durante el arranque):
!    Activar la variable que ignora la configuración de inicio y arrancar el sistema:
switch: SWITCH_IGNORE_STARTUP_CFG=1
switch: boot

! 2. Cuando pregunte por el asistente inicial, responder 'no' y entrar con 'enable':
Would you like to enter the initial configuration dialog? [yes/no]: no
Switch> enable
Switch#

! 3. Traer toda la configuración de la empresa desde la NVRAM a la memoria RAM:
Switch# copy startup-config running-config
Destination filename [running-config]? [Enter]

! 4. Cambiar la contraseña Y desactivar la bandera de ignorar startup-config para futuros reinicios:
SW-CORE# configure terminal
SW-CORE(config)# enable algorithm-type scrypt secret NuevaClaveSwitch!2026
SW-CORE(config)# username netops privilege 15 algorithm-type scrypt secret NuevaClaveSwitch!2026
SW-CORE(config)# no system ignore startupconfig switch all
SW-CORE(config)# end

! 5. Guardar en NVRAM:
SW-CORE# write memory
```

---

### C. Caso 3: Rescatar un Switch/Router que cayó en `switch:` o `rommon 1 >` porque no encuentra su imagen `.bin`

Si alguien borró la imagen de sistema operativo o apuntó mal el comando `boot system`, el equipo al encender cae en el prompt `switch:` o `rommon 1 >`:

```text
! 1. Primero listar qué archivos existen en la memoria flash interna o en un pendrive USB (usbflash0:):
switch: dir flash:
switch: dir usbflash0:

! 2. Si en 'flash:' ves que todavía está la imagen vieja sana (ej. c9200l-universalk9.17.06.04.SPA.bin)
!    o un archivo 'packages.conf', ordenale arrancar directamente desde ese archivo:
switch: boot flash:c9200l-universalk9.17.06.04.SPA.bin
!    (O si insertaste un pendrive USB FAT32 con la imagen en el puerto USB frontal del switch/router):
switch: boot usbflash0:c9200l-universalk9.17.09.05.SPA.bin

! 3. Una vez que el switch terminó de arrancar en IOS, copiar la imagen a la flash interna,
!    corregir la variable 'boot system' y guardar para que nunca más caiga en ROMMON:
SW-CORE# copy usbflash0:c9200l-universalk9.17.09.05.SPA.bin flash:
SW-CORE# configure terminal
SW-CORE(config)# no boot system
SW-CORE(config)# boot system flash:c9200l-universalk9.17.09.05.SPA.bin
SW-CORE(config)# end
SW-CORE# write memory
```

---

## 4. 🔑 Salida clave e interpretación de flags

### Verificación al final de `show version`

```text
# Estado SANO en producción:
Configuration register is 0x2102

# Estado PELIGROSO si alguien recuperó la clave y olvidó devolver el registro:
Configuration register is 0x2142 (will be 0x2102 at next reload)
```

### Tabla de Valores del Registro de Configuración (`Configuration Register`)

| Valor Hexadecimal | Qué hace el Router Cisco al encenderse | Cuándo debe estar puesto |
|:-----------------:|----------------------------------------|--------------------------|
| **`0x2102`** | Lee los comandos `boot system` y **carga normalmente la configuración guardada en `startup-config`** a `9600` baudios | ✅ **SIEMPRE en producción (100% de tus equipos)** |
| **`0x2142`** | Arranca el sistema operativo IOS, pero **ignora por completo la `startup-config`** (arranca como recién salido de fábrica sin borrar la NVRAM) | ⚠️ **Solo durante los 5 minutos de una recuperación de contraseña** |
| **`0x2100`** | No arranca siquiera el sistema operativo IOS; se detiene siempre directo en el prompt `rommon 1 >` | ❌ Nunca dejar en `0x2100`: ante cualquier corte de luz el router quedará muerto en ROMMON |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Un router de una sucursal pierde toda su configuración cada vez que hay un corte de luz en el barrio, aunque el técnico jura que ejecutó `write memory`

1. **Verificación inmediata:** `show version | include Configuration register`
2. **Qué vas a encontrar en la última línea:** `Configuration register is 0x2142`.
3. **Por qué ocurría:** Meses atrás alguien hizo una recuperación de contraseña con `confreg 0x2142`, cargó la configuración, hizo `write memory` (que efectivamente guardó el archivo en la NVRAM), **pero se olvidó de ejecutar `config-register 0x2102`**. Entonces, cada vez que se corta la luz, la NVRAM tiene el archivo guardado pero el bootloader tiene orden de ignorarlo (`0x2142`)!
4. **Corrección en 10 segundos:** `configure terminal` → `config-register 0x2102` → `end` → `write memory`.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **¿Qué pasa si no tenés puerto USB y tenés que subir una imagen IOS desde ROMMON en un switch viejo (`2960 / 3560`) por el cable de consola serie (`xmodem`)?**
  - A `9600` baudios, subir un archivo de 15 MB por consola tarda **4 horas**.
  - **Truco vital en ROMMON antes de iniciar `copy xmodem: flash:`:** Cambiá primero la velocidad de la consola en ROMMON a **`115200` baudios** (`set BAUD 115200` en `switch:` o `confreg` en `rommon >`), reconectá tu programa `tio`/`minicom` a `115200`, subí la imagen 12 veces más rápido (~20 minutos), y al terminar devolvé la velocidad a **`set BAUD 9600`** (`unset BAUD`) antes de arrancar.

---

## 7. ⚠️ Errores comunes en producción

- **❌ En el Paso 5 de la recuperación de contraseña, escribir `copy running-config startup-config` (`write memory`) cuando el router acaba de arrancar en blanco:**
  - ¡Peligro mortal! Cuando el router recién arranca con `0x2142`, la `running-config` (RAM) está **VACÍA** y toda la configuración valiosa de la empresa está en la `startup-config` (NVRAM).
  - Si por reflejo muscular escribís `write memory` antes de haber hecho `copy startup-config running-config`, **sobrescribís la NVRAM con la configuración vacía y destruís para siempre toda la configuración del router**.
- **❌ Responder `yes` a la pregunta `Would you like to enter the initial configuration dialog? [yes/no]:`:** Respondé siempre **`no`**.

---

## 8. ✅ Buenas prácticas profesionales

- **Auditar en todos tus equipos Cisco que el registro sea `0x2102` y `Switch Ignore Startup-Cfg` esté desactivado:** Incluí `show version | include Configuration register` en tu checklist de recepción de equipos y post-mantenimiento.
- **Seguridad física del rack:** Como cualquier persona con acceso físico al botón `MODE` y al puerto `CONSOLE` puede recuperar la contraseña de un switch (a menos que hayas activado `no service password-recovery`), los racks de comunicaciones deben estar siempre bajo llave y en salas con acceso controlado.

---

## 9. 🔗 Referencias internas

- [`cisco-ios-cli-architecture-and-hardening`](cisco-ios-cli-architecture-and-hardening.md) — Arquitectura de memorias RAM (`running-config`) vs NVRAM (`startup-config`) vs Flash
- [`firmware-upgrades-and-maintenance-windows`](../08-operations/firmware-upgrades-and-maintenance-windows.md) — Procedimiento normal de actualización de imágenes IOS para nunca caer en ROMMON por error
- [`serial-console-and-oob-access`](../01-fundamentals/serial-console-and-oob-access.md) — Configuración del cable de consola serie y envío de la señal `Break`
