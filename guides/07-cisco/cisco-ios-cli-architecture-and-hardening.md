⬅️ [Volver a Guías](../README.md)

# Cisco IOS y Catalyst: Arquitectura de CLI, Hardening y Operación Pro — Guía práctica

**Dominio:** `07-cisco`
**Nivel:** 🟢 Básico
**Estándares:** `Cisco IOS / IOS-XE`, `CIS Cisco IOS Benchmark`, `CEF (Cisco Express Forwarding)`
**Concepto base:** [`how-to-think-like-network-engineer`](../../concepts/how-to-think-like-network-engineer.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Los 6 comandos de auditoría inicial al entrar a cualquier switch o router Cisco
show version
show ip interface brief
show interfaces status
show running-config
show logging | last 30
show processes cpu sorted | exclude 0.00
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

**Cisco IOS / IOS-XE** es la lengua franca de la industria de redes: no solo impulsa a millones de switches Catalyst y routers ISR/ASR en el mundo, sino que su sintaxis y arquitectura de modos fue adoptada casi al calco por **Aruba, Dell, Extreme, Huawei, Fortinet (en parte) y FRRouting en Linux**.

Esta guía te enseña a moverte como un ingeniero senior dentro de Cisco IOS:

1. **La jerarquía de Modos de Consola (`User EXEC >` → `Privileged EXEC #` → `Global Config (config)#` → `Sub-modos`)** y los filtros de tubería (`| include`, `| section`, `| begin`) para no leer 500 líneas a mano.
2. **La diferencia vital entre `running-config` (RAM volátil) y `startup-config` (NVRAM persistente)** y cómo usar el rollback transaccional (`configure terminal revert timer`).
3. **La Plantilla Maestra de Hardening y Operación** para dejar cualquier switch o router Cisco nuevo listo para producción (eliminando el odioso bloqueo de 30 segundos por DNS cuando tipeás mal un comando, activando recuperación automática de puertos `err-disabled`, sincronizando NTP/Syslog y blindando SSHv2).

> **🧠 Recordatorio del modelo mental:** Pensá en la memoria de un equipo Cisco como **escribir un documento en Word sin autoguardado**: todo comando que ejecutás en `(config)#` se aplica en vivo en el acto sobre la memoria RAM (**`running-config`**), pero si a los 6 meses se corta la luz del edificio y vos nunca apretaste el botón Guardar (**`write memory` / `copy running-config startup-config`**), cuando el switch vuelva a encenderse cargará el archivo viejo que estaba en el disco (**`startup-config`**), borrando medio año de trabajo.

---

## 2. 🗺️ Topología de referencia (Arquitectura de Modos y Memorias en Cisco IOS)

```text
JERARQUÍA DE MODOS DE CLI EN CISCO IOS:
====================================================================================================
[1. User EXEC]               [2. Privileged EXEC]          [3. Global Config]         [4. Sub-Modos]
SW-CORE>  ----(enable)---->  SW-CORE#  ---(conf t)--->  SW-CORE(config)#  ----->  SW-CORE(config-if)#
(Solo consultas básicas)     (Todos los 'show', 'ping',    (Cambios globales)    SW-CORE(config-vlan)#
                              'write memory', 'reload',                          SW-CORE(config-router)#
                              'clear', 'debug')                                  SW-CORE(config-line)#
                             <----------(Ctrl+Z o 'end' desde cualquier nivel)----------'

ARQUITECTURA DE MEMORIAS EN UN EQUIPO CISCO:
====================================================================================================
+-------------------------+   Al encender carga    +-------------------------+
|  NVRAM (No Volátil)     | ---------------------> |  RAM (Volátil - Activa) |
|  'startup-config'       |                        |  'running-config'       |
|  (Sobrevive a cortes!)  | <--------------------- |  (Se borra al apagar!)  |
+-------------------------+   'write memory' o     +-------------------------+
                              'copy run start'
+-------------------------+
|  FLASH: (Disco Interno) | --> Guarda el sistema operativo (.bin), backups Archive y VLANs (vlan.dat)
+-------------------------+
```

| Atajo de Teclado / Filtro en Cisco CLI | Qué hace exactamente (te ahorra horas de trabajo) |
|----------------------------------------|---------------------------------------------------|
| **`do <comando show>`** | Te permite ejecutar cualquier comando `show`, `ping` o `write memory` **sin tener que salir del modo `(config-if)#`** (ej. `do show interfaces trunk`) |
| **`Ctrl + Z` (o `end`)** | Sale instantáneamente desde cualquier sub-modo profundo directo a `SW-CORE#` |
| **`Ctrl + A` / `Ctrl + E`** | Salta el cursor al **principio (`Ctrl+A`)** o al **final (`Ctrl+E`)** de la línea que estás escribiendo |
| **`show run \| section interface Gi1/0/1`** | Muestra **únicamente el bloque completo** de esa interfaz o protocolo (ej. `show run \| section router ospf`) |
| **`show interfaces status \| include connected`** | Filtra tipo `grep`: muestra solo las líneas que contengan la palabra (soporta `\| include`, `\| exclude`, `\| begin`) |
| **`interface range Gi1/0/1 - 24`** | Aplica los comandos siguientes a los **24 puertos al mismo tiempo** en una sola operación |

---

## 3. 🛠️ Plantilla Maestra de Inicialización y Hardening en Cisco IOS / Catalyst

```cisco
! =====================================================================
! 1. IDENTIDAD, CALIDAD DE VIDA EN CONSOLA Y DESACTIVAR BÚSQUEDA DNS EN ERRORES DE TIPEO
! =====================================================================
configure terminal
hostname SW-CORE-SEDE1
ip domain-name empresa.local

! ¡CRÍTICO! Evita que si tipeás mal un comando, el switch se congele 30 segundos
! buscando ese comando como un host por broadcast DNS (255.255.255.255):
no ip domain-lookup

! Marcas de tiempo exactas con fecha, milisegundos y zona horaria en todos los logs y 'show':
service timestamps debug datetime msec localtime show-timezone
service timestamps log datetime msec localtime show-timezone
clock timezone ART -3
logging buffered 65536 informational

! =====================================================================
! 2. CUENTAS, CONTRASEÑAS CON HASH SCRYPT (TYPE 9) Y DESACTIVAR SERVICIOS PELIGROSOS
! =====================================================================
enable algorithm-type scrypt secret CambiarEnableSecretFuerte!2026
username netops privilege 15 algorithm-type scrypt secret CambiarPasswordFuerte!2026
service password-encryption

! Desactivar servicios legacy inseguros de Cisco (HTTP, Pad, Finger, Small servers, Config remota):
no service pad
no service config
no ip http server
no ip http secure-server
no ip finger
no ip bootp server
no ip source-route
service tcp-keepalives-in
service tcp-keepalives-out

! =====================================================================
! 3. CONFIGURAR SSHv2 Y PROTEGER CONSOLA / TERMINALES VTY
! =====================================================================
crypto key generate rsa modulus 2048
ip ssh version 2
ip ssh time-out 60
ip ssh authentication-retries 3

ip access-list standard ACL-VTY-MGMT
 permit 10.1.20.0 0.0.0.255
 permit 10.1.99.0 0.0.0.255
 deny   any log
exit

line console 0
 logging synchronous
 exec-timeout 10 0
 login local
exit

line vty 0 15
 access-class ACL-VTY-MGMT in
 transport input ssh
 logging synchronous
 exec-timeout 10 0
 login local
exit

! =====================================================================
! 4. RECUPERACIÓN AUTOMÁTICA DE PUERTOS BLOQUEADOS (ERR-DISABLED RECOVERY)
! =====================================================================
! Si una boca de usuario se bloquea por BPDU Guard, Port-Security o Storm-Control,
! que el switch intente rehabilitarla automáticamente a los 5 minutos (300s):
errdisable recovery cause bpduguard
errdisable recovery cause psecure-violation
errdisable recovery cause storm-control
errdisable recovery cause loopback
errdisable recovery cause udld
errdisable recovery interval 300

! =====================================================================
! 5. SPANNING TREE RÁPIDO (RAPID-PVST+), LLDP UNIVERSAL Y ARCHIVE DE BACKUPS
! =====================================================================
spanning-tree mode rapid-pvst
spanning-tree extend system-id
spanning-tree portfast bpduguard default
lldp run

! =====================================================================
! 6. BANNER LEGAL Y GUARDADO EN MEMORIA NVRAM
! =====================================================================
banner login ^C
======================================================================
 ACCESO RESTRINGIDO - INFRAESTRUCTURA DE RED CORPORATIVA
 Toda sesion e intento de acceso es registrado en el servidor Syslog.
======================================================================
^C

end
write memory
```

---

## 4. 🔑 Salida clave e interpretación de flags

### Verificación de puertos y estados (`show interfaces status`)

```text
SW-CORE-SEDE1# show interfaces status
Port      Name               Status       Vlan       Duplex  Speed Type
Gi1/0/1   UPLINK_RTR_BORDE   connected    trunk      a-full  a-1000 10/100/1000BaseTX
Gi1/0/2   PC_CONTABILIDAD    connected    10         a-full  a-1000 10/100/1000BaseTX
Gi1/0/3   CAMARA_ACCESO      connected    100        a-full   a-100 10/100/1000BaseTX
Gi1/0/4   BOCA_CON_BUCLE     err-disabled 10           auto    auto 10/100/1000BaseTX
Gi1/0/5   PUERTO_LIBRE       disabled     999          auto    auto 10/100/1000BaseTX
```

### Verificación de por qué un puerto cayó en `err-disabled` (`show interfaces status err-disabled`)

```text
SW-CORE-SEDE1# show interfaces status err-disabled
Port      Name               Status       Reason               Err-disabled Vlans
Gi1/0/4   BOCA_CON_BUCLE     err-disabled bpduguard
```

### Tabla de interpretación de columnas y estados en `show interfaces status`

| Estado / Prefijo | Qué significa realmente | Diagnóstico inmediato |
|------------------|-------------------------|-----------------------|
| **`connected`** | Enlace físico activo (`Up / Up`) y pasando tráfico | Estado normal de operación |
| **`notconnect`** | El puerto está encendido por configuración (`no shutdown`), pero **no hay cable enchufado** o el equipo del otro lado está apagado | Si el cable está enchufado y dice `notconnect`, revisar cable o cruce de fibra `TX/RX` |
| **`disabled`** | Un administrador apagó el puerto deliberadamente con el comando **`shutdown`** | Para encenderlo: `interface Gi1/0/5` → `no shutdown` |
| **`err-disabled`** | 🚨 **El switch apagó el puerto automáticamente por una violación de seguridad o falla física** | Ejecutar **`show interfaces status err-disabled`** para ver la columna `Reason` (`bpduguard`, `psecure-violation`, `link-flap`, `inline-power`) |
| **`a-full` / `a-1000`** vs `full` / `1000` | El prefijo **`a-`** significa que la velocidad y el duplex fueron acordados por **Auto-Negotiation** | ✅ Siempre queremos ver **`a-full`** y **`a-1000`**. Si dice `full` sin la `a-`, alguien lo forzó a mano (riesgo de *Duplex Mismatch*!) |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: En un switch Cisco la CPU está al 90% (`show processes cpu sorted`) y el proceso que más consume se llama `IP Input` o `Spanning Tree`

1. **Verificación rápida:** `show processes cpu sorted | head -10`
2. **Interpretación de la salida `CPU utilization for five seconds: 92%/80%`:**
   - El primer número (`92%`) es el uso total de CPU, y el segundo número después de la barra (**`80%`**) es cuánto de ese porcentaje se gasta en **Interrupciones de Red (paquetes subiendo del cable a la CPU)**.
   - Si el número después de la barra es alto (`80%`) o el proceso es `Spanning Tree` / `ARP Input`, **no es un bug de software del switch: está entrando una Tormenta de Broadcast / bucle de Capa 2 por uno de los puertos**.
3. **Acción:** Ejecutar `show interfaces counters rate` para ver qué puerto tiene la tasa de paquetes por segundo (`pps`) descontrolada y apagarlo con `shutdown`.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Cómo usar el salvavidas antes de un cambio peligroso en un equipo Cisco remoto:**
  - **Opción 1 (Si configuraste `archive` como en la guía de backups):**
    `configure terminal revert timer 5` → Hacés tu cambio → Si seguís adentro, confirmás con **`configure confirm`**. (Si perdés el SSH, a los 5 minutos revierte solo en RAM sin reiniciar el switch!).
  - **Opción 2 (En cualquier Cisco IOS sin archive):**
    Antes de entrar a `conf t`, ejecutás **`reload in 10`** (y confirmás con `Enter`). Hacés tus cambios. Si todo anda bien y seguís con acceso SSH, cancelás la cuenta regresiva con **`reload cancel`** y recién ahí guardás con **`write memory`**.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Ejecutar `write memory` ANTES de hacer `reload in 10` y probar el cambio:** El truco de `reload in 10` funciona porque tus cambios nuevos viven solo en la memoria RAM (`running-config`), así que cuando el router se reinicia a los 10 minutos, vuelve a cargar la `startup-config` vieja y sana. ¡Si hiciste `write memory` después de romper la configuración, sobrescribiste la `startup-config` con la configuración rota y el reinicio no te salvará!
- **❌ Usar `debug all` o `debug ip packet` en un router en producción:** En Cisco IOS, el comando `debug` imprime cada paquete en la consola usando la CPU principal con prioridad máxima. Ejecutar `debug ip packet` (sin una ACL que filtre 1 sola IP) en un router con tráfico real **clava la CPU al 100% y cuelga el equipo en el acto**. Para apagar todos los debugs de emergencia, el comando corto es **`u all`** (`undebug all`).

---

## 8. ✅ Buenas prácticas profesionales

- **Al borrar un switch Cisco para reutilizarlo en otro lado, recordar que las VLANs NO viven en `startup-config`, sino en `flash:vlan.dat`:** Si ejecutás solo `write erase` (`erase startup-config`) y reiniciás el switch, **todas las VLANs viejas siguen existiendo** porque Cisco las guarda en un archivo aparte llamado `vlan.dat`. Para dejar un switch Cisco 100% de fábrica hay que borrar ambos: **`write erase`** + **`delete flash:vlan.dat`** + **`reload`**.

---

## 9. 🔗 Referencias internas

- [`cisco-rommon-password-recovery-and-ios-upgrade`](cisco-rommon-password-recovery-and-ios-upgrade.md) — El paso siguiente: qué hacer cuando heredás un Cisco cuya contraseña nadie conoce o que no arranca (ROMMON)
- [`ssh-hardening-and-management-plane`](../01-fundamentals/ssh-hardening-and-management-plane.md) — Comparación del hardening de Cisco contra MikroTik, Aruba y Linux
- [`multivendor-cli-rosetta-stone`](../../reference/multivendor-cli-rosetta-stone.md) — Traducción de todos los comandos `show` de Cisco hacia otras marcas
