⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Enlace Gigabit cae a 100 Mbps o acumula errores CRC/FCS por par cortado o Duplex Mismatch

**Dominio:** `l1-l2`
**Nivel:** 🟢 Básico
**Capas OSI afectadas:** `Capa 1 (Física)` y `Capa 2 (Enlace)`
**Equipos involucrados:** `Cisco IOS`, `MikroTik RouterOS`, `Switch Gestionable / Linux`

---

## 🎯 Problema

Un usuario del área de Diseño (conectado al **Puerto 2** de `SW-ACCESO`) reporta que copiar proyectos desde el servidor local tarda 10 veces más que a sus compañeros, y cuando hay una transferencia grande la conexión se corta por segundos. El enlace figura `UP` y el ping sin carga responde en `0.8 ms`.

```text
[PC-Diseno: 10.1.10.52] <====(Tirada UTP Cat6 de 48 metros)====> [SW-ACCESO: Puerto 2 (Gi1/0/2 / ether2)]
 (Placa 1Gbps Full)            Pin 5 (Blanco/Azul) suelto         (Negoció a 100Mbps o suma CRC Errors!)
                               a 47 metros en la roseta!
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# Cisco IOS: Ver velocidad/duplex negociados, errores CRC y disparar reflectometría TDR del cable
show interfaces Gi1/0/2 | include line protocol|Duplex|CRC
test cable-diagnostics tdr interface Gi1/0/2
show cable-diagnostics tdr interface Gi1/0/2

# MikroTik RouterOS v7: Ver tasa negociada, errores FCS y medir a cuántos metros está el corte por TDR
/interface ethernet monitor ether2 once
/interface ethernet print stats where name=ether2
/interface ethernet cable-test ether2 once

# Linux / Host de diagnóstico: Ver velocidad, duplex y contadores físicos de la placa
ethtool eth0 | grep -E "Speed|Duplex|Auto-negotiation|Link"
ip -s link show eth0
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# En MikroTik (/interface ethernet monitor ether2 once + cable-test):
            status: link-ok
  auto-negotiation: done
              rate: 100Mbps
       full-duplex: yes
       cable-pairs: normal:48,normal:48,open:47,normal:48

# En Cisco IOS (show interfaces Gi1/0/2 + show cable-diagnostics tdr):
  Full-duplex, 100Mb/s, media type is 10/100/1000BaseTX
  14250 input errors, 14190 CRC, 0 frame, 0 overrun, 0 ignored
  Gi1/0/2   100M  Pair C     47   +/- 2  meters N/A         Open
```

**Interpretación de la evidencia:**

- `rate: 100Mbps` en un puerto Gigabit con `Pair C: 47m Open` → confirma que **uno de los hilos del Par Azul (`pines 4–5`) o Par Marrón (`pines 7–8`) está cortado a 47 metros del switch** (en la roseta de pared de la oficina). Como `100BASE-TX` solo usa 2 pares (`1, 2, 3 y 6`), el enlace no cayó a `Down`, sino que degradó a `100 Mbps`.
- `14190 CRC` creciendo al pasar tráfico → confirma corrupción física de tramas en Capa 1 (ficha sulfatada, par mal crimpado o *Duplex Mismatch*).

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Hipótesis descartada (Capas 3 a 7 — Firewall / QoS / Servidor Samba):** Los compañeros en la misma VLAN 10 descargan del mismo servidor a `1 Gbps` (`112 MB/s`), por lo que el servidor, el trunk y el router están 100% sanos.
- **Causa raíz (Capa 1):** Gigabit Ethernet (`1000BASE-T`) transmite simultáneamente por los **4 pares (8 hilos)**. Si falla 1 solo hilo de los pares `4–5` o `7–8`, la autonegociación hace fallback a `100 Mbps`. Y si un extremo fue forzado a mano a `100M Full` mientras el otro quedó en `Auto`, el lado `Auto` cae a **`100M Half-Duplex` (*Duplex Mismatch*)**, destruyendo el caudal a `< 1 Mbps` por colisiones tardías (*Late Collisions*).

