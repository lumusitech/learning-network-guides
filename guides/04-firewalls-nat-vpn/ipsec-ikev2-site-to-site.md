⬅️ [Volver a Guías](../README.md)

# Túneles IPsec IKEv2 Site-to-Site Multi-Vendor (MikroTik ↔ Cisco / Linux) — Guía práctica

**Dominio:** `04-firewalls-nat-vpn`
**Nivel:** 🔴 Avanzado
**Estándares:** `RFC 7296 (IKEv2)`, `RFC 4303 (ESP - Proto 50)`, `RFC 3948 (NAT-T UDP 4500)`, `AES-256-GCM / SHA256 / DH Group 14-20`
**Concepto base:** [`tcp-udp-mtu-and-nat-conntrack`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Ver estado de Fase 1 (Active Peers), Fase 2 (Installed SAs) y Políticas (PH2 State = established)
/ip ipsec active-peers print
/ip ipsec installed-sa print
/ip ipsec policy print

# Cisco IOS / IOS-XE: Ver estado de Fase 1 (IKEv2 SA = READY) y Fase 2 (IPsec SA encaps/decaps)
show crypto ikev2 sa
show crypto ipsec sa

# Linux (strongSwan — swanctl): Ver asociaciones de seguridad IKEv2 e IPsec activas
sudo swanctl --list-sas
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

Mientras que WireGuard es la opción ideal cuando vos controlás ambos extremos (MikroTik ↔ MikroTik / Linux), **IPsec con IKEv2 (`RFC 7296`)** es el **estándar corporativo universal** que te van a exigir siempre que tengas que levantar un túnel Site-to-Site contra un **Cisco ISR/ASA/Firepower, un FortiGate, un Palo Alto, un pfSense, AWS/Azure/GCP VPN Gateway o un socio comercial/bancario**.

Para configurar y diagnosticar IPsec entre dos marcas distintas sin frustrarte, solo tenés que entender que IPsec se negocia en **dos fases independientes** y que después requiere **una exención de NAT (*NAT Bypass*)**:

1. **Fase 1 (`IKEv2 SA` — `UDP 500` / `UDP 4500`):** Los dos routers se autentican entre sus IPs públicas y acuerdan un canal seguro de control.
2. **Fase 2 (`IPsec Child SA / ESP` — `Protocolo IP 50` o `UDP 4500`):** Dentro de ese canal, acuerdan las claves para cifrar los paquetes reales y verifican que coincidan exactamente los **Selectores de Tráfico (*Traffic Selectors / Policies*: `Subred Local ↔ Subred Remota`)**.
3. **El Paso 3 que el 80% olvida (*NAT Bypass*):** Como IPsec por políticas evalúa los paquetes **después** de la tabla `srcnat` (`POSTROUTING`), si no eximís al tráfico `10.1.0.0/16 → 10.2.0.0/16` de tu regla de `masquerade`, el router le cambia la IP origen a la IP pública WAN antes de llegar a IPsec y **el paquete se escapa a Internet sin entrar jamás al túnel**.

> **🧠 Recordatorio del modelo mental:** Pensá en **Fase 1 (IKEv2)** como **los dos gerentes de sucursal llamándose por teléfono para verificar sus contraseñas y ponerse de acuerdo en qué idioma hablar**. Pensá en **Fase 2 (IPsec ESP + Policy)** como **el contrato escrito que dice exactamente de qué depósito (`10.1.0.0/16`) a qué depósito (`10.2.0.0/16`) van los camiones blindados**. Y el **NAT Bypass** es avisarle al recepcionista de la puerta que a los paquetes que van a la otra sucursal **NO les pegue la etiqueta de correo público (Masquerade)**, porque si les cambia el remitente, el camión blindado de Fase 2 no los reconoce y los deja afuera.

---

## 2. 🗺️ Topología de referencia

Uniremos un router **MikroTik RouterOS v7 (`Sede 1: 203.0.113.2`)** con un router **Cisco IOS-XE o Linux strongSwan (`Sede 2: 198.51.100.2`)** usando parámetros criptográficos modernos recomendados en 2026 (`IKEv2`, `AES-256`, `SHA256`, `DH Group 14 / 2048-bit MODP`):

```text
+-----------------------------------+      Túnel IPsec IKEv2 (ESP / UDP 500,4500)     +-----------------------------------+
|      RTR-SEDE1 (MikroTik v7)      | ==============================================> |    RTR-SEDE2 (Cisco / strongSwan) |
|   WAN Pública: 203.0.113.2        |   Fase 1 (IKEv2): AES-256 + SHA256 + DH14 (8h)  |   WAN Pública: 198.51.100.2       |
|   Subred LAN:  10.1.0.0/16        |   Fase 2 (ESP):   AES-256 + SHA256 + PFS14 (1h) |   Subred LAN:  10.2.0.0/16        |
+-----------------------------------+   Traffic Selector: 10.1.0.0/16 <-> 10.2.0.0/16 +-----------------------------------+
```

| Parámetro IPsec (Debe ser IDÉNTICO en ambos lados!) | Valor en Fase 1 (`IKEv2 Profile`) | Valor en Fase 2 (`IPsec Proposal`) |
|-----------------------------------------------------|-----------------------------------|------------------------------------|
| **Versión del protocolo** | **`IKEv2`** (`exchange-mode=ike2`) | **`ESP`** (Cifrado en modo Túnel) |
| **Algoritmo de Cifrado (*Encryption*)** | **`aes-256-cbc`** (o `aes-256-gcm`) | **`aes-256-cbc`** (o `aes-256-gcm`) |
| **Algoritmo de Integridad / Hash** | **`sha256`** | **`sha256`** |
| **Grupo Diffie-Hellman (DH / PFS Group)** | **`modp2048` (`DH Group 14`)** | **`modp2048` (`PFS Group 14`)** |
| **Tiempo de vida de claves (*Lifetime*)** | `8 horas` (`28800s`) | `1 hora` (`3600s`) |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. Lado 1: MikroTik RouterOS v7 (`RTR-SEDE1` — `203.0.113.2`)

```text
# 1. PERMITIR IPSEC EN LA CADENA INPUT DEL FIREWALL (UDP 500, UDP 4500 y Protocolo IP 50 ESP):
/ip firewall filter
add chain=input protocol=udp dst-port=500,4500 action=accept place-before=[find action=drop] comment="Permitir IKEv2 UDP 500/4500"
add chain=input protocol=ipsec-esp action=accept place-before=[find action=drop] comment="Permitir IPsec ESP (Proto 50)"

# 2. PASO CRÍTICO (NAT BYPASS + FASTTRACK BYPASS):
#    Eximir al tráfico entre 10.1.0.0/16 y 10.2.0.0/16 TANTO del Masquerade COMO del FastTrack!
#    (Si un paquete entra en FastTrack o en Masquerade, saltea el motor de Políticas IPsec!):
/ip firewall nat
add chain=srcnat src-address=10.1.0.0/16 dst-address=10.2.0.0/16 action=accept place-before=0 comment="0. NAT Bypass obligatorio para IPsec"

/ip firewall raw
add chain=prerouting src-address=10.1.0.0/16 dst-address=10.2.0.0/16 action= accept comment="Opcional: o excluir de FastTrack en filter forward"
/ip firewall filter
add chain=forward ipsec-policy=in,ipsec action=accept place-before=[find action=fasttrack-connection] comment="Permitir entrada IPsec antes de FastTrack"
add chain=forward ipsec-policy=out,ipsec action=accept place-before=[find action=fasttrack-connection] comment="Permitir salida IPsec antes de FastTrack"

# 3. FASE 1 (Profile, Peer e Identity):
/ip ipsec profile
add name=perfil-ikev2-sede2 hash-algorithm=sha256 enc-algorithm=aes-256 dh-group=modp2048 lifetime=8h dpd-interval=10s dpd-maximum-failures=3

/ip ipsec peer
add name=peer-sede2 address=198.51.100.2/32 local-address=203.0.113.2 profile=perfil-ikev2-sede2 exchange-mode=ike2

/ip ipsec identity
add peer=peer-sede2 auth-method=pre-shared-key secret="ClaveCompartidaIPsecMuyLarga!2026"

# 4. FASE 2 (Proposal y Policy / Traffic Selector):
/ip ipsec proposal
add name=propuesta-esp-sede2 auth-algorithms=sha256 enc-algorithms=aes-256-cbc lifetime=1h pfs-group=modp2048

/ip ipsec policy
add peer=peer-sede2 tunnel=yes src-address=10.1.0.0/16 dst-address=10.2.0.0/16 proposal=propuesta-esp-sede2 action=encrypt

# 5. Ajuste de TCP MSS para evitar fragmentación en los paquetes que entran/salen de IPsec (MTU efectivo ~1400 -> MSS 1360):
/ip firewall mangle
add chain=forward ipsec-policy=out,ipsec protocol=tcp tcp-flags=syn tcp-mss=1361-65535 action=change-mss new-mss=1360
add chain=forward ipsec-policy=in,ipsec  protocol=tcp tcp-flags=syn tcp-mss=1361-65535 action=change-mss new-mss=1360
```

---

### B. Lado 2 (Opción Cisco): Cisco IOS-XE (`RTR-SEDE2` — `198.51.100.2`)

```cisco
configure terminal

! 1. FASE 1: Propuesta, Política, Keyring y Perfil IKEv2 (AES-256, SHA256, DH Group 14)
crypto ikev2 proposal IKEV2-PROP-SEDE1
 encryption aes-cbc-256
 integrity sha256
 group 14
exit

crypto ikev2 policy IKEV2-POL-SEDE1
 proposal IKEV2-PROP-SEDE1
exit

crypto ikev2 keyring KR-SEDE1
 peer RTR-SEDE1-MIKROTIK
  address 203.0.113.2
  pre-shared-key ClaveCompartidaIPsecMuyLarga!2026
 exit
exit

crypto ikev2 profile IKEV2-PROF-SEDE1
 match identity remote address 203.0.113.2 255.255.255.255
 identity local address 198.51.100.2
 authentication remote pre-shared
 authentication local pre-shared
 keyring local KR-SEDE1
 lifetime 28800
 dpd 10 3 on-demand
exit

! 2. FASE 2: Transform-Set ESP, ACL del Selector de Tráfico (espejada: 10.2.0.0/16 -> 10.1.0.0/16!) y Crypto Map
crypto ipsec transform-set TS-ESP-SEDE1 esp-aes 256 esp-sha256-hmac
 mode tunnel
exit

ip access-list extended ACL-CRYPTO-SEDE1
 permit ip 10.2.0.0 0.0.255.255 10.1.0.0 0.0.255.255
exit

crypto map CMAP-WAN 10 ipsec-isakmp
 set peer 203.0.113.2
 set transform-set TS-ESP-SEDE1
 set pfs group14
 set security-association lifetime seconds 3600
 set ikev2-profile IKEV2-PROF-SEDE1
 match address ACL-CRYPTO-SEDE1
exit

! 3. Aplicar el Crypto Map a la interfaz WAN (y recordar excluir 10.2.0.0/16 -> 10.1.0.0/16 en la ACL de NAT!)
interface GigabitEthernet0/0
 crypto map CMAP-WAN
exit

end
write memory
```

---

### C. Lado 2 (Opción Linux): `strongSwan` moderno (`swanctl.conf` en `RTR-SEDE2`)

```bash
# 1. Instalar strongSwan con swanctl
sudo apt install -y strongswan strongswan-swanctl charon-systemd

# 2. Configurar /etc/swanctl/conf.d/sede1.conf
cat << 'EOF' | sudo tee /etc/swanctl/conf.d/sede1.conf
connections {
    sede2-to-sede1 {
        version = 2
        local_addrs = 198.51.100.2
        remote_addrs = 203.0.113.2
        proposals = aes256-sha256-modp2048
        rekey_time = 28800s
        dpd_delay = 10s

        local {
            auth = psk
            id = 198.51.100.2
        }
        remote {
            auth = psk
            id = 203.0.113.2
        }
        children {
            net-sede1 {
                local_ts = 10.2.0.0/16
                remote_ts = 10.1.0.0/16
                esp_proposals = aes256-sha256-modp2048
                rekey_time = 3600s
                start_action = trap|start
            }
        }
    }
}
secrets {
    ike-sede1 {
        id-sede1 = 203.0.113.2
        secret = "ClaveCompartidaIPsecMuyLarga!2026"
    }
}
EOF

sudo swanctl --load-all
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/ip ipsec active-peers print` y `/ip ipsec policy print`)

