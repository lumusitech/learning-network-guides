⬅️ [Volver a Referencias](README.md)

# 🧠 Active Recall — Flashcards y Desafíos de Guardia para NetOps

**Alcance:** `Capas 1 a 7` | `Cisco IOS / Catalyst` · `MikroTik RouterOS v7` · `Aruba / HP ProCurve` · `Linux (iproute2 / bridge / FRR)`

---

## 🎯 Cómo usar esta referencia

Esto no es lectura pasiva: es un **gimnasio de memoria muscular**. En cada tarjeta vas a ver un desafío y, recién cuando hayas pensado la respuesta (o la hayas escrito en un papel), desplegás el bloque **👀 Ver solución explicada** para comparar. Si fallás, la respuesta te marca la sección del repositorio donde repasar. Cubrí la respuesta con la mano las primeras veces: el objetivo es **recordar bajo presión**, como en una guardia real.

Todos los comandos salen de [`multivendor-cli-rosetta-stone.md`](multivendor-cli-rosetta-stone.md), así que si dudás de una traducción, esa tabla es la fuente autoritativa.

---

## 🃏 Mazo 1 — Traducción en 5 segundos (Cisco ↔ MikroTik v7 ↔ Aruba ↔ Linux)

**1. ¿Cómo listás la tabla de direcciones MAC aprendidas por el switch en los cuatro ecosistemas?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show mac address-table`
- **MikroTik RouterOS v7:** `/interface bridge host print`
- **Aruba / HP ProCurve:** `show mac-address`
- **Linux (`bridge`):** `bridge fdb show`

*Por qué importa:* en 2 segundos confirmás en qué puerto aprendió cada MAC y detectás duplicados o flapping.

</details>

**2. ¿Qué comando te muestra los puertos Trunk y su Native VLAN / PVID en cada fabricante?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show interfaces trunk`
- **MikroTik RouterOS v7:** `/interface bridge port print`
- **Aruba / HP ProCurve:** `show vlans ports 1-24 detail`
- **Linux (`bridge`):** `bridge vlan show`

*Por qué importa:* un PVID desalineado entre los dos extremos de un trunk es la causa #1 de "la VLAN no llega".

</details>

**3. ¿Cómo ves los vecinos OSPF y su estado de adyacencia en cada marca?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show ip ospf neighbor`
- **MikroTik RouterOS v7:** `/routing ospf neighbor print`
- **Aruba / HP ProCurve:** `show ip ospf neighbor`
- **Linux (`vtysh` FRR):** `vtysh -c "show ip ospf neighbor"`

*Por qué importa:* `FULL` es sano; `ExStart`, `Exchange` o `Init` trabados apuntan a MTU o tipo de red.

</details>

**4. ¿Cómo leer la tabla de rutas (RIB) en cada sistema?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show ip route`
- **MikroTik RouterOS v7:** `/ip route print`
- **Aruba / HP ProCurve:** `show ip route`
- **Linux (`iproute2`):** `ip route show`

*Por qué importa:* mirá la máscara (Longest Prefix Match) y la distancia administrativa antes de culpar al proveedor.

</details>

**5. ¿Cómo descubrís los equipos vecinos con LLDP / CDP / MNDP?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show cdp neighbors detail` / `show lldp neighbors`
- **MikroTik RouterOS v7:** `/ip neighbor print detail`
- **Aruba / HP ProCurve:** `show lldp info remote-device`
- **Linux:** `lldpcli show neighbors`

*Por qué importa:* es el primer comando al llegar a un rack ajeno: te dice qué está conectado a cada puerto sin tocar nada.

</details>

**6. ¿Cómo resumís el estado de todas las interfaces de un equipo?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show interfaces status`
- **MikroTik RouterOS v7:** `/interface print`
- **Aruba / HP ProCurve:** `show interfaces brief`
- **Linux:** `ip -br link show`

*Por qué importa:* detectás de un pantallazo puertos caídos, en velocidad degradada o `err-disabled`.

</details>

**7. ¿Cómo verificás velocidad, duplex y estado real del enlace de una interfaz?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show interfaces Gi1/0/1`
- **MikroTik RouterOS v7:** `/interface ethernet monitor ether1 once`
- **Aruba / HP ProCurve:** `show interfaces 1`
- **Linux:** `ethtool eth0`

*Por qué importa:* un dúplex a media asta (half-duplex) genera colisiones y lentitud sin caer el link.

</details>

**8. ¿Cómo revisás contadores de errores físicos (CRC / FCS / drops)?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show interfaces Gi1/0/1 counters errors`
- **MikroTik RouterOS v7:** `/interface ethernet print stats where name=ether1`
- **Aruba / HP ProCurve:** `show interfaces 1`
- **Linux:** `ip -s link show eth0` / `ethtool -S eth0`