> **🧠 Modelo mental del incidente:** Pensá en esta falla como **una autopista de 4 carriles donde se derrumbó el carril 3 a 1 metro de la llegada**: la policía cierra el tránsito rápido de `1 Gbps` y obliga a todos a circular por los 2 carriles viejos de `100 Mbps`.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Aislar si es degradación por par roto (`100M`) o *Duplex Mismatch* (`Half-Duplex`)

```text
# Cisco IOS
show interfaces status | include Gi1/0/2

# MikroTik RouterOS
/interface ethernet monitor ether2 once
```

- Si ves **`a-full a-100` (`100Mbps Full-Duplex` con autonegociación activa)**: es un problema 100% de **cable/ficha (faltan los pines 4, 5, 7 u 8)**.
- Si ves **`100Mbps Half-Duplex`** de un lado y **`Full-Duplex`** del otro: alguien desactivó `Auto-Negotiation` en una de las dos puntas.

### 2. Confirmar si los errores CRC son actuales o históricos

```text
# Cisco IOS: Poner contadores en cero y pasar tráfico durante 30 segundos
clear counters Gi1/0/2
show interfaces Gi1/0/2 | include CRC|collisions

# MikroTik RouterOS
/interface ethernet reset-counters ether2
/interface ethernet print stats where name=ether2
```

### 3. Medir la distancia exacta al corte con TDR (`cable-test`)

> ⚠️ *Recordá que el test TDR corta el link de esa boca durante 2 segundos.*

```text
# Cisco IOS
test cable-diagnostics tdr interface Gi1/0/2
show cable-diagnostics tdr interface Gi1/0/2

# MikroTik RouterOS
/interface ethernet cable-test ether2 once
```

- Si la falla (`open` / `short`) figura a **`0m – 2m`**: el problema está en el patchcord del rack.
- Si la falla figura al **final del metraje (`47m` de `48m`)**: el problema está en el Jack RJ45 de la pared de la oficina o en el patchcord de la PC.

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
show running-config interface Gi1/0/2
```

### 2. Acción correctiva por fabricante

#### Si era *Duplex Mismatch* (Restaurar Auto-Negotiation en ambos lados)

```cisco
! En Cisco IOS:
configure terminal
interface GigabitEthernet1/0/2
 speed auto
 duplex auto
exit
```

```text
# En MikroTik RouterOS v7:
/interface ethernet set ether2 auto-negotiation=yes

# En Linux:
sudo ethtool -s eth0 autoneg on
```

#### Si era par físico abierto en el TDR (`open at 47m`)

- Re-ponchar el Jack Keystone RJ45 en la roseta de pared respetando la norma **`T568B`** en ambos extremos y reemplazar el patchcord del puesto por uno certificado Cat6 de cobre puro.

### 3. Rollback (si un equipo industrial antiguo de 100M no soporta autonegociación)

```text
# Solo para PLCs o equipos antiguos que obliguen a fijar 100M en AMBOS extremos por igual:
/interface ethernet set ether2 auto-negotiation=no speed=100M-baseT-full full-duplex=yes
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] `rate: 1Gbps` y `full-duplex: yes` (`a-full a-1000` en `show interfaces status`).
- [ ] `cable-pairs: normal,normal,normal,normal` en TDR.
- [ ] `0` nuevos errores `CRC / FCS` tras transferir un archivo de 1 GB.
- [ ] **Cómo evitar que vuelva a ocurrir:** Certificar cada boca nueva tras el ponchado, prohibir cables CCA (aluminio bañado en cobre) y monitorear `ifInErrors` por SNMP en LibreNMS/Prometheus.

---

## 🔗 Referencias

- [`physical-layer-cables-fiber-poe`](../../concepts/physical-layer-cables-fiber-poe.md) — Fundamento teórico de los 4 pares en `1000BASE-T` y Duplex Mismatch
- [`physical-diagnostics-sfp-fiber-and-tdr`](../../guides/05-wireless-poe/physical-diagnostics-sfp-fiber-and-tdr.md) — Guía completa de uso de TDR y contadores físicos
