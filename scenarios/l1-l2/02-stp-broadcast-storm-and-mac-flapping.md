⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Tormenta de Broadcast y MAC Flapping por bucle físico que tumba toda la red

**Dominio:** `l1-l2`
**Nivel:** 🟡 Intermedio
**Capas OSI afectadas:** `Capa 2 (Switching / STP)`
**Equipos involucrados:** `Cisco IOS`, `MikroTik RouterOS`, `Switch Gestionable / No Gestionable`

---

## 🎯 Problema

A las 11:15 AM se cae simultáneamente toda la red de la empresa: nadie puede acceder a los servidores ni a Internet, las llamadas VoIP se cortan, el ping al Default Gateway da `1.900 ms` con `70%` de pérdida y en el rack todos los LEDs de todos los switches parpadean tan rápido que parecen luces fijas.

```text
[RTR-BORDE] ===> [SW-CORE] ===(Puerto 12)===> [Switch doméstico 8 bocas debajo de un escritorio]
                                                    ||                   ||
                                                    +===(Cable en lazo)===+
                                            (¡Las tramas Broadcast giran al infinito
                                             a 1 Gbps sin TTL inundando al SW-CORE!)
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# Cisco IOS: Ver alertas de MAC Flapping en el log, uso de CPU y qué puerto inyecta más paquetes/seg
show logging | include MACFLAP|STORM|SPANTREE
show processes cpu sorted | head -5
show interfaces counters rate

# MikroTik RouterOS v7: Ver alertas en el log, CPU y qué puerto físico tiene el RX Broadcast disparado
/log print where message~"loop|flap"
/interface print stats
/interface ethernet print stats where name~"ether"

# Aruba / HP ProCurve: Ver puertos con alto porcentaje de broadcast y logs de MAC
show interfaces brief
show logging -r
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# En Cisco IOS (show logging + show interfaces counters rate):
%SW_MATM-4-MACFLAP_NOTIF: Host a483.e711.2233 in vlan 10 is flapping between port Gi1/0/1 and port Gi1/0/12
%SW_MATM-4-MACFLAP_NOTIF: Host d4ca.6d01.0203 in vlan 10 is flapping between port Gi1/0/1 and port Gi1/0/12

Port      Name               Intvl   In Mbps     In Kpps    Out Mbps    Out Kpps
Gi1/0/1   UPLINK_RTR         00:30       4.2           6       942.0        1380
Gi1/0/12  OFICINA_VENTAS     00:30     941.8        1379       941.5        1378
```

**Interpretación de la evidencia:**

- `Host ... is flapping between port Gi1/0/1 and port Gi1/0/12` → las tramas de toda la VLAN 10 (incluyendo la MAC del propio router) están rebotando y volviendo a entrar por el puerto **`Gi1/0/12`**.
- `Gi1/0/12` tiene **`941.8 Mbps` (`1.379.000 paquetes por segundo`) de entrada (`In Mbps`)** desde una boca de escritorio → confirma al 100% que el bucle físico está conectado debajo del puerto **`Gi1/0/12`**.

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Hipótesis descartada (Capa 3 / Proveedor de Internet / Ataque externo):** El corte afecta incluso el ping local entre dos PCs del mismo switch y los LEDs físicos parpadean al unísono en toda la LAN.
- **Causa raíz (Capa 2):** Las tramas Ethernet **no tienen campo `TTL`**. Alguien en la Oficina de Ventas (`Puerto 12`) conectó un cable de red entre dos bocas de un switch de escritorio no gestionable (o entre las bocas `SW` y `PC` de un teléfono IP) en un puerto donde no estaban activos `BPDU Guard`, `Loop Protect` ni `Storm Control`.

> **🧠 Modelo mental del incidente:** Pensá en esta falla como **un micrófono pegado frente a un parlante en el Puerto 12**: el primer paquete Broadcast ARP que sale por ese puerto vuelve a entrar amplificado y gira miles de veces por segundo hasta aturdir a todo el edificio.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Entrar al Switch Core (por Consola Serie si el SSH no responde por la saturación)

Si el SSH da timeout debido a que la CPU del switch está al 100% procesando broadcasts, conectá el cable de consola serie (`9600` Cisco / `115200` MikroTik).

