⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Cámaras IP o Access Points se reinician solos de noche por presupuesto PoE agotado o caída de tensión

**Dominio:** `l1-l2`
**Nivel:** 🟢 Básico
**Capas OSI afectadas:** `Capa 1 (PoE IEEE 802.3af/at y Ley de Ohm)`
**Equipos involucrados:** `Cisco IOS PoE`, `MikroTik CRS PoE`, `Aruba / Ubiquiti PoE`

---

## 🎯 Problema

El jefe de seguridad reporta que de día las 16 cámaras IP exteriores del predio funcionan sin fallas, pero **todas las noches alrededor de las 19:45 hs, 4 cámaras específicas se apagan o entran en un bucle de reinicio constante** hasta las 06:30 AM del día siguiente.

```text
+-------------------------------------------------------------------+
|         SW-EXTERIOR-POE (Presupuesto Fuente Total: 150 Watts)     |
|  - De día (IR apagados):   16 cámaras x  5W =  80W (Sobra 70W)    |
|  - De noche (IR al 100%):  16 cámaras x 11W = 176W (¡Faltan 26W!) |
+-------------------------------------------------------------------+
     |                       |                             |
 Puertos 1..12          Puertos 13..15               Puerto 16 (Cable CCA de 92m)
 (Siguen prendidas)     (¡El switch les corta PoE    (Voltaje cae a 35V al prender IR
                         por falta de presupuesto!)   y se reinicia en bucle!)
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# Cisco IOS: Ver presupuesto total (Available vs Used), consumo por puerto y alertas POWER_DENY
show power inline
show logging | include ILPOWER|POWER

# MikroTik RouterOS v7: Ver voltaje, miliamperes, watts y estado PoE (overload / powered-on)
/interface ethernet poe monitor [find] once
/log print where message~"poe"

# Aruba / HP ProCurve: Ver consumo total de la fuente PoE y estado por boca
show power-over-ethernet brief
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente nocturno (Anómalo)

```text
# En Cisco IOS (show power inline + show logging a las 20:00 hs):
Available:150.0(w)  Used:148.5(w)  Remaining:1.5(w)
%ILPOWER-5-ILPOWER_POWER_DENY: Interface Gi1/0/14: inline power denied. Available power 1.5W is less than required 15.4W

# En MikroTik (/interface ethernet poe monitor ether13,ether14,ether16 once):
Columns: NAME, POE-OUT-STATUS, POE-OUT-VOLTAGE, POE-OUT-CURRENT, POE-OUT-POWER
# NAME     POE-OUT-STATUS  POE-OUT-VOLTAGE  POE-OUT-CURRENT  POE-OUT-POWER
0 ether13  overload        0V               0mA              0W
1 ether16  powered-on      48.2V            310mA            14.9W
```

**Interpretación de la evidencia:**

- `Available: 150.0W / Remaining: 1.5W` + `ILPOWER_POWER_DENY` → **al oscurecer, las cámaras encendieron sus reflectores LED infrarrojos (IR) y calefactores**, duplicando su consumo en Watts y agotando la fuente total de `150W` del switch.
- El switch corta automáticamente la energía de los puertos con menor prioridad (por defecto, los números de puerto más altos: `13, 14, 15`).

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Hipótesis descartada (Capas 2 a 7 — NVR, VLANs o Red):** El problema ocurre exactamente a la hora de la puesta del sol y la salida del sol (activación por fotocélula de los LEDs infrarrojos de las cámaras).
- **Dos causas físicas de Capa 1 pueden provocarlo:**
  1. **Agotamiento del Presupuesto Total del Switch (*PoE Budget Exceeded*):** La suma de Watts de todos los puertos supera la fuente interna del switch.
  2. **Caída de Tensión en un cable individual largo o de aluminio (`CCA`):** La fuente del switch tiene Watts libres, pero en una tirada de 90 metros con cable de mala calidad (`CCA`), cuando la cámara duplica sus miliamperes de noche, la caída de voltaje en el cable ($\Delta V = I \times R$) hace que a la cámara le lleguen menos de `37V DC` y se apague sola.

> **🧠 Modelo mental del incidente:** Pensá en esta falla como **una casa con una llave térmica general de 20 Amperes donde en verano todo anda bien, pero en invierno a las 20:00 hs todos prenden las estufas eléctricas al mismo tiempo y salta la térmica general**.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Medir el presupuesto total de la fuente vs la suma de consumos nocturnos

```text
# Cisco IOS:
show power inline

# MikroTik RouterOS:
/interface ethernet poe monitor [find] once
```

### 2. Auditar la calidad y longitud del cable si solo se reinicia 1 cámara mientras sobra presupuesto en el switch

```text
# Medir longitud de los 4 pares con TDR:
# Cisco:    test cable-diagnostics tdr interface Gi1/0/16 -> show cable-diagnostics tdr interface Gi1/0/16
# MikroTik: /interface ethernet cable-test ether16 once
```

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
show power inline
```

### 2. Acción correctiva inmediata (Asignar prioridades a las cámaras críticas y aliviar carga)

Mientras se agrega un segundo switch PoE o inyectores PoE+ dedicados, configurá **prioridad `critical / 1`** en las cámaras de accesos principales para que el switch jamás apague esas bocas, y apagá desde la interfaz web de las cámaras menos importantes la potencia de los LEDs IR del `100%` al `50%` (o mové 3 cámaras a inyectores PoE externos):

#### En Cisco IOS

```cisco
configure terminal
! Blindar las cámaras críticas para que nunca se les corte la energía:
interface range GigabitEthernet1/0/1 - 8
 power inline port priority high
exit
end
write memory
```

#### En MikroTik RouterOS v7

```text
# Prioridad 1 es la MÁS ALTA (nunca se apaga primero); Prioridad 10 es la más baja:
/interface ethernet poe
set ether1,ether2,ether3,ether4,ether5,ether6,ether7,ether8 poe-priority=1
set ether13,ether14,ether15,ether16 poe-priority=9
```

#### En Aruba / HP ProCurve

```text
configure
interface 1-8 power-over-ethernet critical
interface 9-16 power-over-ethernet low
write memory
```

### 3. Rollback

```text
# Restaurar prioridad por defecto una vez ampliada la capacidad PoE con un segundo switch o fuente mayor:
# Cisco:    default interface Gi1/0/1
# MikroTik: /interface ethernet poe set [find] poe-priority=10
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] A las 21:00 hs (con todos los infrarrojos encendidos al 100%), el consumo total del switch se mantiene por debajo del **`80%`** de su presupuesto (`Remaining >= 20%`).
- [ ] `0` eventos de `ILPOWER_POWER_DENY` o `overload` durante toda la noche.
- [ ] **Cómo evitar que vuelva a ocurrir:** Al dimensionar un switch PoE para cámaras o APs, **multiplicar siempre la cantidad de dispositivos por su consumo máximo de hoja de datos (con IR/PTZ encendidos), nunca por su consumo diurno en reposo**, y dejar un 25% de fuente libre.

---

## 🔗 Referencias

- [`physical-layer-cables-fiber-poe`](../../concepts/physical-layer-cables-fiber-poe.md) — Estándares `802.3af/at/bt` y peligro del cable CCA
- [`poe-budgeting-and-switch-management`](../../guides/05-wireless-poe/poe-budgeting-and-switch-management.md) — Guía completa de administración de switches PoE y Watchdog
