⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Enlace de fibra óptica intermitente o caído por degradación de potencia óptica SFP (`dBm` / `LOS`)

**Dominio:** `l1-l2`
**Nivel:** 🟡 Intermedio
**Capas OSI afectadas:** `Capa 1 (Fibra Óptica y Transceptores SFP/SFP+ DDM/DOM)`
**Equipos involucrados:** `Cisco IOS`, `MikroTik RouterOS`, `Aruba / Linux`

---

## 🎯 Problema

El enlace troncal de fibra óptica de `10 Gbps` entre el Edificio Principal (`SW-CORE`) y la Nave Industrial (`SW-NAVE2`, a 400 metros) empezó a sufrir microcortes (`Link Flap`) varias veces por día y pérdidas de paquetes con errores `CRC`, hasta que hoy tras una limpieza en el rack quedó en **`Link Down`** total.

```text
+-----------------------------------+        Fibra Monomodo OS2 (400m)        +-----------------------------------+
|       SW-CORE (SFP+ 10G-LR)       |       Conector LC sucio / doblado       |      SW-NAVE2 (SFP+ 10G-LR)       |
|   TX Power: -2.3 dBm (Emite bien) | ======================================> |   RX Power: -27.4 dBm (¡LOS!)     |
|   RX Power: -25.1 dBm (Muy débil) | <====================================== |   TX Power: -2.5 dBm (Emite bien) |
+-----------------------------------+       ¡Se perdieron > 23 dB de luz!     +-----------------------------------+
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# MikroTik RouterOS v7: Leer telemetría óptica DDM/DOM (TX Power, RX Power en dBm, rx-loss y temperatura)
/interface ethernet monitor sfp-sfpplus1 once

# Cisco IOS: Ver niveles de luz en dBm y tabla de umbrales de alarma del SFP+
show interfaces TenGigabitEthernet1/0/1 transceiver detail

# Aruba / HP ProCurve: Ver potencia óptica recibida/transmitida en el SFP+
show interfaces transceiver 25 detail

# Linux: Leer sensores DDM/DOM del transceptor SFP+
sudo ethtool -m eth0
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# En MikroTik (/interface ethernet monitor sfp-sfpplus1 once):
                      name: sfp-sfpplus1
                    status: no-link
          sfp-module-present: yes
               sfp-rx-loss: yes
            sfp-wavelength: 1310nm
           sfp-temperature: 43C
              sfp-tx-power: -2.310dBm
              sfp-rx-power: -27.450dBm

# En Cisco IOS (show interfaces Te1/0/1 transceiver detail):
                                 High Alarm  High Warn  Low Warn   Low Alarm
          Temperature               75.0        70.0        0.0       -5.0
  Port    (Celsius)      Voltage   Current     Tx Power    Rx Power
  Te1/0/1   42.5          3.29      29.4        -2.3        -27.4 --   (Low Alarm: -24.0 dBm!)
```

**Interpretación de la evidencia:**

- `sfp-tx-power: -2.3 dBm` → **el láser del módulo SFP+ está sano y emitiendo luz con fuerza normal** (`-1` a `-5 dBm`). ¡No gastes dinero cambiando el módulo SFP+!
- `sfp-rx-power: -27.4 dBm` (`sfp-rx-loss: yes`, por debajo del umbral `Low Alarm` de `-24.0 dBm`) → en un enlace de apenas 400 metros (donde la pérdida normal debería ser `< 1 dB`, llegando a `-3.5 dBm`), **se están perdiendo `25 dB` de luz en el camino** (suciedad en el conector LC, patchcord amarillo estrangulado/doblado por la puerta del rack o hilos `TX/RX` invertidos).

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Hipótesis descartada (Módulo SFP+ quemado o desprogramado):** El módulo es detectado (`sfp-module-present: yes`), su temperatura es normal (`43 °C`) y su láser transmite a `-2.3 dBm`.
- **Las 3 causas físicas posibles en la fibra:**
  1. **Si `RX Power` marca `-40.0 dBm` exactos** después de que alguien reconectó el patchcord: **los dos pelos del conector `LC Duplex` quedaron sin cruzar (`TX` mirando a `TX`)**, o el hilo se quebró del todo.
  2. **Si `RX Power` marca entre `-20 dBm` y `-27 dBm`:** La luz llega, pero atenuada al `99%` por **polvo/grasa en la férula cerámica del conector `LC`**, un **radio de curvatura cerrado** (patchcord apretado con un precinto o puerta del rack) o **mezcla de patchcord Multimodo (naranja/aqua `50µm`) con fibra Monomodo (amarilla `9µm`)**.
  3. **Si `RX Power` está bien (`-5 dBm`) en ambos lados pero dice `no-link`:** Diferencia de velocidad/autonegociación (`1G` vs `10G` en puerto SFP+).