*Por qué importa:* CRC en aumento = cable/ficha/óptica dañada, no un problema de configuración L3.

</details>

**9. ¿Cómo medís los niveles ópticos de un SFP (DDM/DOM en dBm)?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show interfaces Gi1/0/25 transceiver detail`
- **MikroTik RouterOS v7:** `/interface ethernet monitor sfp-sfpplus1 once`
- **Aruba / HP ProCurve:** `show interfaces transceiver 25 detail`
- **Linux:** `ethtool -m eth0`

*Por qué importa:* si el `Rx Power` baja de la sensibilidad del módulo, aparecen intermitencias antes de que el link caiga.

</details>

**10. ¿Cómo corrés un test de cable UTP integrado (TDR)?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `test cable-diagnostics tdr interface Gi1/0/1`
- **MikroTik RouterOS v7:** `/interface ethernet cable-test ether1`
- **Aruba / HP ProCurve:** `test cable-diagnostics 1`
- **Linux:** `ethtool --cable-test eth0`

*Por qué importa:* te dice a cuántos metros está el corte y en qué par, sin ir físicamente al cable.

</details>

**11. ¿Cómo ves el consumo y el presupuesto PoE del switch?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show power inline`
- **MikroTik RouterOS v7:** `/interface ethernet poe monitor ether1`
- **Aruba / HP ProCurve:** `show power-over-ethernet brief`
- **Linux (SNMP):** OID `1.3.6.1.2.1.105` (`pethPsePortTable`)

*Por qué importa:* presupuesto agotado = cámaras que reinician de noche cuando se encienden las luces.

</details>

**12. ¿Cómo revisás el estado de Spanning Tree en cada plataforma?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show spanning-tree`
- **MikroTik RouterOS v7:** `/interface bridge monitor bridge1`
- **Aruba / HP ProCurve:** `show spanning-tree`
- **Linux:** `bridge link show` (o `mstpd`)

*Por qué importa:* confirmás quién es Root Bridge y qué puertos están en `Blocking`/`Discarding`.

</details>

**13. ¿Cómo ves el estado de una agregación LACP (802.3ad)?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show etherchannel summary`
- **MikroTik RouterOS v7:** `/interface bonding monitor bond1`
- **Aruba / HP ProCurve:** `show trunks` / `show lacp`
- **Linux:** `cat /proc/net/bonding/bond0`

*Por qué importa:* un miembro `(I)` (individual) no está negociando LACP y puede provocar un bucle.

</details>

**14. ¿Cómo consultás la tabla ARP (IP ↔ MAC)?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show ip arp`
- **MikroTik RouterOS v7:** `/ip arp print`
- **Aruba / HP ProCurve:** `show arp`
- **Linux:** `ip neigh show`

*Por qué importa:* entradas duplicadas o incompletas (`incomplete`/`failed`) revelan conflictos de IP o bucles L2.

</details>

**15. ¿Cómo le preguntás al router por dónde sacaría un paquete hacia un destino concreto?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show ip route 10.0.40.10`
- **MikroTik RouterOS v7:** `/ip route check 10.0.40.10`
- **Aruba / HP ProCurve:** `show ip route 10.0.40.10`
- **Linux:** `ip route get 10.0.40.10`

*Por qué importa:* resuelve de una el "¿por qué este tráfico sale por la WAN de respaldo y no por la principal?".

</details>

**16. ¿Cómo agregás una ruta estática hacia `10.0.50.0/24` vía `10.0.1.2`?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `ip route 10.0.50.0 255.255.255.0 10.0.1.2`
- **MikroTik RouterOS v7:** `/ip route add dst-address=10.0.50.0/24 gateway=10.0.1.2`
- **Aruba / HP ProCurve:** `ip route 10.0.50.0/24 10.0.1.2`
- **Linux:** `ip route add 10.0.50.0/24 via 10.0.1.2`

*Por qué importa:* en Cisco la máscara es decimal; en el resto se usa notación CIDR.

</details>