```text
[netops@RTR-SEDE1] > /ip ipsec active-peers print
Columns: ID, STATE, UPTIME, PH2-TOTAL, REMOTE-ADDRESS
# ID            STATE        UPTIME    PH2-TOTAL  REMOTE-ADDRESS
0 198.51.100.2  established  4d12h10m          1  198.51.100.2

[netops@RTR-SEDE1] > /ip ipsec policy print
Flags: T - TEMPLATE; A - ACTIVE, * - DEFAULT
Columns: PEER, TUNNEL, SRC-ADDRESS, DST-ADDRESS, ACTION, PH2-STATE
#   PEER        TUNNEL  SRC-ADDRESS  DST-ADDRESS  ACTION   PH2-STATE
0 *                     ::/0         ::/0         encrypt
1 A peer-sede2  yes     10.1.0.0/16  10.2.0.0/16  encrypt  established
```

### Tabla de interpretación de Estados en Fase 1 y Fase 2

| Dónde mirar | Estado Sano | Estado Roto | Qué significa y qué revisar exactamente |
|-------------|:-----------:|:-----------:|-----------------------------------------|
| **Fase 1 (`active-peers: STATE`)** | **`established`** (Cisco: `READY`) | `msg1-sent` o desaparece | **`msg1-sent`**: El paquete `UDP 500` sale pero nadie contesta (IP remota mal o firewall remoto bloquea `UDP 500/4500`). **Error de autenticación**: la `secret` (PSK) o el algoritmo de Fase 1 (`AES/SHA/DH14`) no coincide |
| **Fase 2 (`policy: PH2-STATE`)** | **`established`** y `PH2-TOTAL: 1` | `no-phase2` o `larval` | **La Fase 1 levantó bien, pero la Fase 2 fue rechazada (`TS_UNACCEPTABLE` o `NO_PROPOSAL_CHOSEN`):** no coinciden las subredes exactas (`10.1.0.0/16` vs `10.1.10.0/24`) o no coincide el `pfs-group=modp2048` |
| **Contadores en `/ip ipsec installed-sa print`** | `current-bytes` sube en **ambas** filas (In y Out) | Sube solo en la SA de Salida (`Out`), pero la SA de Entrada (`In`) marca **`0 bytes`** | Tus paquetes cifrados salen en `ESP (Protocolo IP 50)`, pero las respuestas cifradas quedan bloqueadas en el camino o en tu propia cadena `INPUT` (falta permitir `protocol=ipsec-esp` o `UDP 4500`) |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: En MikroTik tanto Fase 1 como Fase 2 dicen `established`, pero hacés ping desde una PC de la Sede 1 a una PC de la Sede 2 y da Timeout

