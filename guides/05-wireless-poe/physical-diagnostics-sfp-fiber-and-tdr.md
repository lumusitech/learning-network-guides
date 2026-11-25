⬅️ [Volver a Guías](../README.md)

# Diagnóstico de Capa Física desde CLI: Reflectometría de Cable (TDR), Óptica SFP (`dBm`) y Errores CRC — Guía práctica

**Dominio:** `05-wireless-poe`
**Nivel:** 🟡 Intermedio
**Estándares:** `TDR (Time Domain Reflectometry)`, `SFF-8472 (DDM / DOM)`, `IEEE 802.3 Ethernet Counters`
**Concepto base:** [`physical-layer-cables-fiber-poe`](../../concepts/physical-layer-cables-fiber-poe.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Medir cable UTP por TDR (a cuántos metros está el corte!), leer SFP en dBm y ver errores CRC
test cable-diagnostics tdr interface Gi1/0/2
show cable-diagnostics tdr interface Gi1/0/2
show interfaces Gi1/0/25 transceiver detail
show interfaces counters errors

# MikroTik RouterOS v7: Test de cable TDR por par (distancia al corte en metros) y monitor óptico SFP
/interface ethernet cable-test ether2 once
/interface ethernet monitor sfp-sfpplus1 once
/interface ethernet print stats where name=ether2

# Aruba / HP ProCurve: Diagnóstico de cable, lectura óptica DDM y errores de puerto
test cable-diagnostics 2
show cable-diagnostics 2
show interfaces transceiver 25 detail

# Linux: Test TDR del PHY de la placa de red, lectura óptica SFP y contadores físicos
sudo ethtool --cable-test eth0
sudo ethtool -m eth0
sudo ethtool -S eth0 | grep -iE "err|crc|drop|coll"
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

La mayoría de los técnicos no sabe que **los switches gestionables modernos (Cisco, MikroTik, Aruba) y muchas placas de servidor Linux traen integrado adentro de su chip físico un analizador de cable por reflectometría (`TDR`) y un medidor óptico láser (`DDM / DOM`)**.

Sin desconectar el cable y estando sentado a 500 kilómetros por SSH, podés hacer tres diagnósticos físicos quirúrgicos:

1. **Test de Cable TDR (*Time Domain Reflectometry*):** El switch envía un pulso eléctrico por cada uno de los 4 pares del cable UTP y mide el eco que rebota si un hilo está cortado (`open`) o en cortocircuito (`short`), **diciéndote exactamente a cuántos metros de distancia del switch está roto el cable**:
   - Si te dice **`open at 0m – 2m`**: es el patchcord corto dentro del propio rack o la ficha en el patch panel.
   - Si te dice **`open at 48m`** (en una tirada de 50 metros): el cable se soltó o mordieron la ficha en la roseta de pared del escritorio del usuario.
2. **Diagnóstico Óptico Digital (`DDM / DOM`) en Fibra SFP/SFP+:** Lee en vivo la temperatura del láser, los miliamperes de bias, la potencia transmitida (`TX Power dBm`) y **la potencia de luz recibida (`RX Power dBm`)** con una precisión de décimas de decibel.
3. **Auditoría de Contadores de Errores de Capa 1/2 (`FCS/CRC`, `Runts`, `Giants`, `Late Collisions`):** Distingue al instante entre un cable defectuoso, interferencia eléctrica EMI y un *Duplex Mismatch*.

> **🧠 Recordatorio del modelo mental:** Pensá en el comando **`cable-test` (TDR)** como **el sonar de un submarino metido adentro de cada boca RJ45 del switch**: pega un grito eléctrico por los 8 hilos de cobre y cronometra cuánto tarda en volver el eco cuando choca contra la punta rota del cable para decirte *"el par azul está cortado exactamente a 23 metros de acá"*.

---

## 2. 🗺️ Topología de referencia

Auditaremos remotamente por SSH dos enlaces físicos con problemas en `SW-ACCESO`: un cable de cobre de 55 metros en el **Puerto 2** que bajó a `100 Mbps`, y un enlace de fibra óptica monomodo en el **Puerto SFP+ 25** que sufre microcortes:

```text
+-------------------------------------------------------------------+
|                             SW-ACCESO                             |
+-------------------------------------------------------------------+
         |                                                 |
  Puerto 2 (Cobre Cat6 — 55 metros)                Puerto 25 (SFP+ 10G-LR 1310nm)
  Negoció solo a 100Mbps!                          Microcortes intermitentes!
  -> Corremos TDR (cable-test):                    -> Leemos DDM/DOM (transceiver):
     Par A (1-2): OK                                  TX Power: -2.4 dBm (Normal)
     Par B (3-6): OK                                  RX Power: -23.8 dBm (¡Alarma Baja!)
     Par C (4-5): OPEN at 54 meters! <-- ¡Ajá!
     Par D (7-8): OK
         |                                                 |
         v                                                 v
 [Roseta de Pared en Oficina]                     [Fibra hacia Edificio 2]
 (Pin 4 o 5 mal ponchado en el Jack!)             (Conector LC sucio o fibra estrangulada!)
```

---

## 3. 🛠️ Procedimiento paso a paso por fabricante

> ⚠️ **Advertencia antes de correr `cable-test` (TDR):** Para medir el eco eléctrico en los 4 pares, el chip físico **corta momentáneamente el enlace (`Link Down`) de ese puerto específico durante 2 a 3 segundos**. Nunca corras un `cable-test` sobre el puerto uplink por el cual estás conectado al switch!

### A. Cisco IOS / Catalyst (TDR + SFP Transceiver DOM + Contadores de Errores)

```cisco
! 1. PRUEBA TDR DE CABLE DE COBRE EN EL PUERTO Gi1/0/2:
!    Paso 1.1: Disparar el pulso reflectométrico (tarda ~3 segundos):
test cable-diagnostics tdr interface GigabitEthernet1/0/2

!    Paso 1.2: Mostrar el resultado por cada uno de los 4 pares (Pair A, B, C, D):
show cable-diagnostics tdr interface GigabitEthernet1/0/2

! 2. LECTURA ÓPTICA DDM/DOM DEL MÓDULO SFP/SFP+ EN Gi1/0/25 (con umbrales de alarma):
show interfaces GigabitEthernet1/0/25 transceiver detail

! 3. VER TABLA RESUMIDA DE TODOS LOS PUERTOS QUE TIENEN ERRORES FÍSICOS (CRC, Align, Collisions):
show interfaces counters errors

! 4. LIMPIAR LOS CONTADORES DE UN PUERTO PARA VER SI LOS ERRORES SIGUEN CRECIENDO HOY
!    (¡Un contador con 500 CRC puede ser de hace 6 meses cuando movieron un cable!):
clear counters GigabitEthernet1/0/2
show interfaces GigabitEthernet1/0/2 | include CRC|input errors|collisions
```

---

### B. MikroTik RouterOS v7 (`cable-test`, `ethernet monitor` SFP y `print stats`)

```text
# 1. PRUEBA TDR DE CABLE DE COBRE EN EL PUERTO ether2:
#    Muestra el estado de los 4 pares y a cuántos metros está el corte ('open') o corto ('short'):
/interface ethernet cable-test ether2 once

# 2. LECTURA ÓPTICA DDM/DOM COMPLETA DEL PUERTO DE FIBRA sfp-sfpplus1:
#    Muestra fabricante, longitud de onda (nm), temperatura (°C), voltaje y TX/RX Power en dBm:
/interface ethernet monitor sfp-sfpplus1 once

# 3. AUDITORÍA DE CONTADORES FÍSICOS DE HARDWARE (FCS/CRC, Fragments, Jabber, Pause, Drops):
/interface ethernet print stats-detail where name=ether2

# 4. PONER EN CERO LOS CONTADORES PARA MEDIR TASA DE ERRORES EN VIVO:
/interface ethernet reset-counters ether2
```

---

### C. Switches Gestionables (Aruba / HP ProCurve)

```text
# 1. Ejecutar y mostrar diagnóstico TDR de cable en el puerto 2:
test cable-diagnostics 2
show cable-diagnostics 2

# 2. Ver potencia óptica recibida/transmitida en dBm y alarmas del SFP en el puerto 25:
show interfaces transceiver 25 detail

# 3. Ver contadores detallados de errores físicos (FCS, Runts, Giants, Late Collisions) del puerto 2:
show interfaces 2
clear statistics 2
```

---

### D. Linux (`ethtool` — TDR, DOM Óptico y Contadores del Driver NIC)

```bash
# 1. Ver velocidad negociada, pares soportados y estado de autonegociación:
sudo ethtool eth0

# 2. Ejecutar test TDR de cable de cobre (en placas Intel/Marvell/Realtek modernas con soporte PHY TDR):
sudo ethtool --cable-test eth0

# 3. Leer telemetría óptica DDM/DOM (dBm, temperatura, alarmas) de una placa SFP/SFP+ en Linux:
sudo ethtool -m eth0

# 4. Ver contadores internos de hardware de la placa de red (CRC, rx_missed, tx_aborted):
sudo ethtool -S eth0 | grep -v ": 0$"
```

---

## 4. 🔑 Salida clave e interpretación de flags

### Salida 1: Test TDR detectando un hilo cortado a 54 metros en Cisco y MikroTik

```text
# En Cisco IOS (show cable-diagnostics tdr interface Gi1/0/2):
Interface Speed Local pair Pair length        Remote pair Pair status
--------- ----- ---------- ------------------ ----------- --------------------
Gi1/0/2   100M  Pair A     55   +/- 2  meters Pair B      Normal
                Pair B     55   +/- 2  meters Pair A      Normal
                Pair C     54   +/- 2  meters N/A         Open
                Pair D     55   +/- 2  meters Pair D      Normal

# En MikroTik RouterOS (/interface ethernet cable-test ether2 once):
        name: ether2
      status: link-ok
  cable-pairs: open:54,normal:55,normal:55,normal:55
```

### Salida 2: Monitor Óptico SFP detectando señal degradada en MikroTik y Cisco

```text
[netops@SW-ACCESO] > /interface ethernet monitor sfp-sfpplus1 once
                      name: sfp-sfpplus1
                    status: link-ok
                      rate: 10Gbps
               full-duplex: yes
          sfp-module-present: yes
               sfp-rx-loss: no
                  sfp-type: SFP/SFP+/SFP28/SFP56
           sfp-vendor-name: MikroTik
    sfp-vendor-part-number: S+31DLC10D
            sfp-wavelength: 1310nm
           sfp-temperature: 44C
        sfp-supply-voltage: 3.298V
       sfp-tx-bias-current: 28mA
              sfp-tx-power: -2.412dBm
              sfp-rx-power: -23.840dBm
```

### Tabla de interpretación diagnóstica

| Qué dice la salida | Diagnóstico Exacto | Acción en Campo |
|--------------------|--------------------|-----------------|
| **`Pair C: 54m Open`** (y el resto mide `55m Normal`) | El par C (pines `4–5`, Azul) está **cortado a 54 metros del switch** (justo en el otro extremo, en la roseta de pared de la oficina!) y por eso el enlace bajó de `1G` a `100M` | **No cambies el patchcord del rack ni todo el cable del techo:** mandá al técnico directamente a re-ponchar el Jack RJ45 de la pared en el escritorio del usuario! |
| **`Pair C: 1m Open`** (en una tirada de 55 metros) | El corte está a **1 metro del switch** (dentro del mismo rack) | Cambiar el patchcord corto que va del switch a la pachera (patch panel) del rack |
| **`Pair status: Short at 18m`** | Dos hilos de cobre están **tocándose en cortocircuito** a 18 metros del switch | Alguien engrapó o aplastó el cable en la bandeja a 18 metros del rack (peligroso si el puerto tiene PoE) |
| **`sfp-tx-power: -2.4 dBm` y `sfp-rx-power: -23.8 dBm`** | El láser transmite con fuerza normal (`-2.4 dBm`), pero del otro lado llega menos del `1%` de la luz (`-23.8 dBm`, perdió `21 dB` en el camino!) | Limpiar los conectores `LC` con alcohol isopropílico al 99% / lápiz óptico *One-Click* y revisar que ningún patchcord amarillo/aqua esté aplastado por la puerta del rack |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Un puerto muestra `18.500 CRC errors`, pero el usuario dice que hoy le anda rápido

1. **Verificación obligatoria antes de desarmar nada:**
   - Los contadores de interfaces acumulan errores desde la última vez que el switch se reinició (que puede haber sido hace 300 días, cuando un técnico movió el cable con el equipo encendido).
2. **Procedimiento:**
   - Ejecutá `clear counters Gi1/0/2` (o `/interface ethernet reset-counters ether2`).
   - Generá tráfico real durante 60 segundos (un test de velocidad o un ping con paquetes grandes de 1472 bytes) y volvé a mirar el contador.
   - Si después de pasar 100.000 paquetes el contador sigue en **`0`**, el problema era histórico. Si suma **`+5, +12, +30`** en un minuto, el cable o el conector está roto hoy mismo.

### Síntoma 2: Dos switches con módulos SFP+ de `10 Gbps` unidos por un cable DAC (o fibra corta) no levantan enlace (`Link Down`) en un puerto que también soporta `1 Gbps`

1. **Causa raíz:** En muchos switches con puertos combo `SFP / SFP+` (`1G / 10G`), un lado está intentando autonegociar a `1G` o espera cláusula de autonegociación diferente al módulo DAC/SFP+ del otro fabricante.
2. **Corrección:** Desactivar `auto-negotiation` en **ambos** extremos del enlace óptico/DAC y fijar explícitamente la velocidad en `10Gbps Full-Duplex` en los dos switches (`/interface ethernet set sfp-sfpplus1 auto-negotiation=no speed=10G-baseSR-LR full-duplex=yes` y `speed nonegotiate` / `speed 10000` en el vecino).

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Inspección preventiva mensual de niveles ópticos (`dBm`):**
  - Anotá en la descripción de cada enlace de fibra cuál fue su `RX Power` el día que se instaló (ej. `comment="UPLINK_NAVE2_FIBRA_BASE_-6.2dBm"`).
  - Si un año después al revisar ves que está en `-16.5 dBm`, aunque el enlace todavía esté `UP`, ya sabés que perdió `10 dB` (el 90% de la luz!) por humedad en una bandeja de empalme o suciedad, y podés programar la limpieza antes de que llegue a `-26 dBm` y se corte en plena producción.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Limpiar la punta cerámica de un conector de fibra óptica `LC/SC` soplándolo con la boca o frotándolo contra la camisa:** El núcleo de una fibra monomodo mide **`9 micrómetros`** (10 veces más fino que un cabello humano). El vapor de la boca o una partícula microscópica de polvo o grasa de la ropa tapa el núcleo por completo y además se carboniza con el calor del láser. **Usá siempre un limpiador óptico mecánico seco (*One-Click Cleaner LC 1.25mm*)** y mantenga los capuchones plásticos puestos en todo SFP o patchcord libre.
- **❌ Doblar un patchcord de fibra óptica en ángulo recto de 90° o apretarlo con precintos plásticos fuertes:** La fibra de vidrio guía la luz por reflexión interna total; si la curva es más cerrada que el radio mínimo de curvatura (~3 cm, el tamaño de una moneda grande), **la luz se escapa por las paredes del vidrio (*Macrobending Loss*)** haciendo caer la potencia `RX` en `15 dB` sin que la fibra esté quebrada.

---

## 8. ✅ Buenas prácticas profesionales

- **Usar precintos de Velcro en lugar de precintos plásticos ajustados tanto en Fibra Óptica como en Cobre Cat6A:** Los precintos plásticos apretados con pinza deforman la geometría del trenzado interno del cobre Cat6A (provocando pérdida de certificación NEXT a 10 Gbps) y estrangulan los patchcords de fibra.

---

## 9. 🔗 Referencias internas

- [`physical-layer-cables-fiber-poe`](../../concepts/physical-layer-cables-fiber-poe.md) — El modelo mental completo de Capa 1, los 4 pares de cobre y la escala logarítmica `dBm`
- [`physical-media-fiber-sfp-and-poe-reference`](../../reference/physical-media-fiber-sfp-and-poe-reference.md) — Tablas de referencia rápida de pinout T568B, tipos de fibra OS2/OM4 y umbrales `dBm`
- [`poe-budgeting-and-switch-management`](poe-budgeting-and-switch-management.md) — Diagnóstico de voltaje y watts PoE sobre cables de cobre
