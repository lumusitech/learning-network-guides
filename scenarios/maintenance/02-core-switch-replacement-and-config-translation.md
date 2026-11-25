⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Reemplazo de un Switch Core en producción traduciendo su configuración entre marcas (Cisco ↔ MikroTik ↔ Aruba)

**Dominio:** `maintenance`
**Nivel:** 🟡 Intermedio
**Capas OSI afectadas:** `Capa 1 (Cableado / SFP / PoE)`, `Capa 2 (VLANs / RSTP / LACP)` y `Capa 3 (Management)`
**Equipos involucrados:** `Cisco Catalyst`, `MikroTik CRS3xx`, `Aruba ProCurve`

---

## 🎯 Problema

El switch principal de 24 puertos del rack central (`SW-CORE-VIEJO`, un Cisco Catalyst con 8 años de uso y un ventilador fallando) debe ser reemplazado este jueves a las 20:00 hs por un switch nuevo de otra marca (**un MikroTik `CRS326-24G-2S+` o un Aruba `2930F`**). El switch viejo tiene configurados un grupo LACP en las bocas 1–2, un Trunk hacia un AP en la boca 4, bocas de acceso en tres VLANs distintas (`10, 40, 100`) y es el Root Bridge de Spanning Tree. Si te olvidás de traducir un solo parámetro al switch nuevo, al enchufar los 24 cables a las 20:30 hs la mitad de la planta no levantará.

```text
+---------------------------------------------------+     TRADUCCIÓN EN LABORATORIO     +---------------------------------------------------+
|       SW-CORE-VIEJO (Cisco Catalyst)              |     (¡Antes de ir al rack!)       |       SW-CORE-NUEVO (MikroTik CRS326 / Aruba)     |
|  - IP Mgmt: 10.1.99.2/24 (GW 10.1.99.1)           | ================================> |  - IP Mgmt: 10.1.99.2/24 (en vlan99 sobre bridge1)|
|  - STP: Rapid-PVST+ Priority 4096                 |   Mapa puerto a puerto exacto:    |  - STP: RSTP Priority 0x1000 (4096)               |
|  - Gi1/0/1-2: Po1 LACP Active (Trunk 10,40,99,100)|   Pto 1-2 -> bond1 (802.3ad)      |  - ether1-2: bond1 802.3ad (Tagged 10,40,99,100)  |
|  - Gi1/0/4: Trunk Native 99, Allowed 10,99,200    |   Pto 4   -> PVID 99 + Tag 10,200 |  - ether4: PVID 99 + Tagged 10,200                |
|  - Gi1/0/5-15: Access VLAN 10                     |   Pto 5-15-> PVID 10 (Untagged)   |  - ether5-15: PVID 10 (Untagged, Edge, BPDUGuard) |
+---------------------------------------------------+                                   +---------------------------------------------------+
```

---

## ⚡ Quick command (Extracción de la Radiografía del Switch Viejo en 60 segundos)

Antes de tocar un solo tornillo del rack, ejecutá estos 6 comandos en el switch viejo y guardá su salida en un archivo de texto:

```text
# En el Switch Viejo (Cisco IOS):
show running-config
show interfaces status
show vlan brief
show interfaces trunk
show etherchannel summary
show cdp neighbors detail
show lldp neighbors detail
show mac address-table count
```

---

## 🧠 Metodología: Las 3 Reglas de Oro para un Reemplazo de Switch en 15 Minutos

1. **El switch nuevo se configura, actualiza y prueba al 100% sobre tu escritorio el día anterior (`Staging`), JAMÁS colgado en el rack la noche del cambio.**
2. **Respetar el mapeo físico `Boca N del Viejo == Boca N del Nuevo`:** Si en el switch viejo el servidor contable estaba en la boca 7 y el AP en la boca 4, en el switch nuevo deben ir exactamente en la boca 7 y en la boca 4. Así el cambio físico en el rack consiste únicamente en pasar cada patchcord de la boca `N` de arriba a la boca `N` de abajo.
3. **El switch viejo se apaga y queda atornillado en el rack con su configuración intacta:** Si a mitad de la ventana descubrís que un módulo SFP propietario no es compatible con el switch nuevo, tu **Plan de Rollback** es simplemente volver a pasar los cables al switch viejo y encenderlo en 3 minutos.

---

## 🛠️ Procedimiento paso a paso (Runbook de Traducción y Ventana de Cambio)

### Fase 1 (Día Anterior — En tu Escritorio): Traducir la configuración del Cisco al MikroTik CRS326 (o Aruba)

Tomamos el `show running-config` del Cisco viejo y escribimos su traducción exacta línea por línea para el MikroTik CRS326 nuevo:

