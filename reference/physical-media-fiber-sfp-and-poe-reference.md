⬅️ [Volver a Referencias](README.md)

# 📚 Capa Física: Cobre, Pinout RJ45, Fibra Óptica, SFP (`dBm`) y PoE — Consulta rápida para NetOps

**Alcance:** `Capa 1 (Física)` | `ANSI/TIA-568`, `IEEE 802.3ab/ae`, `SFF-8472 (DDM/DOM)`, `IEEE 802.3af/at/bt`

---

## 🎯 Cómo usar esta referencia

Consultá estas tablas al certificar cableado, crimpar fichas RJ45, elegir transceptores SFP/SFP+ y patchcords de fibra óptica, auditar niveles de potencia óptica en `dBm` por consola o calcular la fuente en Watts de un switch PoE.

---

## 📊 1. Categorías de Cable de Cobre Par Trenzado (Ethernet)

| Categoría | Estándar IEEE | Frecuencia | Distancia a `1 Gbps` | Distancia a `2.5G / 5G` | Distancia a `10 Gbps` | Interpretación / Uso en campo |
|:---------:|---------------|:----------:|:--------------------:|:-----------------------:|:---------------------:|-------------------------------|
| **Cat 5** | `100BASE-TX` | `100 MHz` | No certificado | — | — | ❌ **Obsoleto:** reemplazar si limita enlaces a `100 Mbps` |
| **Cat 5e** | `1000BASE-T` | `100 MHz` | **`100 m`** | `100 m` (`2.5GBASE-T`) | — | ✅ Mínimo estándar para puestos de oficina, cámaras IP y teléfonos VoIP |
| **Cat 6** | `1000BASE-T` / `10G` | `250 MHz` | **`100 m`** | `100 m` | **`55 m`** (`37m` con alto crosstalk) | ✅ Estándar recomendado para cableado horizontal nuevo |
| **Cat 6A** | `10GBASE-T` | `500 MHz` | **`100 m`** | `100 m` | **`100 m`** | 🏆 **Recomendado para uplinks en cobre, servidores y APs WiFi 6E/7** |
| **Cat 7 / 7A** | ISO/IEC 11801 | `600–1000 MHz` | `100 m` | `100 m` | `100 m` | Blindaje S/FTP individual por par; entornos industriales con alto ruido EMI |
| **Cat 8** | `25G / 40GBASE-T` | `2000 MHz` | `30 m` | `30 m` | **`30 m`** (a `25G/40G`) | Solo enlaces cortos Top-of-Rack en Data Center (en la práctica se prefiere DAC/Fibra) |

---

## 📊 2. Pinout RJ45 (`T568B` vs `T568A`) y Uso de Pares por Tecnología

| Pin RJ45 | Color en **`T568B`** (Estándar empresarial) | Color en `T568A` | Par # | Uso en `10/100 Mbps` (Fast Ethernet) | Uso en `1 / 2.5 / 5 / 10 Gbps` | Uso en PoE (`802.3af/at` Modo A vs Modo B) |
|:--------:|---------------------------------------------|------------------|:-----:|--------------------------------------|--------------------------------|--------------------------------------------|
| **Pin 1** | 🟧⬜ **Blanco / Naranja** | 🟩⬜ Blanco / Verde | Par 2 | ✅ **`TX+` (Transmite)** | ✅ Bidireccional `BI_DA+` | **Modo A:** `+Vdc` (o `-Vdc`) sobre datos |
| **Pin 2** | 🟧 **Naranja** | 🟩 Verde | Par 2 | ✅ **`TX-` (Transmite)** | ✅ Bidireccional `BI_DA-` | **Modo A:** `+Vdc` (o `-Vdc`) sobre datos |
| **Pin 3** | 🟩⬜ **Blanco / Verde** | 🟧⬜ Blanco / Naranja | Par 3 | ✅ **`RX+` (Recibe)** | ✅ Bidireccional `BI_DB+` | **Modo A:** `-Vdc` (o `+Vdc`) sobre datos |
| **Pin 4** | 🟦 **Azul** | 🟦 Azul | Par 1 | ❌ *No se usa en 100M* | ✅ **Obligatorio (`BI_DC+`)** | **Modo B (y PoE Pasivo):** **`+Vdc` Positivo** |
| **Pin 5** | 🟦⬜ **Blanco / Azul** | 🟦⬜ Blanco / Azul | Par 1 | ❌ *No se usa en 100M* | ✅ **Obligatorio (`BI_DC-`)** | **Modo B (y PoE Pasivo):** **`+Vdc` Positivo** |
| **Pin 6** | 🟩 **Verde** | 🟧 Naranja | Par 3 | ✅ **`RX-` (Recibe)** | ✅ Bidireccional `BI_DB-` | **Modo A:** `-Vdc` (o `+Vdc`) sobre datos |
| **Pin 7** | 🟫⬜ **Blanco / Marrón** | 🟫⬜ Blanco / Marrón | Par 4 | ❌ *No se usa en 100M* | ✅ **Obligatorio (`BI_DD+`)** | **Modo B (y PoE Pasivo):** **`-Vdc` Negativo** |
| **Pin 8** | 🟫 **Marrón** | 🟫 Marrón | Par 4 | ❌ *No se usa en 100M* | ✅ **Obligatorio (`BI_DD-`)** | **Modo B (y PoE Pasivo):** **`-Vdc` Negativo** |

