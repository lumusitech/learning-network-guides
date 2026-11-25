⬅️ [Volver a Guías](../README.md)

# Backups de Red, Exportación en Texto (`.rsc`) y Versionado en Git — Guía práctica multi-vendor

**Dominio:** `08-operations`
**Nivel:** 🟢 Básico
**Estándares:** `SSH/SCP (RFC 4253)`, `Git / Infrastructure as Code`, `Cisco Archive`, `RouterOS Export`
**Concepto base:** [`netops-day-to-day-maintenance-and-observability`](../../concepts/netops-day-to-day-maintenance-and-observability.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Generar ambos backups (Texto plano legible en Git + Binario cifrado)
/export show-sensitive file=rtr-borde-texto
/system backup save name=rtr-borde-binario password="PasswordDeBackupFuerte!2026"
/file print where name~"rtr-borde"

# Cisco IOS: Verificar estado del archivo automático de configuraciones y diferencias (diff)
show archive
show archive config differences nvram:startup-config system:running-config

# Linux (Servidor de Gestión NetOps): Descargar configuración en vivo de un router a Git por SSH
ssh netops@10.1.99.1 '/export show-sensitive' > configs/rtr-borde.rsc
git diff configs/rtr-borde.rsc
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

En redes hay dos tipos de administradores: los que tienen backups automatizados fuera de sus equipos y los que todavía no sufrieron una tormenta eléctrica o un fallo de memoria flash.

Pero no cualquier archivo sirve: en equipos como **MikroTik RouterOS**, existen **dos tipos de backup completamente distintos**:

1. **El Script en Texto Plano (`/export show-sensitive` → `.rsc`):** Es un archivo de texto ASCII con todos los comandos CLI que reconstruyen tu configuración. **Se puede guardar en Git, permite ver con `git diff` qué línea cambió ayer y se puede adaptar en 5 minutos a un modelo de router nuevo diferente** si el viejo se quemó.
2. **El Backup Binario (`/system backup save` → `.backup`):** Es una imagen binaria cerrada que incluye usuarios, certificados y direcciones MAC, diseñada **únicamente para restaurarse en el mismo equipo exacto**.

En esta guía implementamos el sistema profesional donde un nodo Linux en la VLAN de Management recolecta automáticamente todas las noches las configuraciones en texto plano de tus routers y switches (**Cisco, MikroTik y Aruba**) y las versiona en un repositorio **Git** local.

> **🧠 Recordatorio del modelo mental:** Pensá en el archivo `.backup` binario como **un molde de yeso** que solo sirve si comprás idéntico modelo de hardware, y en el archivo `.rsc` / `running-config` en Git como **los planos de arquitectura firmados** con los que podés auditar cambios línea por línea y levantar cualquier equipo de reemplazo en minutos.

---

## 2. 🗺️ Topología de referencia

Un servidor Linux de gestión (`10.1.99.10`) se conecta por SSH con clave pública (en modo solo lectura o backup) hacia todos los equipos de la `VLAN 99 Management`:

```text
+---------------------------------------------------+
| Servidor NetOps / Oxidized / Cron Git (Linux)     |
| IP: 10.1.99.10  -->  /srv/netops-configs/.git     |
+---------------------------------------------------+
         |                 |                 |
         | SSH (Clave)     | SSH (Clave)     | SSH (Clave)
         v                 v                 v
+-----------------+ +-----------------+ +-----------------+
|   RTR-BORDE     | |    SW-CORE      | |    SW-PISO2     |
| (MikroTik v7)   | | (Cisco IOS)     | | (Aruba 2930F)   |
| 10.1.99.1       | | 10.1.99.2       | | 10.1.99.12      |
| -> rtr.rsc      | | -> sw-core.cfg  | | -> sw-piso2.cfg |
+-----------------+ +-----------------+ +-----------------+
```

| Equipo | IP de Gestión | Comando que devuelve el texto plano | Archivo versionado en Git |
|--------|---------------|-------------------------------------|---------------------------|
| **RTR-BORDE (MikroTik)** | `10.1.99.1` | `/export show-sensitive` | `configs/rtr-borde.rsc` |
| **SW-CORE (Cisco IOS)** | `10.1.99.2` | `show running-config` | `configs/sw-core.cfg` |
| **SW-PISO2 (Aruba)** | `10.1.99.12` | `show running-config` | `configs/sw-piso2.cfg` |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. MikroTik RouterOS (v7+)

> **⚠️ Nota crítica de RouterOS v7:** En RouterOS v6, `/export` incluía las claves WiFi, secretos IPsec y WireGuard por defecto. En **RouterOS v7**, por seguridad, `/export` oculta los secretos a menos que agregues explícitamente el parámetro **`show-sensitive`** (que requiere que el usuario tenga permisos `sensitive`).

```text
# 1. Generar manualmente antes de cualquier cambio el par de archivos (Texto + Binario)
/export show-sensitive file=pre-cambio-texto
/system backup save name=pre-cambio-binario password="PasswordDeBackupFuerte!2026"

# 2. Verificar que ambos archivos se hayan escrito en el disco flash y no pesen 0 bytes
/file print where name~"pre-cambio"

# 3. Crear usuario dedicado para que el servidor Linux descargue el backup todas las noches por SSH
/user group add name=backup-git policy=ssh,read,sensitive,test,!local,!telnet,!ftp,!reboot,!write,!policy,!winbox,!password,!web,!sniff,!api,!romon
/user add name=gitbackup group=backup-git password="PasswordLargoBackup!2026"
/user ssh-keys import public-key-file=gitbackup_ed25519.pub user=gitbackup
```

### B. Cisco IOS / Catalyst (Activar `archive` con historial de 14 versiones y `config-logger`)

Cisco IOS incluye una joya nativa llamada **`archive`**: guarda automáticamente una copia versionada cada vez que alguien ejecuta `write memory` y registra en el Syslog exactamente qué comando tipeó cada administrador:

```cisco
! 1. Crear carpeta en la memoria flash local para guardar las últimas 14 versiones
mkdir flash:archive

! 2. Configurar Archive automático al guardar (write memory) y auditoría de comandos en Syslog
configure terminal
archive
 log config
  logging enable
  logging size 500
  hidekeys
  notify syslog contenttype plaintext
 path flash:archive/sw-core-cfg
 write-memory
 maximum 14
exit

end
write memory
```

### C. Servidor Linux NetOps (Script automatizado de Backup a Git por SSH sin dependencias pesadas)

Si aún no desplegaste **Oxidized**, este script POSIX (`backup-red-git.sh`) descarga por SSH la configuración de tus equipos, elimina las líneas de fecha/hora que cambian solas (para no generar commits falsos) y hace un `git commit` automático solo cuando alguien modificó algo en la red:

```bash
#!/bin/sh
set -eu

REPO_DIR="/srv/netops-configs"
mkdir -p "$REPO_DIR/configs"
cd "$REPO_DIR"

# Inicializar repositorio Git local si no existe
if [ ! -d ".git" ]; then
  git init -b main
  git config user.name "NetOps Backup Bot"
  git config user.email "netops@empresa.local"
fi

# 1. Descargar MikroTik (.rsc) quitando la primera línea '# nov/25/2026 03:00:01 by RouterOS...'
ssh -i /root/.ssh/gitbackup_ed25519 -o BatchMode=yes gitbackup@10.1.99.1 '/export show-sensitive' \
  | tr -d '\r' | sed '1{/^# .* by RouterOS/d;}' > "$REPO_DIR/configs/rtr-borde.rsc"

# 2. Descargar Cisco IOS (.cfg) quitando las líneas dinámicas 'Current configuration : ...' y 'Last configuration change...'
ssh -i /root/.ssh/gitbackup_ed25519 -o BatchMode=yes gitbackup@10.1.99.2 'show running-config' \
  | tr -d '\r' | grep -v -E '^(Current configuration|! Last configuration change|! NVRAM config last updated)' \
  > "$REPO_DIR/configs/sw-core.cfg"

# 3. Si hubo cambios reales respecto a ayer, crear commit con timestamp
git add configs/
if ! git diff --cached --quiet; then
  git commit -m "chore(netops): cambio detectado en configuracion de red ($(date +%Y-%m-%d_%H:%M))"
fi
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En Cisco IOS (`show archive` y `show archive config differences`)

```text
SW-CORE# show archive
The maximum archive configurations allowed is 14.
The next archive file will be named flash:archive/sw-core-cfg-3
 Archive #  Name
   1        flash:archive/sw-core-cfg-1
   2        flash:archive/sw-core-cfg-2 <- Most Recent

SW-CORE# show archive config differences nvram:startup-config system:running-config
!Contextual Config Diffs:
+interface GigabitEthernet1/0/10
 +switchport access vlan 20
-interface GigabitEthernet1/0/10
 -switchport access vlan 10
```

### En Servidor Linux (`git log -p -n 1`)

```text
commit 8a4f2c1 (HEAD -> main)
Date:   Wed Nov 25 03:00:04 2026 -0300
    chore(netops): cambio detectado en configuracion de red (2026-11-25_03:00)

diff --git a/configs/rtr-borde.rsc b/configs/rtr-borde.rsc
--- a/configs/rtr-borde.rsc
+++ b/configs/rtr-borde.rsc
@@ -142,3 +142,4 @@
 /ip firewall filter
+add action=accept chain=forward dst-address=10.1.40.10 dst-port=443 protocol=tcp comment="Ticket #402"
```

### Tabla de interpretación de salidas

| Indicador en la salida | Herramienta | Qué significa realmente | Acción operativa |
|------------------------|-------------|-------------------------|------------------|
| **`+` y `-` en `show archive config differences`** | Cisco IOS | Muestra qué líneas existen hoy en la memoria RAM (`running-config`) que **aún no fueron guardadas** en `startup-config` | Si un cambio temporal no está guardado y se corta la luz, se perderá; si fue una prueba fallida, podés revertir sin reiniciar con `configure replace` |
| **`diff --git` con líneas `+add ...`** | Git en Servidor NetOps | Un administrador agregó o modificó una regla o VLAN en las últimas 24 horas | Permite correlacionar inmediatamente *"desde ayer no funciona X"* con la línea exacta que cambió ayer |
| **Tamaño `0 B` en `/file print` de MikroTik** | MikroTik RouterOS | El archivo `.rsc` o `.backup` falló al escribirse porque el disco flash del router está al **100% lleno** | Borrar archivos `.pcap` o `.npk` viejos de `/file` antes de volver a exportar |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Se quemó un router MikroTik y tenés que cargar el archivo `.rsc` en un equipo nuevo, pero a mitad de la importación falla con `already have such interface`

1. **Causa raíz:** El router nuevo viene con la **configuración por defecto de fábrica (*Default Configuration*)** ya cargada (un bridge `bridge`, IP `192.168.88.1`, DHCP, etc.) que choca con los comandos `add` de tu script `.rsc`.
2. **Corrección profesional:**
   - Para importar un `.rsc` completo desde cero en un equipo nuevo, **primero debés vaciar la configuración de fábrica** y pedirle que ejecute tu script apenas arranque en blanco:
   - Subí `rtr-borde.rsc` a `/file` y ejecutá: `/system reset-configuration no-defaults=yes keep-users=no run-after-reset=rtr-borde.rsc`.
   - *(O mejor aún: conectate por WinBox MAC al equipo ya reseteado con `no-defaults=yes` y pegá los bloques del `.rsc` en la terminal por secciones para ver si alguna interfaz física cambió de nombre).*

### Síntoma 2: En Cisco hiciste varios cambios en vivo, algo salió mal y querés volver a la configuración guardada sin reiniciar el switch (que tarda 6 minutos)

1. **Verificación rápida:** `show archive config differences system:running-config nvram:startup-config`
2. **Corrección sin reinicio (*Atomic Rollback*):**
   - En lugar de reiniciar el switch con `reload`, ejecutá: **`configure replace nvram:startup-config force`**.
   - Cisco IOS calcula las diferencias exactas y revierte en memoria RAM solo los comandos que cambiaste en menos de 2 segundos, sin apagar los puertos ni cortar a toda la empresa.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Rollback con temporizador nativo en Cisco (`configure terminal revert timer 10`):**
  - Mucho mejor que `reload in 10` (que reinicia todo el switch si te quedás afuera): con `archive` configurado, podés entrar con **`configure terminal revert timer 10`**.
  - Si tu cambio te corta el SSH, a los 10 minutos Cisco ejecuta automáticamente `configure replace` hacia la versión anterior **sin reiniciar el switch**. Si todo salió bien, confirmás con **`configure confirm`**.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Ejecutar `/export file=backup` en RouterOS v7 sin `show-sensitive`:** Cuando un mes después quieras restaurar ese `.rsc`, descubrirás con horror que **faltan todas las claves Pre-Shared Key de tus túneles IPsec, las claves privadas de tus 20 túneles WireGuard y las contraseñas de tus redes WiFi**. Usá siempre `/export show-sensitive` y guardá el archivo en un repositorio Git privado y seguro.
- **❌ Restaurar un `.backup` binario del Router A en un Router B sin limpiar las MACs:** El archivo `.backup` binario guarda la dirección `admin-mac` del bridge y de las interfaces Ethernet del equipo viejo. Si algún día restaurás un `.backup` en otro equipo, entrá inmediatamente a `/interface ethernet reset-mac-address [find]` y revisá el `admin-mac` del bridge.
- **❌ Subir el repositorio Git de configuraciones con `show-sensitive` a un repositorio público de GitHub:** Los repositorios con configuraciones de red deben vivir en un servidor **Gitea / GitLab interno** en tu propia infraestructura o en un repositorio privado con cifrado (`git-crypt` / `sops`).

---

## 8. ✅ Buenas prácticas profesionales

- **Regla 3-2-1 aplicada a configuraciones de red:** La configuración debe estar en la memoria no volátil del equipo (`startup-config`), en el repositorio Git del servidor NetOps local y en una copia cifrada fuera del edificio.
- **Hacer un backup manual antes y después de cada ventana de mantenimiento:** Nombrarlos con fecha y número de ticket (`2026-11-25-pre-ticket402.rsc` y `2026-11-25-post-ticket402.rsc`).

---

## 9. 🔗 Referencias internas

- [`netops-day-to-day-maintenance-and-observability`](../../concepts/netops-day-to-day-maintenance-and-observability.md) — Concepto completo de operación diaria y diferencia arquitectónica entre `.rsc` y `.backup`
- [`firmware-upgrades-and-maintenance-windows`](firmware-upgrades-and-maintenance-windows.md) — Cómo usar estos backups durante una ventana de actualización de firmware
- [`multivendor-cli-rosetta-stone`](../../reference/multivendor-cli-rosetta-stone.md) — Comandos de exportación y guardado en todas las marcas