> **🧠 Modelo mental del incidente:** Pensá en `TX Power` vs `RX Power` como **alumbrar con una linterna potente (`-2.3 dBm`) por adentro de un tubo de vidrio hacia un compañero**: si la linterna prende fuerte pero tu compañero del otro lado apenas ve un puntito casi apagado (`-27.4 dBm`), la linterna no está rota; el vidrio del medio está tapado de barro o doblado.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Comparar `TX Power` y `RX Power` en AMBOS switches (si podés entrar al remoto por un enlace backup/4G)

```text
# Verificar cuál de los dos pelos de la fibra (Ida o Vuelta) es el que tiene la atenuación:
/interface ethernet monitor sfp-sfpplus1 once
```

- Si en `SW-CORE` el `RX Power` es `-27 dBm`, el problema está en el hilo que **viene desde `SW-NAVE2` hacia `SW-CORE`**.

### 2. Inspección física del rack (Sin mirar jamás la punta de la fibra con los ojos!)

1. **Verificar radio de curvatura:** Seguir visualmente el patchcord de fibra amarillo desde el SFP+ hasta la bandeja ODF. Si está doblado en ángulo cerrado o aplastado por otros cables pesados, liberarlo: vas a ver en vivo en la consola cómo el `RX Power` sube instantáneamente de `-27 dBm` a **`-4 dBm`**!
2. **Verificar que el color del patchcord coincida con el SFP+:**
   - Si el SFP+ dice **`1310nm` (`LR / LX`)**, el patchcord debe ser **Monomodo `OS2` (Amarillo)**.
   - Si el SFP+ dice **`850nm` (`SR / SX`)**, el patchcord debe ser **Multimodo `OM3/OM4` (Aguamarina / Violeta)**.
3. **Si el enlace nunca levantó tras cambiar el patchcord (`RX = -40 dBm`):** Destrabar el clip plástico que une los dos conectores `LC` en **una sola** de las puntas e intercambiar la posición del conector izquierdo con el derecho (`A ↔ B`).

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
/interface ethernet monitor sfp-sfpplus1 once
```

### 2. Acción correctiva en campo (Limpieza óptica seca y reemplazo de patchcord)

1. Retirar el patchcord `LC` del SFP+ y del acoplador de la bandeja ODF.
2. Utilizar un **lápiz limpiador óptico seco (*One-Click Cleaner LC 1.25mm*)** dando 1 clic dentro del puerto del SFP+, 1 clic en el acoplador de la ODF y limpiando las dos férulas blancas del patchcord (o reemplazar el patchcord de fibra del rack por uno nuevo cerrado en bolsa).
3. Reconectar asegurando una curva suave y amplia (diámetro mínimo de 6 cm) sujeta solo con Velcro.

### 3. Rollback (Si el puerto SFP+ de 10G no levanta contra un SFP de 1G por autonegociación)

```text
# Si colocaste un módulo SFP de 1 Gbps dentro de una jaula SFP+ de 10 Gbps en MikroTik / Cisco:
/interface ethernet set sfp-sfpplus1 auto-negotiation=no speed=1G-baseX full-duplex=yes
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] `status: link-ok`, `sfp-rx-loss: no`, velocidad `10Gbps Full-Duplex`.
- [ ] `sfp-rx-power` entre **`-3.0 dBm` y `-12.0 dBm`** (pérdida total de inserción `< 3 dB` respecto al `tx-power`).
- [ ] `0` nuevos errores `CRC / FCS` en `/interface ethernet print stats`.
- [ ] **Cómo evitar que vuelva a ocurrir:** Monitorear el sensor `RX Power (dBm)` por SNMP y configurar una alerta preventiva cuando cualquier fibra baje de **`-18 dBm`** (mucho antes de llegar al corte de `-26 dBm`).

---

## 🔗 Referencias

- [`physical-layer-cables-fiber-poe`](../../concepts/physical-layer-cables-fiber-poe.md) — Fundamento teórico de fibra Monomodo vs Multimodo y la escala logarítmica `dBm`
- [`physical-media-fiber-sfp-and-poe-reference`](../../reference/physical-media-fiber-sfp-and-poe-reference.md) — Tabla rápida de umbrales ópticos `dBm` y tipos de fibra `OS2 / OM3 / OM4 / BiDi`
- [`physical-diagnostics-sfp-fiber-and-tdr`](../../guides/05-wireless-poe/physical-diagnostics-sfp-fiber-and-tdr.md) — Guía completa de diagnóstico físico por CLI