> **🔍 Regla diagnóstica de campo:**
>
> - **Si se corta el pin `1, 2, 3 o 6`:** El enlace cae a **`Link Down`** total (salvo ciertos chips Gigabit que intentan bajar, pero en el 99% pierde tráfico).
> - **Si se corta el pin `4, 5, 7 u 8`:** El enlace **NO cae a Down**, sino que negocia automáticamente a **`100 Mbps Full-Duplex`** (y si usaba PoE Modo B o PoE Pasivo, el equipo se apaga).

---

## 📊 3. Fibra Óptica y Transceptores SFP / SFP+ / QSFP28

| Tipo de Fibra | Categoría | Núcleo / Cladding | Color de Chaqueta | Transceptor Típico | Longitud de Onda | Distancia Máx. (`1G / 10G`) | Interpretación / Uso en campo |
|---------------|:---------:|:-----------------:|-------------------|--------------------|:----------------:|:---------------------------:|-------------------------------|
| **Multimodo (MMF)** | `OM1 / OM2` | `62.5` o `50/125 µm` | 🟧 **Naranja** | `1000BASE-SX` / `10G-SR` | `850 nm` | `275–550 m` (`1G`) / `33–82 m` (`10G`) | Cableado multimodo antiguo; muy limitado a 10 Gbps |
| **Multimodo (MMF)** | **`OM3`** | `50 / 125 µm` | 🩵 **Aguamarina (Aqua)** | `SFP+ 10GBASE-SR` | `850 nm` | **`300 m` a `10 Gbps`** (`100m` a `40G/100G`) | ✅ Estándar dentro de la misma sala de servidores o entre racks cercanos |
| **Multimodo (MMF)** | **`OM4`** | `50 / 125 µm` | 🩵 **Aqua** o 🟪 **Violeta** | `SFP+ 10GBASE-SR` | `850 nm` | **`400 m` a `10 Gbps`** (`150m` a `40G/100G`) | ✅ Multimodo de alto rendimiento para Data Center |
| **Monomodo (SMF)** | **`OS2`** | **`9 / 125 µm`** | 🟨 **Amarillo** (o Negro ext.) | `SFP+ 10GBASE-LR` | **`1310 nm`** | **`10 km` a `20 km`** | 🏆 **Estándar universal entre edificios, pisos lejanos y plantas industriales** |
| **Monomodo (SMF)** | **`OS2` (BiDi)** | `9 / 125 µm` (1 solo pelo) | 🟨 **Amarillo** (1 conector LC) | `SFP+ BiDi (WDM)` *(se compran en par A+B)* | **Lado A:** `TX 1270 / RX 1330 nm` **Lado B:** `TX 1330 / RX 1270 nm` | `10 km` a `20 km` | Usa **1 solo hilo de fibra** en lugar de 2. ¡Obligatorio poner el módulo `1270/1330` en una punta y el opuesto `1330/1270` en la otra! |
| **Monomodo (SMF)** | `OS2` (Largo) | `9 / 125 µm` | 🟨 **Amarillo** | `10GBASE-ER` / `ZR` | `1550 nm` | `40 km` (`ER`) / `80 km` (`ZR`) | Enlaces interurbanos. ⚠️ **Requiere atenuador óptico si se prueba en banco con patchcord corto** |

---

## 📊 4. Umbrales de Potencia Óptica SFP (`DDM / DOM` en `dBm`)

