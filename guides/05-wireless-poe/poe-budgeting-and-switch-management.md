⬅️ [Volver a Guías](../README.md)

# Gestión de Switches PoE (802.3af/at/bt), Presupuesto de Potencia y Power-Cycle Remoto — Guía práctica

**Dominio:** `05-wireless-poe`
**Nivel:** 🟢 Básico
**Estándares:** `IEEE 802.3af (PoE 15.4W)`, `IEEE 802.3at (PoE+ 30W)`, `IEEE 802.3bt (PoE++ 60/100W)`, `RFC 3621 (Power Ethernet MIB)`
**Concepto base:** [`physical-layer-cables-fiber-poe`](../../concepts/physical-layer-cables-fiber-poe.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Ver presupuesto total en Watts, consumo por boca y clase IEEE detectada
show power inline
show power inline Gi1/0/3 detail

# MikroTik RouterOS v7 (CRS328-24P / RB5009Pr+S+IN): Ver voltaje, miliamperes y watts en vivo por puerto
/interface ethernet poe monitor [find] once
/interface ethernet poe print

# Aruba / HP ProCurve: Ver resumen de presupuesto PoE y consumo por puerto
show power-over-ethernet brief
show power-over-ethernet 3

# Ubiquiti EdgeSwitch / UniFi Switch (por SSH): Ver estado PoE de todos los puertos
swctrl poe show
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

Un **Switch PoE Gestionable** no solo conmuta tramas Ethernet: es una **PDU (unidad de distribución eléctrica inteligente) administrable por SSH y SNMP**. Dominar sus comandos de consola te permite resolver tres necesidades cotidianas:

1. **Power-Cycle Remoto ("Desenchufar y volver a enchufar a 500 km"):** Cuando una cámara IP en una columna de 8 metros de altura, un Access Point en el cielorraso o un teléfono VoIP se cuelga en su sistema operativo pero sigue consumiendo corriente, **cortás la energía PoE de ese puerto durante 5 segundos por SSH y la volvés a encender**, reiniciando físicamente el aparato sin moverte de tu silla.
2. **Prioridades de Energía (`critical / high / low`):** Si un switch tiene una fuente de `150 Watts` y de noche cuando prenden los infrarrojos de las cámaras la suma pide `165 Watts`, si vos definiste las prioridades por puerto, el switch mantiene encendidas las cámaras perimetrales de seguridad y los APs principales (`critical`) y solo apaga los teléfonos de escritorios vacíos (`low`).
3. **Automatización con *PoE Watchdog / Ping Watchdog*:** Hacer que el propio switch le haga ping cada 1 minuto a la cámara conectada en la boca 3 y, si la cámara deja de responder 5 pings seguidos, **el switch le corte y restaure la energía PoE automáticamente a las 3 de la mañana sin despertarte**.

> **🧠 Recordatorio del modelo mental:** Pensá en el Switch PoE como **un tablero eléctrico con llaves térmicas individuales controladas por software y un amperímetro en cada enchufe**, pero alimentado por **un único generador central (el *PoE Budget*)**. Si la suma de todas las estufas supera los Watts del generador, el tablero empieza a bajar las térmicas de menor prioridad para no quemar la fuente principal.

---

## 2. 🗺️ Topología de referencia

En un switch PoE+ (`SW-ACCESO-POE`), conectamos tres tipos de cargas con distintas prioridades eléctricas:

```text
+-----------------------------------------------------------------------+
|             SW-ACCESO-POE (Presupuesto Total Fuente: 185 Watts)       |
+-----------------------------------------------------------------------+
        |                               |                               |
  Puerto 2 (PoE 802.3af)          Puerto 3 (PoE+ 802.3at)         Puerto 4 (PoE+ 802.3at)
  Prioridad: LOW                  Prioridad: CRITICAL             Prioridad: HIGH
  Consumo: ~4.5 Watts             Consumo: ~18.5 Watts (PTZ+IR)   Consumo: ~11.2 Watts
        |                               |                               |
        v                               v                               v
 [Teléfono VoIP Escritorio]      [Cámara Domo PTZ Perimetral]    [Access Point WiFi 6 Pro]
  (10.1.30.50)                    (10.1.100.50 — Con Watchdog!)   (10.1.99.51)
```

| Puerto | Dispositivo Conectado | Estándar / Clase | Prioridad Eléctrica | Acción ante cuelgue de IP |
|:------:|-----------------------|------------------|:-------------------:|---------------------------|
| **Puerto 2** | Teléfono VoIP | `802.3af` (`Class 2/3`, `< 7W`) | `low` | Manual |
| **Puerto 3** | Cámara Domo PTZ (`10.1.100.50`) | `802.3at` (`Class 4`, hasta `30W`) | **`critical`** | **Auto-Reset PoE si falla ping a `10.1.100.50`** |
| **Puerto 4** | Access Point WiFi 6 (`10.1.99.51`) | `802.3at` (`Class 4`, hasta `30W`) | **`high`** | Manual |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. Cisco IOS / Catalyst PoE (`show power inline`, prioridades y Power-Cycle)

```cisco
! 1. VERIFICAR ESTADO Y PRESUPUESTO TOTAL ANTES DE TOCAR:
show power inline

! 2. REINICIAR ELÉCTRICAMENTE (POWER-CYCLE) UNA CÁMARA O AP COLGADO EN EL PUERTO Gi1/0/3:
!    (Método A — Comando directo de test en Catalyst modernos):
test cable-diagnostics prbs
!    (Método B — Universal en cualquier switch Cisco IOS, funciona el 100% de las veces):
configure terminal
interface GigabitEthernet1/0/3
 power inline never
 ! Esperar 5 segundos para que se descarguen los capacitores de la cámara:
 power inline auto
exit

! 3. CONFIGURAR PRIORIDADES ELÉCTRICAS POR PUERTO (critical / high / low):
interface GigabitEthernet1/0/3
 description CAMARA_PTZ_PERIMETRAL
 power inline auto
 power inline port priority high
exit

! 4. APAGAR PoE EN PUERTOS HACIA SERVIDORES O ROUTERS QUE NO NECESITAN PoE:
interface GigabitEthernet1/0/1
 description UPLINK_RTR_BORDE
 power inline never
exit

end
write memory
```

---

### B. MikroTik RouterOS v7 (Switches `CRS328-24P-4S+` / `CRS354-48P` / `netPower` / `RB5009Pr+S+IN`)

> **🔥 Función estrella de MikroTik PoE (`ping-enabled` Watchdog nativo):** En RouterOS, podés configurar directamente en el puerto PoE la IP de la cámara (`poe-lldp-enabled=yes`, `ping-enabled=yes`, `ping-address=10.1.100.50`). Si la cámara se tilda y no responde al ping durante 3 minutos, **el switch le corta la corriente 5 segundos y la vuelve a prender automáticamente**, anotándolo en el Syslog!

```text
# 1. Monitorear en tiempo real Voltaje (V), Corriente (mA) y Potencia (W) de todos los puertos PoE:
/interface ethernet poe monitor [find] once

# 2. REINICIAR ELÉCTRICAMENTE (POWER-CYCLE) EL PUERTO ether3 DURANTE 5 SEGUNDOS CON 1 SOLO COMANDO:
/interface ethernet poe power-cycle ether3 duration=5s

# 3. Configurar prioridades PoE (1 = Máxima prioridad, 10 = Mínima) y modo 'auto-on' (estándar activo):
#    *(En puertos de Uplink como ether1, apagar poe-out=off)*:
/interface ethernet poe
set ether1 poe-out=off
set ether2 poe-out=auto-on poe-priority=8
set ether3 poe-out=auto-on poe-priority=1
set ether4 poe-out=auto-on poe-priority=2

# 4. ACTIVAR POE PING WATCHDOG EN LA CÁMARA DEL PUERTO ether3 (Auto-Reset si deja de responder a 10.1.100.50):
#    (Si tu modelo no incluye el flag ping-enabled en el chip PoE, podés usar /tool netwatch ejecutando power-cycle):
/tool netwatch
add name="WATCHDOG-POE-CAMARA-P3" host=10.1.100.50 type=icmp interval=1m timeout=2s \
    down-script="/log warning \"Camara 10.1.100.50 no responde: ejecutando PoE Power-Cycle en ether3\"; /interface ethernet poe power-cycle ether3 duration=5s"
```

---

### C. Switches Gestionables (Aruba / HP ProCurve y Ubiquiti UniFi / EdgeSwitch)

```text
# --- EN ARUBA PROCURVE / AOS-S: ---
configure
# 1. Configurar prioridades (critical / high / low) en cada puerto:
interface 3
   power-over-ethernet critical
   exit
interface 4
   power-over-ethernet high
   exit
interface 2
   power-over-ethernet low
   exit

# 2. Reiniciar energía PoE del puerto 3:
no interface 3 power-over-ethernet
# (esperar 5 segundos)
interface 3 power-over-ethernet
write memory


# --- EN UBIQUITI UNIFI SWITCH (Conectado por SSH directo al switch): ---
# 1. Ver tabla de consumo PoE en todos los puertos:
swctrl poe show

# 2. Reiniciar (Power-Cycle) la energía PoE del puerto 3 por SSH:
swctrl poe set off id 3 && sleep 5 && swctrl poe set auto id 3
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En Cisco IOS (`show power inline`)

```text
SW-ACCESO-POE# show power inline
Available:185.0(w)  Used:34.2(w)  Remaining:150.8(w)

Interface Admin  Oper       Power   Device              Class Max
                            (Watts)
--------- ------ ---------- ------- ------------------- ----- ----
Gi1/0/1   never  off        0.0     n/a                 n/a   30.0
Gi1/0/2   auto   on         4.5     IP Phone 8841       2     30.0
Gi1/0/3   auto   on         18.5    Ieee PD             4     30.0
Gi1/0/4   auto   on         11.2    U6-Pro              4     30.0
```

### En MikroTik (`/interface ethernet poe monitor ether2,ether3,ether4 once`)

```text
[netops@SW-ACCESO-POE] > /interface ethernet poe monitor ether2,ether3,ether4 once
Columns: NAME, POE-OUT, POE-OUT-STATUS, POE-OUT-VOLTAGE, POE-OUT-CURRENT, POE-OUT-POWER
# NAME    POE-OUT  POE-OUT-STATUS  POE-OUT-VOLTAGE  POE-OUT-CURRENT  POE-OUT-POWER
0 ether2  auto-on  powered-on      53.2V            84mA             4.4W
1 ether3  auto-on  powered-on      52.8V            350mA            18.4W
2 ether4  auto-on  powered-on      53.0V            211mA            11.1W
```

### Tabla de interpretación de columnas y estados

| Columna / Estado | Fabricante | Qué significa realmente | Estado sano vs Estado roto |
|------------------|------------|-------------------------|----------------------------|
| **`Available: 185W / Remaining: 150.8W`** | Cisco / Aruba | Total de la fuente PoE del switch vs margen libre actual | ✅ Sano: dejar siempre **`>= 20%` libre (`Remaining`)** para absorber picos de arranque y luces IR nocturnas |
| **`POE-OUT-STATUS: powered-on`** | MikroTik | El equipo negoció resistencia `25 kΩ` válida y está recibiendo corriente | Si dice **`waiting-for-load`**: no hay equipo PoE enchufado (o el cable tiene cortado un par de energía) |
| **`POE-OUT-STATUS: short-circuit` / `overload`** | MikroTik / Cisco (`err-disable`) | 🚨 **Cortocircuito físico o exceso de corriente en ese cable** | ❌ Entró agua de lluvia en la ficha RJ45 exterior de la cámara o el cable fue aplastado/mordido. El switch cortó ese puerto para evitar un incendio |
| **`Class 4` (`Max 30.0W`)** | Todos (`IEEE 802.3at`) | El dispositivo conectado pidió PoE+ (hasta 30W en el puerto) | Si conectás un equipo `Class 6 (60W 802.3bt)` en un switch que solo es `802.3at (30W)`, el equipo no encenderá o funcionará en modo degradado sin radio de 6GHz / sin calefactor |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Una cámara IP a 85 metros de distancia figura `powered-on` durante 10 segundos, cuando empieza a girar el motor PTZ se apaga, vuelve a encender y nunca llega a dar link de red

1. **Causa raíz (Caída de tensión por Ley de Ohm en cable largo o cable CCA):**
   - Al arrancar en reposo la cámara pide solo `60 mA` y la caída de voltaje en el cable es pequeña.
   - A los 10 segundos de arrancar, la cámara hace su auto-test del motor PTZ y los LEDs IR, pidiendo de golpe `450 mA`. Si el cable mide 85 metros y es de mala calidad (**CCA — aluminio bañado en cobre** o calibre fino `26 AWG`), la caída de voltaje ($\Delta V = I \times R$) hace que en la punta de la cámara el voltaje baje de `52V` a **`< 37V`**, y la cámara se apaga por baja tensión (*Undervoltage Lockout*).
2. **Verificación y solución:**
   - Mirá el consumo en vivo con `watch` / `/interface ethernet poe monitor ether3` mientras la cámara intenta arrancar.
   - Reemplazá el cable CCA por **cobre puro 100% `23 AWG` (Cat6)** o instalá un **PoE Extender / Switch PoE intermedio** a mitad de camino.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Cuidado al reiniciar el switch PoE durante actualizaciones de firmware:**
  - En muchos switches empresariales (Cisco Catalyst con *Perpetual PoE / Fast PoE* o MikroTik CRS3xx), si hacés un reinicio por software (`reload` / `/system reboot`), el switch **mantiene encendida la alimentación eléctrica PoE de las bocas mientras el sistema operativo del switch reinicia**, para que las cámaras y APs no tengan que tardar otros 3 minutos en arrancar desde cero.
  - Si realmente necesitás cortar la electricidad de los dispositivos conectados, usá el comando explícito de **PoE Power-Cycle** sobre el puerto.

---

## 7. ⚠️ Errores comunes en producción

- **❌ En MikroTik, usar `poe-out=forced-on` sin verificar antes el voltaje de la fuente del switch (`24V` vs `48V/54V`):**
  - `auto-on` primero mide que del otro lado haya un equipo PoE compatible antes de mandar corriente.
  - **`forced-on` inyecta corriente a la fuerza sin preguntar**. Si tu switch MikroTik está alimentado con una fuente de `48V–57V` y ponés `forced-on` en un puerto donde hay conectada una antena MikroTik/Ubiquiti de **`24V Pasivo`** (o una PC vieja), **la vas a quemar instantáneamente con humo blanco**.
- **❌ Comprar un switch de "24 puertos PoE+" sin mirar cuántos Watts totales tiene su fuente interna:** Hay switches económicos de 24 bocas PoE+ cuya fuente interna es de solo **`120 Watts` totales**: podés conectar 24 teléfonos IP de `4W` (`96W`), pero si intentás conectar 15 cámaras PTZ de `15W` (`225W`), a la décima cámara el switch se queda sin fuente. **Calculá siempre la suma de Watts máximos de todos tus dispositivos más un `+25%` de margen antes de elegir el modelo de switch.**

---

## 8. ✅ Buenas prácticas profesionales

- **Configurar siempre LLDP-MED para negociación fina de potencia PoE:** A través de **LLDP (`802.1AB`)**, un Access Point o teléfono IP le dice al switch exactamente cuántos décimos de Watt necesita (por ejemplo, `11.4 W` en lugar de reservar los `30.0 W` enteros de la Clase 4), permitiendo que el switch administre su presupuesto total con mucha más eficiencia.

---

## 9. 🔗 Referencias internas

- [`physical-layer-cables-fiber-poe`](../../concepts/physical-layer-cables-fiber-poe.md) — Concepto completo de estándares PoE y el caso real de las cámaras que se reinician a las 19:30 hs
- [`physical-media-fiber-sfp-and-poe-reference`](../../reference/physical-media-fiber-sfp-and-poe-reference.md) — Tabla de voltajes, clases PoE (`Class 0` a `Class 8`) y pares energizados en el pinout RJ45
- [`physical-diagnostics-sfp-fiber-and-tdr`](physical-diagnostics-sfp-fiber-and-tdr.md) — Cómo diagnosticar si el cable de la cámara PoE tiene un par cortado usando TDR desde la consola del switch
