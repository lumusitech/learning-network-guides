⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Enlace agregado LACP (EtherChannel / Bonding) con puertos suspendidos o pérdida del 50% de paquetes

**Dominio:** `l1-l2`
**Nivel:** 🟡 Intermedio
**Capas OSI afectadas:** `Capa 2 (IEEE 802.3ad / 802.1AX LACP)`
**Equipos involucrados:** `Cisco IOS`, `MikroTik RouterOS`, `Aruba / Linux`

---

## 🎯 Problema

Durante una ampliación, un técnico conecta un segundo cable entre el switch principal **Cisco (`SW-CORE`)** y el switch de distribución **MikroTik (`SW-DIST`)** para duplicar el enlace a `2 Gbps`. Apenas enchufa el segundo cable, **exactamente la mitad de los pings y conexiones hacia el edificio se pierden (`50% packet loss`)** o uno de los puertos queda muerto en estado `suspended / stand-alone`.

```text
+-----------------------------------+                     +-----------------------------------+
|       SW-CORE (Cisco IOS)         |  Cable 1 (Gi1/0/1)  |     SW-DIST (MikroTik CRS326)     |
|  Configuró:                       | ==================> |  Olvidó crear bond1 o RSTP        |
|  'channel-group 1 mode on' (¡Mal!)|  Cable 2 (Gi1/0/2)  |  bloqueó ether2 por bucle!        |
|  (Manda 50% por cada cable        | ---------X--------> |  (El 50% del tráfico que viene    |
|   sin preguntar si hay LACP!)     |                     |   por el Cable 2 se tira!)        |
+-----------------------------------+                     +-----------------------------------+
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# Cisco IOS: Ver flags de los puertos del Port-channel ('P' = OK, 'I' = Stand-alone, 's' = Suspended)
show etherchannel summary
show lacp neighbor

# MikroTik RouterOS v7: Ver si ambos puertos están en 'active-ports' y si recibe el System-ID vecino
/interface bonding monitor bond1 once
/interface bridge port print where interface=bond1

# Aruba / HP ProCurve: Ver estado de negociación LACP en el trunk
show lacp
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# Caso A — Pérdida del 50% de paquetes: En Cisco pusieron 'mode on' (protocolo '-' ninguno) y el vecino bloqueó 1 cable:
Group  Port-channel  Protocol    Ports
------+-------------+-----------+-----------------------------------------------
1      Po1(SU)          -        Gi1/0/1(P)  Gi1/0/2(P)

# Caso B — Puerto suspendido o individual en LACP ('I' o 's'):
1      Po1(SU)         LACP      Gi1/0/1(P)  Gi1/0/2(I)
```

**Interpretación de la evidencia:**

- **En el Caso A (`Protocol: -`, pérdida del 50%):** Alguien usó **`mode on`** (o `mode=balance-rr` en MikroTik) en un extremo, que **desactiva LACP** y escupe paquetes a ciegas por los dos cables sin verificar si el otro switch tiene el bonding armado o si Spanning Tree bloqueó el segundo cable.
- **En el Caso B (`Gi1/0/2(I)` o `(s)`):** El flag **`I` (*Stand-alone*)** indica que el puerto `ether2` del otro lado no fue agregado al grupo LACP. El flag **`s` (*Suspended*)** indica que `Gi1/0/2` tiene diferente configuración de VLANs, modo trunk o velocidad que `Gi1/0/1`.

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Hipótesis descartada (Capa 1):** Si desconectás cualquiera de los dos cables dejando uno solo, la pérdida baja instantáneamente a `0%`.
- **Causa raíz (Capa 2 — Negociación LACP `802.3ad`):** Para que dos cables funcionen como un único enlace lógico sin bucles ni descartes, **ambos extremos deben hablar el protocolo dinámico `IEEE 802.3ad (LACP)` (`mode active` ↔ `mode 802.3ad`)** y todas las VLANs deben estar aplicadas **sobre la interfaz lógica (`Port-channel1` / `bond1` / `trk1`)**, jamás sobre los puertos físicos sueltos.

> **🧠 Modelo mental del incidente:** Pensá en usar `mode on` sin LACP como **un camión de reparto que empieza a tirar la mitad de las cajas por un segundo puente que del otro lado del río todavía tiene la barrera cerrada por la policía (Spanning Tree)**: exactamente la mitad de la mercadería cae al agua.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Desactivar temporalmente el segundo puerto físico para restaurar el 100% del servicio en 2 segundos