| Lectura `RX Power` (Luz recibida) | Estado del Enlace | Interpretación y Acción Inmediata en Campo |
|:---------------------------------:|-------------------|--------------------------------------------|
| **`> 0 dBm` a `-2.0 dBm`** | 🚨 **Saturación (`RX Too High`)** | **¡Peligro de quemar el fotodiodo receptor!** Estás usando un SFP de 40/80 km (`ER/ZR`) en una distancia corta. Colocar un **atenuador óptico de `10 dB` o `15 dB`** en recepción |
| **`-3.0 dBm` a `-15.0 dBm`** | ✅ **Óptimo / Excelente** | Nivel saludable normal para enlaces `SR` (multimodo) y `LR` (monomodo hasta 10 km). `0` errores CRC |
| **`-16.0 dBm` a `-20.0 dBm`** | 🟢 **Aceptable (Con margen)** | Normal en enlaces largos; si es un enlace corto de 100 metros, limpiar las férulas `LC` con lápiz limpiador óptico (*One-Click Cleaner*) |
| **`-21.0 dBm` a `-24.5 dBm`** | ⚠️ **Alarma Baja (`Low RX Warning`)** | **Enlace al borde de caer:** hay una curva cerrada en el patchcord de fibra, suciedad en el acoplador del ODF, una fusión mal hecha o mezclaste fibra MMF con SMF |
| **`< -26.0 dBm` (ej. `-40.0 dBm`)** | ❌ **`LOS` (*Loss of Signal*)** | **Oscuridad total:** fibra cortada en la calle, patchcord desconectado o **los dos pelos `TX/RX` están sin cruzar** (invertir A↔B en un conector LC) |

---

## 📊 5. Estándares Power over Ethernet (PoE) y Presupuesto de Potencia

| Estándar | Nombre | Clase PoE | Voltaje en Switch (PSE) | Voltaje mín. en Equipo (PD) | Watts máx. en Puerto Switch | Watts útiles en Equipo (`100m`) | Pares Energizados | Equipos típicos |
|----------|--------|:---------:|:-----------------------:|:---------------------------:|:---------------------------:|:-------------------------------:|:-----------------:|-----------------|
| **`IEEE 802.3af`** | **PoE** | `Class 0–3` | `44 – 57V DC` | `37V DC` | **`15.4 W`** | **`12.95 W`** | 2 pares | Teléfonos IP, cámaras fijas básicas, sensores |
| **`IEEE 802.3at`** | **PoE+** | `Class 4` | `50 – 57V DC` | `42.5V DC` | **`30.0 W`** | **`25.5 W`** | 2 pares | Access Points WiFi 6/6E, cámaras domo PTZ |
| **`IEEE 802.3bt` (Tipo 3)** | **PoE++ (`4PPoE`)** | `Class 5–6` | `50 – 57V DC` | `42.5V DC` | **`60.0 W`** | **`51.0 W`** | **4 pares** | APs WiFi 7 multigigabit, cámaras PTZ con calefactor |
| **`IEEE 802.3bt` (Tipo 4)** | **PoE++ (`Hi-PoE`)** | `Class 7–8` | `52 – 57V DC` | `41.1V DC` | **`90 – 100 W`** | **`71.3 W`** | **4 pares** | Switches compactos alimentados por PoE, monitores/thin clients |
| **PoE Pasivo `24V`** | *Passive 24V* | Sin clase | `24V DC` fijo | `~18V DC` | `12 – 24 W` | Variable | 2 pares (`4,5+ / 7,8-`) | Antenas CPE MikroTik / Ubiquiti airMAX. ⚠️ **Sin negociación: no enchufar PCs** |

---

## ⚡ Comandos rápidos de verificación

```text
# Cisco IOS: Ver óptica SFP (dBm), correr test TDR de cable y ver watts PoE
show interfaces Gi1/0/25 transceiver detail
test cable-diagnostics tdr interface Gi1/0/1
show power inline

# MikroTik RouterOS v7: Ver óptica SFP (dBm), correr test de cable y monitorear PoE
/interface ethernet monitor sfp-sfpplus1 once
/interface ethernet cable-test ether1
/interface ethernet poe monitor ether1 once

# Linux: Ver estado de enlace, errores físicos y niveles ópticos del SFP
ethtool eth0
ethtool -m eth0
```

---

## 🔗 Ver también

- [`physical-layer-cables-fiber-poe`](../concepts/physical-layer-cables-fiber-poe.md) — Explicación conceptual profunda de Capa 1, Duplex Mismatch y presupuesto PoE nocturno
- [`symptom-to-layer-troubleshooting-matrix`](symptom-to-layer-troubleshooting-matrix.md) — Cómo correlacionar síntomas físicos con las demás capas