| Bloque en el Cisco Viejo | Traducción exacta en el MikroTik CRS326 Nuevo (`RouterOS v7`) | Traducción exacta en el Aruba Nuevo (`AOS-S`) |
|--------------------------|---------------------------------------------------------------|-----------------------------------------------|
| `spanning-tree vlan 1-4094 priority 4096` | `/interface bridge add name=bridge1 protocol-mode=rstp priority=0x1000` | `spanning-tree` + `spanning-tree priority 1` |
| `Gi1/0/1-2`: `channel-group 1 mode active` | `/interface bonding add name=bond1 slaves=ether1,ether2 mode=802.3ad transmit-hash-policy=layer-3-and-4` | `trunk 1-2 trk1 lacp` |
| `Po1`: `trunk allowed vlan 10,40,99,100` | `bond1` en `bridge port` (`admit-only-vlan-tagged`, `trusted=yes`) y en `bridge vlan` (`tagged=bond1`) | `vlan 10,40,99,100 tagged trk1` |
| `Gi1/0/4`: `trunk native 99 allowed 10,99,200` | `ether4` en `bridge port` con `pvid=99 frame-types=admit-all` y en `bridge vlan` (`tagged=ether4` en `10,200`) | `vlan 99 untagged 4` + `vlan 10,200 tagged 4` |
| `Gi1/0/5-15`: `access vlan 10` + `portfast bpduguard` | `ether5..15` en `bridge port` con `pvid=10 frame-types=admit-only-untagged... edge=yes bpdu-guard=yes` | `vlan 10 untagged 5-15` + `admin-edge-port` + `bpdu-protection` |
| `interface Vlan99`: `ip address 10.1.99.2/24` | `/interface vlan add interface=bridge1 name=vlan99 vlan-id=99` (`bridge1` en `tagged=` de VLAN 99!) + IP `.99.2/24` | `vlan 99 ip address 10.1.99.2/24` |

### Fase 2 (T - 15 min antes de cortar): Tomar la Foto Pre-Check en Vivo

1. Ver cuántos puertos están `connected` hoy en el switch viejo (`show interfaces status | include connected`) y anotar cuáles son (ej. 18 bocas encendidas: `1, 2, 4, 5, 6, 7, 9...`).
2. Etiquetar con cinta numerada los patchcords si alguno no tuviera número visible.

### Fase 3 (T = 0 — Corte de 10 minutos): El Traspaso Físico Controlado

1. **Montar el switch nuevo** en la unidad de rack libre inmediatamente debajo (o arriba) del switch viejo y encenderlo (aún sin cables de red conectados).
2. **Apagar la corriente del switch viejo** (para que no haya dos equipos con la misma IP `10.1.99.2` ni riesgo de bucle parcial mientras pasás los cables).
3. **Mover primero únicamente el enlace Uplink LACP (`Puertos 1 y 2`)** hacia el switch nuevo.
   - Desde el Router principal (`10.1.99.1`), limpiar la entrada ARP vieja (`/ip arp remove [find address=10.1.99.2]`) y hacer `ping 10.1.99.2`.
   - **¡El switch nuevo ya responde por SSH en `10.1.99.2` a través del LACP!**
4. **Mover el resto de los patchcords uno por uno (`Boca 4 → Boca 4`, `Boca 5 → Boca 5`, etc.)** verificando que cada LED enlace en verde/ámbar según corresponda.

### Fase 4 (T + 15 min): Foto Post-Check y Validación contra la Fase 2

```text
# En el Switch Nuevo (MikroTik CRS326):
/interface print where running
/interface bonding monitor bond1 once
/interface bridge port print
/interface bridge host print count-only
/ip neighbor print
```

---

## 🧯 Mitigación y Rollback

### Problema frecuente durante la Fase 3: El Router no responde al ping de la IP `10.1.99.2` del switch nuevo durante los primeros 4 minutos

- **Por qué ocurre:** El Router todavía tiene guardada en su **caché ARP** la dirección MAC del **switch Cisco viejo** para la IP `10.1.99.2`!
- **Solución en 1 segundo:** Hacer un ping desde el propio switch nuevo hacia el router (`/ping 10.1.99.1`) para que el router actualice su tabla ARP, o limpiar la entrada ARP de `10.1.99.2` en el router.

### Plan de Rollback Total (Si ocurre una falla de hardware imprevista en el switch nuevo)

1. Apagar el switch nuevo.
2. Volver a pasar los patchcords `Boca N → Boca N` al switch viejo que quedó montado en el rack.
3. Encender el switch viejo (en 90 segundos toda la planta vuelve exactamente al estado previo).

---

## ✅ Verificación post-mantenimiento

- [ ] La misma cantidad exacta de puertos que estaban `connected` en la Foto Pre-Check están hoy `Running (R)` en el switch nuevo.
- [ ] Todos los puertos del `bridge1` muestran el flag **`H` (*HW-OFFLOAD*)** activo y la CPU del switch está por debajo del **`5%`**.
- [ ] `SW-CORE-NUEVO` figura como `root-bridge: yes` (`Priority 0x1000 / 4096`).
- [ ] El servidor de monitoreo (SNMP / Syslog) y el script de Backup en Git ya leen al switch nuevo.

---

## 🔗 Referencias

- [`multivendor-cli-rosetta-stone`](../../reference/multivendor-cli-rosetta-stone.md) — La Piedra Rosetta para traducir comandos entre Cisco, MikroTik, Aruba y Linux
- [`mikrotik-bridge-vlan-filtering-deep-dive`](../../guides/06-mikrotik/mikrotik-bridge-vlan-filtering-deep-dive.md) — Cómo configurar un switch MikroTik CRS3xx con 100% Hardware Offload (`H`)
- [`lacp-etherchannel-bonding`](../../guides/02-switching-l2/lacp-etherchannel-bonding.md) — Traducción de EtherChannel (Cisco) ↔ Bonding (MikroTik) ↔ Trunk (Aruba)