**17. ¿Cómo revisás las reglas de firewall y sus contadores de paquetes?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show access-lists`
- **MikroTik RouterOS v7:** `/ip firewall filter print stats`
- **Linux (`nftables`):** `nft list ruleset` / `iptables -L -v -n`

*Por qué importa:* los contadores en `0` te dicen que el tráfico ni siquiera llega a esa regla (orden mal puesto).

</details>

**18. ¿Cómo inspeccionás la tabla de conexiones activas (Conntrack)?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS (NAT):** `show ip nat translations`
- **MikroTik RouterOS v7:** `/ip firewall connection print`
- **Linux (`conntrack`):** `conntrack -L` / `ss -tan`

*Por qué importa:* estados `INVALID` o `SYN_SENT` colgados explican drops silenciosos en enrutamiento asimétrico.

</details>

**19. ¿Cómo ves el estado de redundancia VRRP / HSRP?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `show standby brief` / `show vrrp brief`
- **MikroTik RouterOS v7:** `/interface vrrp print`
- **Aruba / HP ProCurve:** `show vrrp`
- **Linux:** `ip addr show` (servicio `keepalived`)

*Por qué importa:* dos equipos en `MASTER` al mismo tiempo = split-brain y una IP de gateway duplicada en la LAN.

</details>

**20. ¿Cómo exportás el backup legible en texto para versionarlo en Git?**

<details>
<summary>👀 Ver solución explicada</summary>

- **Cisco IOS:** `copy running-config scp://usuario@servidor/backup`
- **MikroTik RouterOS v7:** `/export show-sensitive file=backup` (genera `.rsc`)
- **Aruba / HP ProCurve:** `copy running-config tftp/scp`
- **Linux:** `tar czf etc-net.tgz /etc/netplan /etc/frr`

*Por qué importa:* un backup en texto plano y versionado es tu red de seguridad ante un cambio fallido.

</details>

---

## 🃏 Mazo 2 — Encontrá el bug en esta salida de consola

**1. ¿Qué está roto y por qué?**

```text
Switch# show interfaces status
Port      Name   Status       Vlan   Duplex  Speed Type
Gi1/0/1          connected    10     a-full  a-1000 10/100/1000BaseTX
Gi1/0/2          err-disabled 10     auto    auto   10/100/1000BaseTX
Gi1/0/3          connected    20     a-full  a-1000 10/100/1000BaseTX
```

<details>
<summary>👀 Ver solución explicada</summary>

El puerto `Gi1/0/2` está **`err-disabled`**: una protección de Capa 2 lo apagó, casi siempre **BPDU Guard** (llegó un BPDU por un puerto con PortFast/Edge, suele ser un switch doméstico o un router mal conectado). Diagnosticá con `show interfaces status err-disabled`. Se recupera corrigiendo la causa y haciendo `shutdown` + `no shutdown`.

</details>

**2. ¿Qué significa esa `(I)` y qué riesgo trae?**

```text
Switch# show etherchannel summary
Group  Port-channel  Protocol  Ports
------+-------------+---------+----------------------------------------
1      Po1(SU)         LACP    Gi1/0/1(P)  Gi1/0/2(I)
```

<details>
<summary>👀 Ver solución explicada</summary>

`Gi1/0/2(I)` = **Individual / Stand-alone**: ese miembro **no** negoció LACP con el vecino y quedó fuera del bundle. El tráfico igual puede circular por él, así que si no está protegido por STP puede formar un **bucle L2**. Revisá la config del switch del otro extremo (modo LACP, velocidad/duplex/VLAN consistentes).

</details>

**3. Todas las VLAN muestran prioridad `32768`. ¿Está bien?**

```text
Switch# show spanning-tree
VLAN0001
  Spanning tree enabled protocol rstp
  Root ID    Priority    32769
             Address     0050.56AA.BB01
  Bridge ID  Priority    32769  (priority 32768 sys-id-ext 1)
```

<details>
<summary>👀 Ver solución explicada</summary>

No. Con **todos** los switches en la prioridad por defecto (`32768`, +1 de system-id-extension), el Root Bridge se elige por **la MAC más baja**, lo cual es impredecible y puede dejar el root en un switch de acceso de baja calidad. Fijá el core explícitamente (ej. `spanning-tree vlan 1 priority 4096`).

</details>

**4. La vecindad OSPF quedó trabada. ¿Cuál es la causa más probable?**

```text
MikroTik> /routing ospf neighbor print
 0 address=10.0.0.1 router-id=1.1.1.1 state=ExStart
```

<details>
<summary>👀 Ver solución explicada</summary>

`ExStart` trabado es el síntoma clásico de **MTU distinta** entre los dos extremos: los paquetes DBD (Database Description) se descartan por tamaño y la negociación no avanza. Alineá el MTU en ambas interfaces (ej. `1500`) o habilitá el "ignore MTU" donde el fabricante lo permita.

</details>

**5. El vecino OSPF aparece en `Init`. ¿Qué mirás?**

```text
MikroTik> /routing ospf neighbor print
 0 address=10.0.0.5 router-id=5.5.5.5 state=Init
```

<details>
<summary>👀 Ver solución explicada</summary>

