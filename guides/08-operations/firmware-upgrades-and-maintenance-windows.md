⬅️ [Volver a Guías](../README.md)

# Actualizaciones de Firmware y Ventanas de Mantenimiento — Guía práctica multi-vendor

**Dominio:** `08-operations`
**Nivel:** 🟡 Intermedio
**Estándares:** `ITIL Change Management`, `MikroTik RouterOS + RouterBOOT`, `Cisco IOS / Install Mode`
**Concepto base:** [`netops-day-to-day-maintenance-and-observability`](../../concepts/netops-day-to-day-maintenance-and-observability.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Verificar versión de SO (RouterOS) Y versión de Bootloader (RouterBOOT)
/system resource print
/system package update print
/system routerboard print

# Cisco IOS / Catalyst: Verificar versión actual, imagen de arranque (BOOT variable) y hash MD5/SHA512
show version
show boot
verify /md5 flash:c9200l-universalk9_ias.17.09.05.SPA.bin

# Aruba / HP ProCurve: Ver las dos particiones de flash (Primary vs Secondary) y cuál arrancará
show flash
show version
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

Actualizar el firmware de un router o switch en producción es el momento de mayor riesgo en la operación de una red: corrige vulnerabilidades de seguridad críticas (CVEs) y bugs de estabilidad, pero si se ejecuta sin verificar el espacio en disco, sin validar la integridad del archivo o olvidando la variable de arranque (`boot system`), **el equipo se reinicia y queda atrapado en el bootloader (`ROMMON`) a 300 kilómetros de distancia**.

Esta guía estandariza el **Runbook de 4 Fases (Pre-Check → Backup → Upgrade en dos etapas → Post-Check)** para actualizar **MikroTik RouterOS (incluyendo el olvidado RouterBOOT)**, **Cisco IOS** y **Switches Aruba/HP con doble partición** sin sorpresas.

> **🧠 Recordatorio del modelo mental:** Pensá en actualizar el firmware de un router remoto como **cambiarle los neumáticos y revisar los frenos al camión de caudales**: nunca lo hacés un viernes a la noche sin rueda de auxilio; primero sacás una foto exacta de cómo está funcionando todo (*Pre-Check*), guardás los planos afuera (*Backup*), verificás que el repuesto sea el correcto (*Hash MD5/SHA*) y al terminar comprobás que todas las rutas y frenos respondan igual que antes (*Post-Check*).

---

## 2. 🗺️ Topología de referencia

Secuencia de mantenimiento sobre el router de borde y el switch core garantizando continuidad o recuperación por vía secundaria:

```text
[Estación del Ingeniero] ---> 1. Guarda Pre-Check (rutas, vecinos OSPF, túneles, VLANs)
                         ---> 2. Descarga a su laptop el .rsc + .backup / startup-config
                         ---> 3. Verifica espacio en Flash y sube/descarga firmware Stable
                         ---> 4. Reinicia y compara Post-Check contra la foto del paso 1
```

| Fabricante | Componentes que se actualizan | Canal recomendado en Producción | Cuántos reinicios requiere |
|------------|-------------------------------|---------------------------------|:--------------------------:|
| **MikroTik RouterOS** | **1. Paquetes (`RouterOS`)** + **2. Bootloader (`RouterBOOT`)** | **`stable`** (o `long-term`) — *Nunca `testing` en prod* | `2` (o `1` si activás `auto-upgrade=yes` en RouterBOARD antes) |
| **Cisco IOS / IOS-XE** | Imagen `.bin` (Bundle mode o Install mode `packages.conf`) | **Gold Star / MD (*Maintenance Deployment*)** | `1` (previa validación de `show boot` y `verify /md5`) |
| **Aruba / HP ProCurve** | Partición `Primary Image` (dejando la versión vieja sana en `Secondary Image`) | **Maintenance Release (YA/WC/KB)** | `1` (`boot system flash primary`) |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### Fase 1 Común (Obligatoria en todas las marcas): Tomar la "Foto Pre-Check"

Antes de tocar el firmware, ejecutá estos comandos y copiá su salida en tu bloc de notas del ticket para poder comparar al volver del reinicio:

```text
# En MikroTik (Foto Pre-Check):
/system resource print
/interface print where running
/ip route print count-only where active
/routing ospf neighbor print
/interface wireguard peers print

# En Cisco IOS (Foto Pre-Check):
show version
show interfaces status | include connected
show ip route summary
show ip ospf neighbor
show etherchannel summary
```

---

### A. MikroTik RouterOS v7 (El protocolo completo: `RouterOS` + `RouterBOOT`)

> **💡 Secreto profesional:** En MikroTik, el sistema operativo (`RouterOS`) y el firmware de arranque de la placa (`RouterBOOT`) son dos piezas separadas. Si activás `auto-upgrade=yes` en `/system routerboard settings`, cada vez que actualices RouterOS también se actualizará solo el RouterBOOT en el próximo arranque.

```text
# 1. Hacer backup completo y descargarlo FUERA del router (a tu PC)
/export show-sensitive file=pre-upgrade-v7
/system backup save name=pre-upgrade-v7

# 2. Verificar que haya al menos 20 MB libres en disco (Free HDD Space)
/system resource print
# (Si queda poco espacio, borrar backups o capturas viejas en /file print)

# 3. Asegurar canal 'stable' y buscar nueva versión
/system package update set channel=stable
/system package update check-for-updates

# 4. Descargar los paquetes primero (sin reiniciar todavía, para confirmar que bajaron bien)
/system package update download
# Esperar a que diga 'status: Downloaded, please reboot router to upgrade it'

# 5. Activar auto-upgrade del RouterBOOT y reiniciar en ventana aprobada
/system routerboard settings set auto-upgrade=yes
/system reboot

# 6. Al volver del reinicio (1 a 2 minutos), verificar que RouterOS y RouterBOOT coincidan:
/system resource print
/system routerboard print
# Si 'current-firmware' aún es menor que 'upgrade-firmware', ejecutar:
/system routerboard upgrade
/system reboot
```

### B. Cisco IOS / Catalyst (Validación de Hash + Variable `boot system`)

```cisco
! 1. Guardar la configuración actual y respaldarla por SCP
write memory
copy running-config scp://netops@10.1.99.10/sw-core-pre-upgrade.cfg

! 2. Verificar espacio libre en flash: (y borrar imágenes viejas que no estén en uso si falta lugar)
dir flash:

! 3. Copiar la nueva imagen IOS desde tu servidor SCP/TFTP a la flash del switch
copy scp://netops@10.1.99.10/c9200l-universalk9_ias.17.09.05.SPA.bin flash:

! 4. PASO CRÍTICO: Verificar el hash MD5 o SHA512 contra el publicado en cisco.com
!    (Si el archivo se corrompió al copiar y reiniciás sin verificar, el switch caerá en ROMMON!)
verify /md5 flash:c9200l-universalk9_ias.17.09.05.SPA.bin

! 5. Apuntar la variable de arranque a la imagen nueva (y dejar la imagen vieja como 2da opción de rescate!)
configure terminal
no boot system
boot system flash:c9200l-universalk9_ias.17.09.05.SPA.bin
boot system flash:c9200l-universalk9_ias.17.06.04.SPA.bin
end

! 6. Guardar y confirmar con 'show boot' que la variable quedó grabada antes de hacer reload
write memory
show boot
reload
```

### C. Switches Gestionables (Aruba / HP con Doble Partición `Primary` y `Secondary`)

Los switches empresariales Aruba tienen dos bancos de memoria flash (`Primary` y `Secondary`). La regla de oro es **copiar siempre la versión actual sana al banco `Secondary` antes de sobrescribir el banco `Primary`**:

```text
# 1. Ver qué versión hay en Primary y en Secondary
show flash

# 2. Copiar la imagen Primary actual (que sabemos que anda bien) hacia Secondary como salvavidas
copy flash flash secondary

# 3. Subir el firmware nuevo al banco Primary por SCP/TFTP
copy scp netops@10.1.99.10 WC_16_11_0015.swi flash primary

# 4. Verificar que ambos bancos tengan imágenes válidas y reiniciar desde Primary
show flash
write memory
boot system flash primary
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/system routerboard print`)

