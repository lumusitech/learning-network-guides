⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: <Título claro, realista y accionable del incidente o mantenimiento>

**Dominio:** `<l1-l2 | l3-routing | security-vpn | wireless | maintenance>`
**Nivel:** 🟢 Básico | 🟡 Intermedio | 🔴 Avanzado
**Capas OSI afectadas:** `<Capa(s)>`
**Equipos involucrados:** `Cisco IOS`, `MikroTik RouterOS`, `Switch Gestionable / Linux`

---

## 🎯 Problema

<Descripción realista del incidente en 3-5 líneas: qué reportan los usuarios o el sistema de monitoreo, qué funciona y qué no funciona, y cómo está conectada la topología afectada.>

```text
<Diagrama ASCII conciso de la topología donde ocurre el problema, indicando IPs, VLANs y puertos involucrados>
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# Cisco IOS
<comando show de diagnóstico inmediato>

# MikroTik RouterOS v7
<comando print/monitor de diagnóstico inmediato>

# Linux / Host de diagnóstico
<comando ip/ping/tcpdump/ethtool de diagnóstico inmediato>
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
<Salida realista de consola mostrando el error, flag roto, contador creciendo o estado caído>
```

**Interpretación de la evidencia:**

- `<Indicador 1 en la salida>` → confirma que <explicación técnica>.
- `<Indicador 2 en la salida>` → descarta que sea un problema de <otra capa>.

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Hipótesis descartada (<Capa sana>):** <Por qué sabemos rápido que esa capa no tiene la culpa>.
- **Causa raíz (<Capa afectada>):** <Explicación técnica exacta del mecanismo que falló>.

> **🧠 Modelo mental del incidente:** Pensá en esta falla como <analogía breve de 2 líneas que explique por qué se produce el síntoma>.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Aislar el segmento o salto exacto

<Qué comando correr primero y cómo leer su resultado.>

```text
<Comandos y salidas del paso 1>
```

### 2. Confirmar la causa raíz en el equipo afectado

<Cómo inspeccionar la tabla MAC/VLAN/Rutas/Conntrack/Logs para ver el culpable con nombre y apellido.>

```text
<Comandos y salidas del paso 2>
```

### 3. Validar el impacto antes de aplicar el cambio

<Qué verificar para no cortar otros servicios al aplicar la solución.>

```text
<Comandos del paso 3>
```

---

## 🧯 Mitigación y Rollback

> ⚠️ **Salvavidas obligatorio:** Antes de aplicar la corrección remota, activá **Safe Mode** (`Ctrl+X` en MikroTik) o `reload in 10` (en Cisco).

### 1. Verificar antes de tocar (Backup rápido)

```text
# Cisco IOS
show running-config interface <interfaz>

# MikroTik RouterOS
/export file=pre-mitigacion
```

### 2. Acción correctiva por fabricante

#### En Cisco IOS

```cisco
<Comandos exactos de solución en Cisco>
```

#### En MikroTik RouterOS v7

```text
<Comandos exactos de solución en MikroTik>
```

#### En Switch Gestionable (Aruba / Ubiquiti / TP-Link) o Linux

```text
<Comandos o parámetros exactos>
```

### 3. Rollback (si el cambio genera un efecto secundario)

```text
# Cisco IOS: revertir al estado previo
<comandos de rollback cisco>

# MikroTik RouterOS: revertir al estado previo
<comandos de rollback mikrotik>
```

---

## ✅ Verificación post-incidente y Prevención

Cómo confirmar que el incidente quedó cerrado al 100%:

- [ ] `<Check 1 con comando y valor esperado>`
- [ ] `<Check 2 con comando y valor esperado>`
- [ ] **Cómo evitar que vuelva a ocurrir:** <Medida arquitectónica permanente (ej. BPDU Guard, DHCP Snooping, MSS Clamping, monitoreo SNMP)>.

---

## 🔗 Referencias

- [`<concepto>`](../../concepts/<concepto>.md) — Fundamento teórico y modelo mental de esta capa
- [`<guía>`](../../guides/<dominio>/<guía>.md) — Guía completa de configuración paso a paso