`Init` significa que **nosotros escuchamos sus Hello, pero él no escucha los nuestros** (adyacencia unidireccional). Causas típicas: **tipo de red OSPF distinto** (`point-to-point` vs `broadcast`), un ACL/firewall que filtra el multicast `224.0.0.5`, o una VLAN que no llega en un sentido del trunk.

</details>

**6. La ruta a `10.9.0.0/24` existe pero no está activa. ¿Por qué?**

```text
MikroTik> /ip route print
Flags: X - disabled, A - active, D - dynamic, C - connect, S - static
 #      DST-ADDRESS      PREF-SRC    GATEWAY         DISTANCE
 0 A S  0.0.0.0/0                    203.0.113.1     1
 1  DS  10.1.10.0/24    10.1.10.1   ether2          0
 2   S  10.9.0.0/24                 192.168.99.1    1
```

<details>
<summary>👀 Ver solución explicada</summary>

A la fila `2` le **falta el flag `A` (active)**: el gateway `192.168.99.1` es **inalcanzable** porque no hay ninguna ruta hacia `192.168.99.0/24`. RouterOS no puede resolver el next-hop y descarta la ruta. Solución: corregir la IP del gateway o agregar la ruta hacia la red del gateway.

</details>

**7. Un puerto del bridge no muestra la flag `H`. ¿Qué implica?**

```text
MikroTik> /interface bridge port print
Flags: X - disabled, I - inactive, D - dynamic, H - hw-offload
 #   INTERFACE   BRIDGE    PVID
 0 H ether2      bridge1   10
 1   ether3      bridge1   20
```

<details>
<summary>👀 Ver solución explicada</summary>

Sin la flag **`H` (hw-offload)**, `ether3` se conmuta por **software/CPU** en lugar del switch-chip. No es que el tráfico se caiga, pero el rendimiento baja muchísimo y la CPU sube. Suele pasar cuando una función incompatible (cierto feature de `vlan-filtering`, bonding o un puerto de otro tipo) desactiva el offload. Verificá con `/interface bridge port print detail`.

</details>

**8. La VLAN 40 no aparece en el bridge. ¿Qué pasa?**

```text
MikroTik> /interface bridge vlan print
Flags: D - dynamic, X - disabled
 #   VLAN-IDS   CURRENT-TAGGED     CURRENT-UNTAGGED
 0   10         ether1             ether2
 1   20         ether1
```

<details>
<summary>👀 Ver solución explicada</summary>

Falta declarar la **VLAN 40**. Aunque el trunk `ether1` la transporte físicamente, RouterOS con **Bridge VLAN Filtering** solo etiqueta/reenvía las VLAN declaradas en `/interface bridge vlan`. Solución: `/interface bridge vlan add vlan-ids=40 tagged=ether1`. Sin eso, los hosts de la VLAN 40 quedan incomunicados.

</details>

**9. ¿Está bien este failover de doble WAN?**

```text
Router# show ip route
S*   0.0.0.0/0 [1/0] via 203.0.113.1
S*   0.0.0.0/0 [1/0] via 198.51.100.1
```

<details>
<summary>👀 Ver solución explicada</summary>

Dudoso. Con **la misma distancia administrativa (1)**, el router instala **ambas** como default (ECMP) y repartirá el tráfico, incluso por el enlace de respaldo. Para un failover real, la ruta de backup debe tener **AD mayor** (ej. **250**) para ser *flotante*. Mejor aún: combinarla con *tracking* para que caiga cuando el ISP muere aguas arriba, no solo cuando el cable cae.

</details>

**10. El tráfico toma el enlace lento. ¿Qué mirás?**

```text
Router# show ip ospf interface Gi1/0/5
  Cost: 100
Router# show ip ospf interface Gi1/0/6
  Cost: 10
```

<details>
<summary>👀 Ver solución explicada</summary>

`Gi1/0/5` parece el enlace **rápido** (Gigabit), pero tiene **costo 100** manual, mientras que `Gi1/0/6` (¿Fast Ethernet?) quedó en 10. OSPF elige el **costo total más bajo**, así que manda todo por el enlace lento. Revisá overrides con `show ip ospf interface` y quitá el costo manual (`no ip ospf cost`).

</details>

**11. Desde la oficina no abre el servidor por su IP pública, pero desde afuera sí. ¿Qué falta?**

```text
# Desde Internet:
$ curl -m 3 http://203.0.113.2:8080
<h1>Servidor ERP Interno</h1>

# Desde la PC interna (10.1.40.50):
$ curl -m 3 http://203.0.113.2:8080
curl: (28) Connection timed out
```

<details>
<summary>👀 Ver solución explicada</summary>