En plena emergencia con `50%` de pérdida de paquetes, **lo primero es apagar uno de los dos puertos físicos (`Gi1/0/2` / `ether2`)** para que todo el tráfico fluya al 100% por el Cable 1 mientras corregís la configuración LACP sin presión.

### 2. Auditar la configuración de ambos extremos

```text
# En Cisco IOS: Verificar que Po1 y Gi1/0/1-2 tengan exactamente las mismas líneas y usen 'mode active'
show running-config interface Port-channel1
show running-config interface Gi1/0/1
show running-config interface Gi1/0/2

# En MikroTik RouterOS: Verificar que ether1 y ether2 NO estén en /interface bridge port, sino dentro de bond1!
/interface bonding print detail
/interface bridge port print
/interface bridge vlan print
```

---

## 🧯 Mitigación y Rollback

> ⚠️ **Salvavidas obligatorio:** Activá **Safe Mode (`Ctrl+X`)** en MikroTik y `reload in 10` en Cisco antes de reconfigurar el uplink troncal.

### 1. Verificar antes de tocar (Backup rápido)

```text
/export file=pre-fix-lacp
```

### 2. Acción correctiva por fabricante (Configurar `802.3ad LACP Active` + Hash `Layer 3+4` en ambos lados)

#### En Cisco IOS (`SW-CORE`)

```cisco
configure terminal
port-channel load-balance src-dst-mixed-ip-port

! 1. Limpiar y configurar ambos puertos con LACP 'mode active':
default interface range GigabitEthernet1/0/1 - 2
interface range GigabitEthernet1/0/1 - 2
 description MIEMBRO_LACP_SW_DIST
 shutdown
 channel-protocol lacp
 channel-group 1 mode active
exit

! 2. Aplicar el Trunk sobre Port-channel1 (que lo replica solo a Gi1/0/1 y Gi1/0/2):
interface Port-channel1
 description UPLINK_LACP_SW_DIST
 switchport mode trunk
 switchport trunk native vlan 999
 switchport trunk allowed vlan 10,99,100,200
exit

! 3. Encender los puertos físicos:
interface range GigabitEthernet1/0/1 - 2
 no shutdown
exit
end
write memory
```

#### En MikroTik RouterOS v7 (`SW-DIST`)

```text
# 1. Quitar ether1 y ether2 sueltos del bridge1 (si estaban ahí):
/interface bridge port remove [find interface=ether1 or interface=ether2]

# 2. Crear bond1 en modo 802.3ad con hash layer-3-and-4:
/interface bonding
add name=bond1 slaves=ether1,ether2 mode=802.3ad transmit-hash-policy=layer-3-and-4 mii-interval=100ms

# 3. Meter a 'bond1' dentro del bridge1 y actualizar las VLANs para que salgan tagged por 'bond1':
/interface bridge port
add bridge=bridge1 interface=bond1 frame-types=admit-only-vlan-tagged ingress-filtering=yes trusted=yes

/interface bridge vlan
set [find vlan-ids=10]  tagged=bond1
set [find vlan-ids=99]  tagged=bridge1,bond1
set [find vlan-ids=100] tagged=bond1
set [find vlan-ids=200] tagged=bond1
```

### 3. Rollback (Volver a enlace simple de 1 solo cable si hay que reemplazar un puerto físico dañado)

```text
# Si uno de los dos puertos físicos del switch está quemado, basta con dejarlo en 'shutdown';
# LACP seguirá funcionando normalmente con 1 solo puerto activo dentro de Po1 / bond1!
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] `show etherchannel summary` en Cisco muestra `Protocol: LACP` y ambos puertos con flag **`(P)`**: `Gi1/0/1(P) Gi1/0/2(P)`.
- [ ] `/interface bonding monitor bond1 once` en MikroTik muestra `active-ports: ether1,ether2` y la MAC del Cisco en `lacp-partner-system-id`.
- [ ] `/interface bridge port print where interface=bond1` muestra el flag **`H` (*HW-OFFLOAD*)** activo.
- [ ] **Cómo evitar que vuelva a ocurrir:** Prohibir por política el uso de `channel-group mode on` y `mode=balance-rr` entre switches; usar siempre **`802.3ad LACP (mode active)`**.

---

## 🔗 Referencias

- [`link-aggregation-and-redundancy-l2`](../../concepts/link-aggregation-and-redundancy-l2.md) — Concepto completo de LACP, matriz `Active/Passive` y algoritmos de Hash
- [`lacp-etherchannel-bonding`](../../guides/02-switching-l2/lacp-etherchannel-bonding.md) — Guía completa paso a paso de configuración de LACP en Cisco, MikroTik, Aruba y Linux
