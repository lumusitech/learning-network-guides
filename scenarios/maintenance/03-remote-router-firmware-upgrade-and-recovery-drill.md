⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Actualización de Firmware en un Router Remoto Crítico y Simulacro de Recuperación

**Dominio:** `maintenance`
**Nivel:** 🟡 Intermedio
**Capas OSI afectadas:** `Capas 1 a 7 (Plano de Gestión y Continuidad Operativa)`
**Equipos involucrados:** `MikroTik RouterOS v7 (RouterOS + RouterBOOT)`, `Cisco IOS-XE`

---

## 🎯 Problema

Se publica una actualización de seguridad importante en la rama **`stable`** de **MikroTik RouterOS v7** (o **Cisco IOS-XE**) y debés actualizar el router principal de una planta ubicada a 250 kilómetros de distancia. No hay otro ingeniero de redes en esa ciudad: si el router no vuelve a levantar después del comando `reboot` (por falta de espacio en flash, por un paquete corrupto o porque se rompe la sintaxis de una ruta), la planta queda incomunicada y tenés que viajar 3 horas en auto de urgencia.

```text
PROTOCOLO BLINDADO DE UPGRADE REMOTO (A 250 KM DE DISTANCIA):
==================================================================================================
[1. Pre-Check & Limpieza Flash] ---> [2. Backup Externo (.rsc + .backup) + Partición Clonada]
                                                      |
[4. Post-Check (Rutas == Pre-Check)] <--- [3. Upgrade RouterOS + RouterBOOT con OOB/Watchdog listo]
```

---

## ⚡ Quick command (Pre-Check de Elegibilidad antes de descargar nada)

```text
# MikroTik RouterOS v7: Verificar espacio libre en disco (Free HDD Space), salud de voltaje/temp y particiones
/system resource print
/system health print
/system routerboard print
/partitions print
/file print

# Cisco IOS: Verificar espacio libre en flash:, registro de arranque 0x2102 y variable BOOT
dir flash:
show version | include Configuration register
show boot
```

---

## ✅ Salida esperada vs Salida peligrosa (Cuándo NO reiniciar todavía!)

### Lo que debés auditar antes de ejecutar el reinicio

```text
# PELIGRO 1 EN MIKROTIK: Disco Flash casi lleno (< 15% o < 2 MB libres en equipos de 16 MB flash):
          free-hdd-space: 812.0KiB
         total-hdd-space: 16.0MiB
# -> ¡PROHIBIDO actualizar sin limpiar antes /file! Si el paquete .npk no entra al descomprimir, fallará!

# PELIGRO 2 EN CISCO: Registro en 0x2142 o variable BOOT apuntando a una imagen que borraste:
BOOT path-list      : flash:imagen-vieja-borrada.bin
Configuration register is 0x2142
# -> ¡PROHIBIDO ejecutar 'reload'! Si reiniciás así, el router caerá en ROMMON o arrancará en blanco!
```

---

## 🧠 Diagnóstico y Preparación del Salvavidas Remoto

Antes de actualizar un equipo a 250 km, preparás tres anillos de seguridad:

1. **Anillo 1 — Clonar la Partición Activa (`/partitions` en MikroTik / `Secondary Flash` en Aruba / Segunda línea `boot system` en Cisco):**
   - En routers MikroTik con NAND (`RB5009`, `CCR`, `CRS3xx`, `RB4011`), si tenés configuradas 2 particiones (`part0` y `part1`), clonás el sistema actual vivo a `part1` con **`/partitions copy-to`**. Si algo fallara en `part0`, el router puede caer de regreso a `part1` con la versión y configuración anteriores intactas.
2. **Anillo 2 — Contacto en sitio o Acceso Out-of-Band (4G / Servidor interior):**
   - Dejar una sesión SSH o AnyDesk/RustDesk abierta en un servidor o PC interna de esa planta que tenga salida secundaria (por ejemplo, un módem 4G de respaldo o Starlink), o tener conectada la consola serie del router al puerto USB de un switch interno accesible.
3. **Anillo 3 — Foto Pre-Check Exacta:**
   - Guardar en un archivo de texto local el conteo exacto de rutas activas, vecinos OSPF, sesiones BGP y peers WireGuard.

---

## 🛠️ Procedimiento paso a paso (Runbook de la Ventana de Mantenimiento)

### Paso 1 (T - 15 min): Capturar la "Foto Pre-Check" y Limpiar Espacio en Flash

```text
# En MikroTik RouterOS v7:
/system resource print
/ip route print count-only where active
/routing ospf neighbor print
/interface wireguard peers print
/file print
# Borrar backups o capturas .pcap viejas de hace meses para liberar espacio en flash:
# /file remove [find name~"viejo"]
```