Falta **Hairpin NAT (NAT loopback / U-turn)**. El DNAT reescribe el destino a `10.1.40.10`, pero el servidor responde directo a `10.1.40.50` con origen `10.1.40.10`, así que la PC descarta la respuesta como "no solicitada". Se arregla con una regla `srcnat`/`MASQUERADE` para el tráfico `10.1.40.0/24 → 10.1.40.10` en el puerto 8080.

</details>

**12. Las páginas chicas cargan, las descargas grandes se congelan. ¿Qué está pasando?**

```text
$ ping -M do -s 1400 8.8.8.8        # -> responde OK
$ ping -M do -s 1472 8.8.8.8        # -> 100% packet loss
$ curl -m 3 https://example.com/archivo-grande.iso
# -> se congela a mitad de descarga
```

<details>
<summary>👀 Ver solución explicada</summary>

Es un **agujero negro de MTU** (PMTUD bloqueado). El enlace real es menor a 1500 (típico **PPPoE = 1492**) y los paquetes grandes con DF se descartan en silencio. Sin **TCP MSS Clamping** en el firewall, las conexiones se estancan. Solución: clamp del MSS (ej. `1452`) y/o bajar el MTU de la interfaz WAN.

</details>

**13. La Simple Queue está en `0 bps`. ¿Por qué no limita?**

```text
MikroTik> /queue simple print stats
 #   NAME        TARGET         MAX-LIMIT     RATE         BYTES
 0   limite-nas  10.1.10.0/24   20M/20M       0bps/0bps    0
```

<details>
<summary>👀 Ver solución explicada</summary>

Casi siempre es **FastTrack**: la regla de `/ip firewall filter` con `action=fasttrack-connection` **saltea las colas** y los contadores quedan en `0`. Además, revisá que el `TARGET` coincida con el origen real del tráfico. Si necesitás shaping fino, usá **Queue Tree + Mangle** en lugar de Simple Queues con FastTrack activo.

</details>

**14. Una notebook se quedó sin IP. ¿Cuál es la causa más probable?**

```text
C:\> ipconfig
  IPv4 Address . . . . . . : 169.254.14.22
  Subnet Mask  . . . . . . : 255.255.0.0
```

<details>
<summary>👀 Ver solución explicada</summary>

`169.254.x.x` es **APIPA** (`RFC 3927`): la PC se autoasignó una IP porque **nunca llegó la respuesta DHCP**. En un SSID con VLAN, la causa #1 es que esa **VLAN no está permitida en el trunk del AP**, o que **DHCP Snooping** marcó el puerto como no confiable, o que no hay servidor DHCP en esa VLAN. Revisá las VLAN permitidas del trunk.

</details>

**15. Acabás de perder 200 usuarios en VLAN 10 y 20. ¿Qué comando causó esto?**

```text
Switch(config-if)# switchport trunk allowed vlan 50
```

<details>
<summary>👀 Ver solución explicada</summary>

Sin la palabra **`add`**, el comando **reemplaza** toda la lista de VLANs permitidas y deja **solo la 50**: las VLAN 10 y 20 se cayeron. Correcto: `switchport trunk allowed vlan add 50`. Es una de las trampas de guardia más dolorosas.

</details>

**16. Estos mensajes repetidos en el log delatan algo grave. ¿Qué es?**

```text
%MAC_MOVE: Host 00:11:22:33:44:55 moved from Gi1/0/2 to Gi1/0/3
%MAC_MOVE: Host 00:11:22:33:44:55 moved from Gi1/0/3 to Gi1/0/2
%MAC_MOVE: Host 00:11:22:33:44:55 moved from Gi1/0/2 to Gi1/0/3
```

<details>
<summary>👀 Ver solución explicada</summary>

**Flapping de MAC** causado por un **bucle de Capa 2**, una MAC duplicada o un switch pirata. La misma MAC aparece alternando puertos cientos de veces por segundo → CPU al 100% y tormenta de broadcast. Revisá STP, conectá BPDU Guard en los accesos y buscá el cable en bucle.

</details>

**17. El log de conntrack muestra un problema en la red interna. ¿Cuál?**

```text
$ conntrack -L | grep 10.0.50.10
tcp 6 431995 ESTABLISHED src=10.0.50.10 dst=10.0.50.1 sport=51514 dport=22 [UNREPLIED]
```

<details>
<summary>👀 Ver solución explicada</summary>

Una conexión con estado **`[UNREPLIED]`** significa que salió el SYN pero **no volvió nada**: no hubo respuesta. Junto a un `INVALID` en el firewall, es la firma del **enrutamiento asimétrico**: la ida sale por un router y la vuelta por otro, y el firewall que no vio el handshake la descarta. Unificá la simetría del tráfico.

</details>

**18. El diagrama de Hairpin funciona desde afuera pero el usuario interno ve timeouts. ¿Qué regla revisás?**