### 2. Identificar la boca exacta por donde entra el huracán de paquetes (`RX Broadcast`)

```text
# En Cisco IOS:
show interfaces counters rate
show mac address-table notification mac-move

# En MikroTik RouterOS v7 (Ver qué puerto suma millones de rx-broadcast):
/interface ethernet print stats where rx-broadcast>100000
```

- Si el puerto que trae la tormenta es un enlace Trunk desde otro switch de piso (`SW-PISO2`), entrá a `SW-PISO2` y repetí el comando para encontrar la boca de escritorio final donde nace el bucle.

### 3. Cortar el bucle apagando la boca culpable y confirmar que la red revive en 1 segundo

```text
# Apagar inmediatamente la boca culpable (Puerto 12):
# Cisco:    interface Gi1/0/12 -> shutdown
# MikroTik: /interface ethernet disable ether12
```

- Apenas apagás esa única boca, los LEDs del rack vuelven a la normalidad y el ping al gateway cae de `1.900 ms` a **`0.3 ms`**.

---

## 🧯 Mitigación y Rollback

> ⚠️ **Salvavidas obligatorio:** Nunca desactives `RSTP` para "intentar arreglar" un problema; activá siempre `Safe Mode` (`Ctrl+X`) o `reload in 10` antes de tocar enlaces troncales.

### 1. Verificar antes de tocar (Backup rápido)

```text
show running-config interface Gi1/0/12
/export file=pre-blindaje-stp
```

### 2. Acción correctiva permanente por fabricante (Para que nunca vuelva a tumbar la empresa)

#### En Cisco IOS (Fijar Root Bridge + PortFast + BPDU Guard + Storm Control en bocas de acceso)

```cisco
configure terminal
spanning-tree mode rapid-pvst
spanning-tree vlan 1-4094 priority 4096

interface range GigabitEthernet1/0/2 - 24
 spanning-tree portfast
 spanning-tree bpduguard enable
 storm-control broadcast level 5.00
 storm-control action shutdown
exit

errdisable recovery cause bpduguard
errdisable recovery cause storm-control
errdisable recovery interval 300
end
write memory
```

#### En MikroTik RouterOS v7 (RSTP + BPDU Guard + Loop Protect en bocas de acceso)

```text
/interface bridge set bridge1 protocol-mode=rstp priority=0x1000
/interface bridge port set [find interface~"ether([2-9]|1[0-9]|2[0-4])"] edge=yes bpdu-guard=yes
/interface ethernet set [find default-name~"ether([2-9]|1[0-9]|2[0-4])"] loop-protect=on loop-protect-disable-time=5m
```

#### En Switch Gestionable (Aruba / Ubiquiti / TP-Link)

```text
configure
spanning-tree
spanning-tree priority 1
spanning-tree 2-24 admin-edge-port
spanning-tree 2-24 bpdu-protection
loop-protect 2-24
interface 2-24 broadcast-limit 5
write memory
```

### 3. Rollback (Rehabilitar el puerto 12 una vez retirado físicamente el cable en lazo de la oficina)

```text
# Cisco IOS:
interface Gi1/0/12 -> no shutdown

# MikroTik RouterOS:
/interface ethernet enable ether12
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] `show processes cpu` / `/system resource print` muestra CPU `< 15%`.
- [ ] `0` alertas nuevas de `MACFLAP` en `/log print` / `show logging`.
- [ ] `show spanning-tree` confirma que `SW-CORE` es el Root Bridge (`Priority 4096 / 0x1000`).
- [ ] **Cómo evitar que vuelva a ocurrir:** Retirar switches domésticos no gestionables debajo de los escritorios y mantener activo el combo **`BPDU Guard` + `Loop Protect` + `Storm Control (5%)`** en todas las rosetas de usuarios.

---

## 🔗 Referencias

- [`spanning-tree-and-loop-prevention`](../../concepts/spanning-tree-and-loop-prevention.md) — Por qué un bucle L2 colapsa la red y cómo funciona RSTP
- [`spanning-tree-rstp-bpduguard`](../../guides/02-switching-l2/spanning-tree-rstp-bpduguard.md) — Guía completa de configuración multi-vendor de RSTP y protecciones
