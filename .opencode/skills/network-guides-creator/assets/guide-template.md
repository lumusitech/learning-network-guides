⬅️ [Volver a Guías](../README.md)

# <Título de la tecnología o protocolo> — Guía práctica multi-vendor

**Dominio:** `<01-fundamentals | 02-switching-l2 | 03-routing-l3 | 04-firewalls-nat-vpn | 05-wireless-poe | 06-mikrotik | 07-cisco | 08-operations>`
**Nivel:** 🟢 Básico | 🟡 Intermedio | 🔴 Avanzado
**Estándares:** `<IEEE / RFC aplicables>`
**Concepto base:** [`<concepto>`](../../concepts/<concepto>.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS
<comando show principal>

# MikroTik RouterOS v7
<comando print/monitor principal>

# Aruba / Ubiquiti / Genérico
<comando show principal>

# Linux (iproute2 / bridge / FRR)
<comando linux principal>
```

---

## 📑 Índice

1. [¿Qué resuelve y cuándo usarlo?](#1-qué-resuelve-y-cuándo-usarlo)
2. [Topología de referencia](#2-topología-de-referencia)
3. [Configuración paso a paso por fabricante](#3-configuración-paso-a-paso-por-fabricante)
4. [Salida clave e interpretación de flags](#4-salida-clave-e-interpretación-de-flags)
5. [Uso en troubleshooting](#5-uso-en-troubleshooting)
6. [Mantenimiento, backup y rollback seguro](#6-mantenimiento-backup-y-rollback-seguro)
7. [Errores comunes en producción](#7-errores-comunes-en-producción)
8. [Buenas prácticas profesionales](#8-buenas-prácticas-profesionales)
9. [Referencias internas](#9-referencias-internas)

---

## 1. 🧠 ¿Qué resuelve y cuándo usarlo?

<Explicación concisa de 2 párrafos: qué hace esta configuración en producción, qué problema operativo soluciona y qué prerrequisitos de capa inferior necesita.>

> **🧠 Recordatorio del modelo mental:** Pensá en esta configuración como <analogía coherente de 2 líneas conectada con su archivo en `concepts/`>.

---

## 2. 🗺️ Topología de referencia

Todos los ejemplos de configuración de esta guía implementan exactamente este mismo escenario para que puedas comparar línea por línea cómo se hace en cada marca:

```text
<Diagrama ASCII con nombres de interfaces, VLAN IDs y subredes IP concretas>
```

| Parámetro de la topología | Valor utilizado en los ejemplos |
|---------------------------|---------------------------------|
| `<Parámetro 1 (ej. Enlace Trunk)>` | `<Valor (ej. Gi1/0/1 / ether1 / eth0)>` |
| `<Parámetro 2 (ej. VLANs / Subredes)>` | `<Valor (ej. VLAN 10: 10.0.10.0/24, VLAN 20: 10.0.20.0/24)>` |

---

## 3. 🛠️ Configuración paso a paso por fabricante

> ⚠️ **Salvavidas antes de empezar:** Si estás conectado remotamente por SSH/WinBox, activá **Safe Mode** (`Ctrl+X` en MikroTik) o programá un reinicio preventivo (`reload in 10` en Cisco) antes de aplicar cambios en interfaces o firewall.

### A. Cisco IOS / Catalyst

```cisco
! 1. <Paso 1 explicado>
<comandos cisco>

! 2. <Paso 2 explicado>
<comandos cisco>

! 3. Guardar en NVRAM
end
write memory
```

### B. MikroTik RouterOS (v7+)

```text
# 1. <Paso 1 explicado>
<comandos routeros>

# 2. <Paso 2 explicado>
<comandos routeros>
```

### C. Switches Gestionables (Aruba / Ubiquiti / TP-Link Omada)

```text
# Enfoque Tagged / Untagged / PVID (CLI o equivalente Web GUI)
<comandos o flujo estructurado de parámetros Tagged, Untagged y PVID>
```

### D. Linux (`iproute2` / `bridge` / `FRRouting`)

```bash
# 1. <Paso 1 en Linux>
<comandos linux>
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En Cisco IOS

```text
<Salida realista del comando show en Cisco>
```

### En MikroTik RouterOS

```text
<Salida realista del comando print/monitor en MikroTik con sus flags D, R, H, S, X, I>
```

### Tabla de interpretación de columnas y flags

| Columna / Flag | Fabricante | Qué significa realmente | Estado sano vs Estado roto |
|----------------|------------|-------------------------|----------------------------|
| `<Flag/Columna 1>` | `<Cisco/MikroTik/Linux>` | `<Significado>` | `<Sano vs Roto>` |
| `<Flag/Columna 2>` | `<Cisco/MikroTik/Linux>` | `<Significado>` | `<Sano vs Roto>` |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: <Problema frecuente 1>

1. **Verificación rápida:** `<comando exacto>`
2. **Qué buscar en la salida:** <indicador del problema>
3. **Corrección:** `<comando de corrección>`

### Síntoma 2: <Problema frecuente 2>

1. **Verificación rápida:** `<comando exacto>`
2. **Qué buscar en la salida:** <indicador del problema>
3. **Corrección:** `<comando de corrección>`

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Antes del cambio (Pre-check & Backup):**
  - Cisco: `show running-config interface <id>`
  - MikroTik: `/export file=pre-cambio`
- **Cómo revertir el cambio (Rollback limpio):**
  - En Cisco: `<comandos no ... exactos>`
  - En MikroTik: `<comandos remove / set exactos>`

---

## 7. ⚠️ Errores comunes en producción

- **❌ <Error 1>:** <Por qué pasa y cómo rompe la red>.
- **❌ <Error 2>:** <Por qué pasa y cómo rompe la red>.
- **❌ <Error 3>:** <Por qué pasa y cómo rompe la red>.

---

## 8. ✅ Buenas prácticas profesionales

- **Documentar cada puerto/regla:** Usar siempre `description` (Cisco/Aruba) o `comment="..."` (MikroTik) indicando a qué equipo o ticket pertenece.
- **<Buena práctica 2 específica del protocolo>:** <Explicación>.
- **<Buena práctica 3 específica del protocolo>:** <Explicación>.

---

## 9. 🔗 Referencias internas

- [`<concepto>`](../../concepts/<concepto>.md) — Modelo mental y funcionamiento interno del protocolo
- [`<referencia>`](../../reference/<referencia>.md) — Tabla rápida de equivalencia de comandos