```text
MikroTik> /ip firewall nat print
 0    ;;; masquerade WAN
     chain=srcnat out-interface=ether1 action=masquerade
 1    ;;; DNAT web
     chain=dstnat dst-address=203.0.113.2 dst-port=8080 protocol=tcp action=dst-nat to-addresses=10.1.40.10
```

<details>
<summary>👀 Ver solución explicada</summary>

Solo hay **masquerade hacia la WAN** (`out-interface=ether1`) y el DNAT; **falta la regla de Hairpin** para el tráfico que **no sale a Internet**. Agregá antes una regla `srcnat` con `src-address=10.1.40.0/24 dst-address=10.1.40.10 dst-port=8080 action=masquerade`. Sin ella, el retorno va directo y el cliente interno lo descarta.

</details>

---

## 🃏 Mazo 3 — Cálculo mental CIDR / VLSM / CGNAT en 15 segundos

**1. ¿Cuántas IPs totales y cuántas usables tiene una `/30`?**

<details>
<summary>👀 Ver solución explicada</summary>

`/30` → `2^(32-30) = 4` direcciones totales, **2 usables** (`.1` y `.2`). Máscara `255.255.255.252`. Es el clásico enlace punto a punto entre dos routers.

</details>

**2. ¿Y una `/29`?**

<details>
<summary>👀 Ver solución explicada</summary>

`/29` → 8 totales, **6 usables**. Máscara `255.255.255.248`. Útil para un bloque chico de IPs públicas o un segmento de servicios.

</details>

**3. ¿Y una `/28`?**

<details>
<summary>👀 Ver solución explicada</summary>

`/28` → 16 totales, **14 usables**. Máscara `255.255.255.240`.

</details>

**4. ¿Y una `/27` y una `/26`?**

<details>
<summary>👀 Ver solución explicada</summary>

`/27` → 32 totales, **30 usables** (`255.255.255.224`). `/26` → 64 totales, **62 usables** (`255.255.255.192`).

</details>

**5. ¿Y una `/25`?**

<details>
<summary>👀 Ver solución explicada</summary>

`/25` → 128 totales, **126 usables**. Máscara `255.255.255.128`. Media `/24`.

</details>

**6. ¿Cuántas IPs hay en una `/23`?**

<details>
<summary>👀 Ver solución explicada</summary>

`/23` → `2^9 = 512` totales, **510 usables**. Máscara `255.255.254.0`. Equivale a **2 redes `/24`** consecutivas.

</details>

**7. ¿Cuántas `/24` entran en una `/22`?**

<details>
<summary>👀 Ver solución explicada</summary>

`/22` → `2^(24-22) = 4` bloques `/24` (1024 IPs totales, 1022 usables, máscara `255.255.252.0`).

</details>

**8. ¿Cuál es la wildcard mask de una `/26` para una ACL de Cisco?**

<details>
<summary>👀 Ver solución explicada</summary>

La wildcard es el **complemento** de la máscara: `/26` = `255.255.255.192` → wildcard **`0.0.0.63`**. Se usa en ACLs: `permit ip 10.0.0.0 0.0.0.63 any`.

</details>

**9. ¿`10.0.10.200` y `10.0.10.50` están en la misma subred si ambas usan `/24`?**

<details>
<summary>👀 Ver solución explicada</summary>

**Sí.** Con `/24` la red es `10.0.10.0/24` (`.0` a `.255`), así que ambas están en el mismo "barrio" y se hablan por **ARP directo**, sin pasar por el gateway.

</details>

**10. ¿Qué rango usa CGNAT y qué implica encontrarlo?**

<details>
<summary>👀 Ver solución explicada</summary>

**`100.64.0.0/10`** (`RFC 6598`). Si tu WAN tiene esa IP, estás **detrás del NAT del proveedor**: **no podés** hacer Port Forwarding público y muchos clientes comparten esa salida. Pedí IP pública real.

</details>

**11. Un cliente ve `169.254.x.x`. ¿Qué significa?**

<details>
<summary>👀 Ver solución explicada</summary>

Es **APIPA** (`169.254.0.0/16`, `RFC 3927`): dirección autoasignada porque **falló el DHCP**. El equipo puede hablar en su propia LAN pero **no tiene gateway ni DNS**, así que no sale a ningún lado.

</details>

**12. ¿Para qué sirve una `/31` y qué RFC la define?**

<details>
<summary>👀 Ver solución explicada</summary>

`/31` → **2 direcciones, ambas usables**, sin red ni broadcast. Definida en el **`RFC 3021`**. Ideal para enlaces punto a punto donde querés ahorrar direcciones.

</details>