1. **Las 2 causas responsables del 99% de este síntoma:**
   1. **Falta el NAT Bypass en el puesto #0 de `/ip firewall nat`:** Mirá el contador de paquetes de la regla `chain=srcnat src-address=10.1.0.0/16 dst-address=10.2.0.0/16 action=accept`. Si no existe o si está **debajo** de la regla de `masquerade`, tu router le está cambiando la IP origen `10.1.10.50` por la IP pública `203.0.113.2` antes de que la Política IPsec vea el paquete!
   2. **El paquete está entrando en `FastTrack`:** Los paquetes marcados con `action=fasttrack-connection` en `forward` saltean el motor de encriptación IPsec. Asegurate de tener las dos reglas `ipsec-policy=in,ipsec` e `ipsec-policy=out,ipsec` con `action=accept` colocadas **arriba** de la regla de `fasttrack-connection`.

### Síntoma 2: Cuando hacés ping desde la consola del propio Router MikroTik (`/ping 10.2.10.1`) no pasa por el túnel, pero desde las PCs de la oficina sí pasa

1. **Por qué ocurre:** Cuando ejecutás `/ping 10.2.10.1` desde la consola del router sin indicar dirección de origen, el router elige como IP origen de su paquete su **IP Pública WAN (`203.0.113.2`)** porque la ruta hacia `10.2.10.1` sale por la tabla general. Como `203.0.113.2` no forma parte del selector `src-address=10.1.0.0/16` de la Política IPsec, el ping no entra al túnel.
2. **Cómo probar desde la consola del router:** Especificá siempre la IP LAN interna del router como origen: **`/ping 10.2.10.1 src-address=10.1.10.1`**.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Cómo reiniciar un túnel IPsec trabado sin reiniciar el router ni cortar otros túneles:**
  - En MikroTik: `/ip ipsec active-peers kill-connections` (o deshabilitar y habilitar solo ese peer).
  - En Cisco: `clear crypto ikev2 sa remote 203.0.113.2` y `clear crypto ipsec sa peer 203.0.113.2`.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Seguir usando `IKEv1` (`main mode / aggressive mode`), `3DES`, `MD5`, `SHA1` o `DH Group 2 (modp1024)`:** Todos esos algoritmos están criptográficamente obsoletos y muchos sistemas modernos (strongSwan en Debian 12/Ubuntu 24.04 y Cisco IOS-XE 17.x) los traen deshabilitados por defecto. Estandarizá siempre en **`IKEv2` + `AES-256` + `SHA256` + `DH Group 14 (modp2048)` o `Group 19/20 (ECP)`**.