```text
[netops@RTR-BORDE] > /system routerboard print
       routerboard: yes
             model: RB5009UG+S+
     firmware-type: 70x0
  factory-firmware: 7.4.1
  current-firmware: 7.14.3
  upgrade-firmware: 7.16.1
```

### En Aruba (`show flash`)

```text
SW-PISO2# show flash
Image             Size (bytes) Date     Version
----------------- ------------ -------- --------------
Primary Image    : 30142511    10/15/26 WC.16.11.0015
Secondary Image  : 29884120    02/10/25 WC.16.11.0002

Boot ROM Version : WC.17.02.0006
Default Boot     : Primary
```

### Tabla de interpretación de salidas

| Campo / Salida | Fabricante | Qué significa realmente | Acción requerida |
|----------------|------------|-------------------------|------------------|
| **`current-firmware` != `upgrade-firmware`** | MikroTik (`routerboard print`) | Ya actualizaste el sistema operativo `RouterOS`, pero la placa sigue arrancando con el `RouterBOOT` viejo (`7.14.3` vs `7.16.1`) | Ejecutar `/system routerboard upgrade` y reiniciar cuando sea oportuno |
| **`BOOT path-list : flash:imagen.bin`** | Cisco (`show boot`) | Es el archivo exacto que el bootloader buscará al encender el switch | **Jamás borres de `flash:` el archivo que figura acá** sin haber actualizado antes `boot system` y hecho `write memory` |
| **`Primary Image` vs `Secondary Image`** | Aruba (`show flash`) | Dos sistemas operativos completos independientes alojados en el switch | Si el `Primary` nuevo tuviera un bug, volvés a la versión anterior en 1 minuto ejecutando `boot system flash secondary` |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: En un MikroTik con solo 16 MB de almacenamiento Flash (ej. `hEX`, `hAP ac2`), la actualización falla diciendo `not enough disk space`