**13. ¿Cuál es la dirección de broadcast de `192.168.5.32/27`?**

<details>
<summary>👀 Ver solución explicada</summary>

`/27` en el cuarto octeto usa bloques de 32: `0-31`, `32-63`, `64-95`... El bloque de `.32` llega hasta **`.63`**. Broadcast = **`192.168.5.63`**, red = `192.168.5.32`, usables `.33` a `.62`.

</details>

**14. ¿Cuál es la dirección de red (network) de `10.1.20.75/26`?**

<details>
<summary>👀 Ver solución explicada</summary>

`/26` usa bloques de 64: `0-63`, `64-127`, `128-191`... `75` cae en el bloque que arranca en **`64`**. Red = **`10.1.20.64`**, broadcast = `10.1.20.127`, usables `.65` a `.126`.

</details>

**15. ¿Cuántas redes `/30` punto a punto entran en una `/24`?**

<details>
<summary>👀 Ver solución explicada</summary>

`/24` tiene 256 direcciones; cada `/30` usa 4 → **64 enlaces punto a punto**. Es la cuenta que hacés al planificar los links entre routers de una topología full-mesh.

</details>

---

## 🃏 Mazo 4 — Trampas mortales de guardia

**1. ¿Qué hace exactamente `switchport trunk allowed vlan 50` y por qué es peligroso?**

<details>
<summary>👀 Ver solución explicada</summary>

**Reemplaza** toda la lista de VLANs permitidas por solo la `50`, cortando todas las demás. Siempre usá `add` para sumar sin borrar: `switchport trunk allowed vlan add 50`. Antes de tocar un trunk productivo, dejate un `reload in 10`.

</details>

**2. ¿Qué es el Safe Mode de MikroTik y cómo te salva de un corte remoto?**

<details>
<summary>👀 Ver solución explicada</summary>

Se activa con **`Ctrl+X`** en la consola/SSH. Mientras esté activo, **los cambios no se confirman**; si perdés la sesión, RouterOS **revierte todo automáticamente** a como estaba. Si el cambio funcionó, volvés a presionar **`Ctrl+X`** para confirmarlo. Es el "salvavidas" routeros.

</details>

**3. ¿Cómo te protegés en Cisco antes de un cambio riesgoso por SSH?**

<details>
<summary>👀 Ver solución explicada</summary>

Programá un reinicio de rescate: **`reload in 10`**. Si el cambio te deja afuera, el equipo reinicia solo en 10 minutos y vuelve a la config guardada. Si el cambio salió bien, cancelás con **`reload cancel`** antes de que expire.

</details>

**4. ¿Por qué una Simple Queue marca `0 bps` si claramente hay tráfico pasando?**

<details>
<summary>👀 Ver solución explicada</summary>

Por **FastTrack**: la regla `action=fasttrack-connection` en `/ip firewall filter` hace que las conexiones establecidas **salteen las colas**, así que los contadores quedan en `0`. O quitás esa regla para la subred, o usás **Queue Tree + Mangle** (el approach recomendado para shaping serio).

</details>

**5. ¿Por qué un usuario interno no puede entrar a un servidor publicado por su IP pública?**

<details>
<summary>👀 Ver solución explicada</summary>

Porque falta **Hairpin NAT**. El cliente interno recibe la respuesta con un origen distinto al destino que pidió y la descarta. Se resuelve con una regla `srcnat`/`MASQUERADE` para el tráfico **interno → IP pública interna**. No es un problema del DNAT en sí.

</details>

**6. ¿Por qué bloquear todo ICMPv6 en un firewall IPv6 es un error grave?**

<details>
<summary>👀 Ver solución explicada</summary>

Porque **NDP (Neighbor Discovery) y SLAAC viajan sobre ICMPv6** (`RS=133`, `RA=134`, `NS=135`, `NA=136`). Si lo bloqueás, los equipos **no resuelven vecinos ni autoconfiguran dirección**: la red IPv6 se cae aunque el filtrado parezca "más seguro". Permití siempre los tipos esenciales de ICMPv6.

</details>

**7. Dos routers VRRP están ambos en `MASTER`. ¿Qué pasó?**

<details>
<summary>👀 Ver solución explicada</summary>

**Split-brain**: los routers no se escuchan entre sí, casi siempre porque **se perdió la adyacencia L2** (VLAN que no cruza el trunk, o el multicast `224.0.0.18` bloqueado). Resultado: **dos equipos responden por la misma IP virtual**, generando MAC e IP duplicadas en la LAN. Verificá la conectividad L2 y que `vrid`, prioridad y autenticación coincidan.

</details>

**8. Una ruta recursiva no resuelve. ¿Qué revisás en MikroTik?**