- **❌ Poner `src-address=10.1.0.0/16` en un lado y `10.1.10.0/24` en el otro:** En IPsec basado en políticas, los **Traffic Selectors deben ser un espejo exacto (`A → B` en el Lado 1 y `B → A` con la misma máscara exacta en el Lado 2)**. Si de un lado ponés `/16` y del otro lado ponés tres políticas `/24`, la Fase 2 fallará con `TS_UNACCEPTABLE`.

---

## 8. ✅ Buenas prácticas profesionales

- **Configurar siempre `level=unique` en `/ip ipsec policy` cuando tenés múltiples subredes o políticas hacia el mismo Peer:** En MikroTik, si creás dos políticas distintas hacia el mismo peer (ej. `10.1.10.0/24 → 10.2.10.0/24` y `10.1.40.0/24 → 10.2.40.0/24`), cambiá el parámetro `level=require` (por defecto) a **`level=unique`** en cada política para que cada par de subredes negocie su propia Child SA independiente sin pisarse con la otra.

---

## 9. 🔗 Referencias internas

- [`wireguard-site-to-site-and-roadwarrior`](wireguard-site-to-site-and-roadwarrior.md) — Cuándo elegir WireGuard (interfaz enrutable nativa) frente a IPsec IKEv2
- [`nat-masquerade-dnat-and-hairpin`](nat-masquerade-dnat-and-hairpin.md) — Dónde se ubica la regla #0 de *NAT Bypass* en la tabla `srcnat`
- [`network-ports-protocols-and-multicast`](../../reference/network-ports-protocols-and-multicast.md) — Puertos `UDP 500` (IKE), `UDP 4500` (NAT-T) y Protocolo IP `50` (`ESP`)