1. **Causa raíz:** En equipos con flash chica de `16 MB`, el archivo de actualización `.npk` se descarga primero en la memoria **RAM (`/file`)**, pero al reiniciar necesita un margen mínimo en la flash para descomprimirse.
2. **Corrección paso a paso:**
   - Entrar a `/file print` y borrar cualquier archivo `.backup`, `.rsc` o `.pcap` viejo que esté ocupando la flash (descargarlos antes a tu PC).
   - No subir el paquete a la carpeta `flash/`; usar `/system package update download` que utiliza el disco RAM temporal.

### Síntoma 2: Después de actualizar un switch con PoE, el switch arranca en 2 minutos pero una vez arriba corta los puertos durante otros 3 minutos más

1. **Interpretación (¡No apagues el switch!):** Cuando una actualización de IOS o firmware incluye nuevo microcódigo para los **controladores internos PoE o CPLD de hardware**, el switch lo programa automáticamente durante el arranque.
2. **Regla vital:** **Jamás desenchufes de la corriente un switch mientras está en medio de un upgrade de firmware/microcódigo**, aunque tarde 8 a 12 minutos en volver.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Particionamiento Dual en MikroTik (`/partitions` en equipos con NAND grande como CCR/RB5009/CRS3xx):**
  - En routers MikroTik de gama media/alta podés dividir la memoria flash en **2 particiones independientes (`part0` y `part1`)** y clonar tu sistema funcionando con `/partitions copy-to` antes de actualizar. Si la nueva versión falla, elegís `/partitions activate part1` y al reiniciar estás exactamente en el sistema anterior con su versión y configuración intactas.
- **Rollback en Aruba y Cisco:**
  - En Aruba: `boot system flash secondary`.
  - En Cisco: cambiar `boot system flash:<imagen-anterior.bin>`, `write memory` y `reload`.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Borrar la imagen `.bin` vieja de `flash:` en un Cisco y reiniciar sin haber cambiado el comando `boot system`:** El switch se reinicia, busca el nombre del archivo viejo que acabás de borrar, no lo encuentra y queda muerto en la pantalla **`switch:` (ROMMON)** esperando que alguien vaya físicamente al rack con un cable de consola y un pendrive USB.
- **❌ Actualizar toda la red el mismo día (Core + Sucursales + APs a la vez):** Primero se actualiza **1 equipo piloto no crítico** (o una sucursal chica), se lo deja correr 48–72 horas validando estabilidad, y recién después se programa la ventana para el Core y el resto de las sedes.
- **❌ En MikroTik, saltar de RouterOS v6 directo a RouterOS v7 en un router remoto con BGP, OSPF o colas complejas sin probar la configuración en un laboratorio CHR:** Entre RouterOS v6 y v7 cambió por completo la sintaxis de `/routing ospf`, `/routing bgp`, `/routing filter` y `route-marking`. Antes de migrar de v6 a v7, levantá una máquina virtual gratuita **MikroTik CHR** en tu laptop, importá el `.rsc` y corregí cualquier bloque de routing que haya cambiado de sintaxis.

---

## 8. ✅ Buenas prácticas profesionales

- **Nunca actualizar un viernes ni en víspera de feriado:** Las ventanas de mantenimiento se programan de martes a jueves en horario de baja carga, con margen para monitorear el primer día hábil completo.
- **Comparar la "Foto Post-Check" contra la "Foto Pre-Check":** La ventana de mantenimiento no termina cuando el equipo responde al ping; termina cuando confirmaste que la cantidad de rutas activas, vecinos OSPF, sesiones BGP, túneles WireGuard y tramas en los puertos Trunk es **idéntica** a la foto que tomaste 15 minutos antes.

---

## 9. 🔗 Referencias internas

- [`network-backups-export-and-git-versioning`](network-backups-export-and-git-versioning.md) — Cómo generar y resguardar los backups obligatorios de la Fase 2 antes de actualizar
- [`serial-console-and-oob-access`](../01-fundamentals/serial-console-and-oob-access.md) — Cómo rescatar un equipo por consola serie si falla el arranque
- [`netops-day-to-day-maintenance-and-observability`](../../concepts/netops-day-to-day-maintenance-and-observability.md) — El modelo mental completo de las 4 fases de una ventana de mantenimiento