### Paso 2 (T - 10 min): Generar Backups Nuevos, Descargarlos a tu Laptop y Clonar Partición

```text
# 1. Generar .rsc en texto plano y .backup binario:
/export show-sensitive file=2026-11-25-pre-upgrade
/system backup save name=2026-11-25-pre-upgrade password="PasswordBackupFuerte!2026"

# 2. ¡Descargar AMBOS archivos a tu laptop por SCP o WinBox ANTES de continuar!

# 3. (En equipos con soporte de particiones NAND): Clonar el sistema sano actual a la partición de respaldo:
/partitions copy-to [find name!=([/partitions get [find active] name])]
```

### Paso 3 (T = 0): Descargar Firmware `stable`, Configurar `auto-upgrade` del RouterBOOT y Reiniciar

```text
# En MikroTik RouterOS v7:
# 1. Asegurar canal 'stable' y activar auto-upgrade del bootloader RouterBOOT:
/system package update set channel=stable
/system routerboard settings set auto-upgrade=yes

# 2. Descargar primero el paquete SIN reiniciar (para verificar que la descarga e integridad SHA sean 100% exitosas):
/system package update download
# Esperar hasta leer: 'status: Downloaded, please reboot router to upgrade it'

# 3. Ejecutar el reinicio de actualización (tarda entre 60 y 150 segundos en volver):
/system reboot
```

```cisco
! Equivalente en Cisco IOS / Catalyst:
! 1. Verificar hash MD5 de la nueva imagen ya copiada en flash:
verify /md5 flash:c9200l-universalk9_ias.17.09.05.SPA.bin

! 2. Configurar orden de arranque: 1ro imagen nueva, 2do imagen vieja sana como fallback automático!
configure terminal
no boot system
boot system flash:c9200l-universalk9_ias.17.09.05.SPA.bin
boot system flash:c9200l-universalk9_ias.17.06.04.SPA.bin
config-register 0x2102
end
write memory
show boot
reload
```

### Paso 4 (T + 3 min): Verificación de `RouterOS` + `RouterBOOT` y Comparación "Foto Post-Check"

```text
# Al reconectar por SSH tras el reinicio:
# 1. Confirmar que tanto RouterOS como RouterBOOT estén en la versión nueva:
/system resource print
/system routerboard print
# (Si 'current-firmware' aún difiere de 'upgrade-firmware', ejecutar '/system routerboard upgrade' y '/system reboot')

# 2. Comparar la Foto Post-Check contra la Foto Pre-Check del Paso 1:
/ip route print count-only where active
/routing ospf neighbor print
/interface wireguard peers print
/log print where topics~"error|critical|warning"
```

---

## 🧯 Mitigación y Rollback (Simulacro de Recuperación)

### ¿Cómo volver a la versión anterior (*Downgrade*) en MikroTik si la versión nueva presenta un bug con un túnel o SFP?

1. **Opción A (Si clonaste la partición en el Paso 2.3 — Toma 60 segundos):**

   ```text
   /partitions activate part1
   /system reboot
   ```

   El router arranca desde la partición `part1` con la versión anterior exacta y su configuración intacta.
2. **Opción B (En cualquier MikroTik subiendo el paquete `.npk` de la versión anterior):**
   - Subís por WinBox o SCP el archivo `routeros-7.xx.x-arm64.npk` de la versión anterior a la raíz de `/file`.
   - Ejecutás: **`/system package downgrade`** y confirmás con `y`. El router instala la versión anterior y reinicia.

---

## ✅ Verificación de cierre de ventana

- [ ] `version` en `/system resource print` y `current-firmware` en `/system routerboard print` coinciden en la nueva versión `stable`.
- [ ] El conteo de rutas activas, vecinos OSPF (`Full`) y túneles WireGuard/IPsec es **idéntico** al de la Foto Pre-Check.
- [ ] Se genera y descarga a Git el nuevo backup post-upgrade (`2026-11-25-post-upgrade.rsc`).

---

## 🔗 Referencias

- [`firmware-upgrades-and-maintenance-windows`](../../guides/08-operations/firmware-upgrades-and-maintenance-windows.md) — Guía completa multi-vendor de actualizaciones de firmware
- [`network-backups-export-and-git-versioning`](../../guides/08-operations/network-backups-export-and-git-versioning.md) — Automatización de backups `.rsc` y `archive` en Git
- [`serial-console-and-oob-access`](../../guides/01-fundamentals/serial-console-and-oob-access.md) — Cómo dejar armado un acceso de consola Out-of-Band desde otro equipo del rack