<details>
<summary>👀 Ver solución explicada</summary>

El **`scope` / `target-scope`**. Una ruta recursiva (típico en doble WAN: la default apunta al gateway de la WAN y esta a su vez se resuelve por la IP del ISP) solo se activa si la ruta "resolutora" tiene un `scope` menor al `target-scope` de la ruta dependiente (ej. `target-scope=11` y la ruta base con `scope=10`). Mal calibrados, la ruta queda sin flag `A`.

</details>

**9. ¿Cuál es la diferencia entre las cadenas `INPUT` y `FORWARD` y por qué confundirlas rompe todo?**

<details>
<summary>👀 Ver solución explicada</summary>

- **`INPUT`**: tráfico destinado **al propio router** (SSH, WinBox, respuesta a ping).
- **`FORWARD`**: tráfico que **atraviesa** el router (de una LAN a otra o a Internet).

Si permitís en `FORWARD` pero bloqueás en `INPUT` (o al revés), podés dejar a los usuarios sin salida o exponer la gestión del equipo. Son políticas distintas: no las mezcles.

</details>

**10. ¿Cómo se configuran bien los puertos "confiables" de DHCP Snooping?**

<details>
<summary>👀 Ver solución explicada</summary>

**Confiable (`trust`) solo el puerto que va hacia el servidor DHCP real** (el uplink hacia el router/core); **NO confiable** todos los puertos de acceso de usuarios. Así, si alguien enchufa un "router casero" que reparte DHCP, sus ofertas se descartan y evitás el **Rogue DHCP**.

</details>

**11. ¿Por qué nunca debés bloquear el protocolo IP `89` en un enlace de tránsito?**

<details>
<summary>👀 Ver solución explicada</summary>

El **número de protocolo IP `89` es OSPF**. Bloquearlo en un filtro de WAN/tránsito **tumba las adyacencias** y las rutas dinámicas desaparecen. OSPF no usa TCP/UDP, por lo que no aparece en filtros de puertos: hay que filtrar por **protocolo**, y hacerlo solo donde corresponde (borde de Internet), no en los enlaces internos.

</details>

**12. Tres cámaras IP reinician todas las noches. ¿Cuál es la causa más probable?**

<details>
<summary>👀 Ver solución explicada</summary>

**Presupuesto PoE agotado**: al encenderse las luces o sumarse más dispositivos, el switch no puede entregar la potencia y **corta/reaplica energía** a los puertos. Verificá `show power inline` o `/interface ethernet poe monitor`, y revisá si el total de Watts alcanza. Considerá un switch con más presupuesto PoE.

</details>

**13. Un trunk tiene Native VLAN distinta en cada extremo. ¿Qué riesgo genera?**

<details>
<summary>👀 Ver solución explicada</summary>

**VLAN hopping y agujeros negros**: las tramas sin tag se interpretan en VLANs distintas en cada punta, causando desde pérdida de conectividad hasta que el tráfico termine en una VLAN que no corresponde. Regla: **la Native VLAN / PVID debe coincidir en ambos extremos** del trunk.

</details>

**14. Un puerto se deshabilitó solo por BPDU Guard. ¿Cómo lo recuperás?**

<details>
<summary>👀 Ver solución explicada</summary>

Primero **quitá la causa** (el switch/router casero que envía BPDUs por un puerto de acceso). Después rehabilitalo con **`shutdown`** seguido de **`no shutdown`** en la interfaz. Si es un enlace punto a punto legítimo, configurá el puerto correctamente (sin PortFast) para que no dispare la protección.

</details>

**15. Movés el PVID de un puerto trunk "para probar". ¿Qué puede pasar?**

<details>
<summary>👀 Ver solución explicada</summary>

Cambiar el **PVID en un trunk** altera en qué VLAN caen las tramas **sin etiquetar** (la Native VLAN). Si no coincide con el otro extremo o con los dispositivos que envían tráfico sin tag, perdés conectividad o mandás tráfico a la VLAN equivocada. Nunca lo cambies en producción sin coordinarlo en las dos puntas y sin `reload in`/Safe Mode de respaldo.

</details>

---

## 🔗 Ver también

- [`multivendor-cli-rosetta-stone`](multivendor-cli-rosetta-stone.md) — Fuente autoritativa de la traducción exacta de todos los comandos de estos desafíos
- [`ipv4-cidr-vlsm-and-special-ranges`](ipv4-cidr-vlsm-and-special-ranges.md) — Tabla extendida para el Mazo 3 (CIDR, VLSM y rangos especiales)
- [`symptom-to-layer-troubleshooting-matrix`](symptom-to-layer-troubleshooting-matrix.md) — Del síntoma del Mazo 2 a la primera acción de diagnóstico
