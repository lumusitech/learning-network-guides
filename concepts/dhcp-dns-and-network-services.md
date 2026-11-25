⬅️ [Volver a Conceptos](README.md)

# Servicios Esenciales de Red (DHCP, DNS y NTP) — Cómo una red cobra vida (y cómo se rompe)

**Capa OSI principal:** Capas 2 a 7 (Infraestructura Core) | **Estándares:** `RFC 2131 (DHCP)`, `RFC 3046 (Option 82)`, `RFC 1035 (DNS)`, `RFC 5905 (NTPv4)`

---

## 🧠 ¿Qué es?

Podés tener el mejor cableado de fibra óptica (Capa 1), las VLANs perfectamente etiquetadas (Capa 2), las tablas OSPF convergidas (Capa 3) y el firewall más limpio del mundo (Capa 4), pero si fallan **DHCP, DNS o NTP**, para el usuario final **"no hay Internet y se cayó todo el sistema"**.

Estos tres protocolos son la **Santísima Trinidad de los servicios de infraestructura**:

1. **DHCP (*Dynamic Host Configuration Protocol* — `UDP 67/68`):** Le entrega automáticamente a cada equipo recién encendido su identidad de Capa 3 (`IP`, `Máscara`, `Default Gateway` y `Servidor DNS`).
2. **DNS (*Domain Name System* — `UDP/TCP 53`):** Traduce nombres humanos (`erp.empresa.local` o `google.com`) en direcciones IP que los routers puedan enrutar.
3. **NTP (*Network Time Protocol* — `UDP 123`):** Mantiene el reloj de todos los routers, switches, servidores y cámaras sincronizado al milisegundo (sin lo cual fallan los certificados HTTPS/TLS, los túneles WireGuard/IPsec, Active Directory y la correlación de logs).

---

## 🎯 ¿Por qué importa en el día a día?

En la práctica diaria de soporte e ingeniería de redes, **más del 60% de los tickets de "no tengo red"** son fallas en el ciclo DHCP (VLAN mal puesta, pool agotado o un router doméstico intruso haciendo de *Rogue DHCP*) o fallas de resolución DNS.

- **En diseño:** Entender **DHCP Relay (`ip helper-address`)** te permite tener 20 VLANs aisladas sin tener que armar 20 servidores DHCP separados, y entender **Split-Horizon DNS** te permite que tus usuarios internos accedan a los servidores locales por su nombre público a velocidad de LAN sin pasar por el NAT del router.
- **En operación/mantenimiento:** Configurar **DHCP Snooping** en tus switches te blinda contra el clásico accidente donde alguien enchufa un router WiFi hogareño en una oficina y tira abajo a toda la empresa.
- **En troubleshooting:** Saber la diferencia entre que falle un `ping 1.1.1.1` (falla de Capa 1–3) y que falle un `ping google.com` cuando `1.1.1.1` sí responde (falla 100% de DNS en Capa 7) te ahorra horas de búsqueda en el lugar equivocado.

---

## ⚙️ Cómo funciona por dentro

### 1. El Ciclo DHCP `DORA` y por qué usa Broadcast

Cuando una PC recién arranca, **todavía no tiene dirección IP (`0.0.0.0`)** ni sabe quién es el servidor DHCP. Por eso tiene que gritar en **Broadcast (`255.255.255.255` / `FF:FF:FF:FF:FF:FF`)** desde el puerto **`UDP 68` (Cliente)** hacia el puerto **`UDP 67` (Servidor)** siguiendo las 4 etapas **D-O-R-A**:

```text
[Cliente sin IP: 0.0.0.0]                                      [Servidor DHCP: 10.1.10.1]
     (Puerto UDP 68)                                                (Puerto UDP 67)
            |                                                              |
            | 1. [D] DISCOVER (Broadcast L2/L3: 0.0.0.0 -> 255.255.255.255)|
            |    "¡Hola! Soy la MAC AA:BB:CC, ¿hay algún DHCP en esta VLAN?"
            +------------------------------------------------------------->|
            |                                                              |
            | 2. [O] OFFER (Oferta con IP libre, Máscara, GW y DNS)        |
            |    "Te ofrezco 10.1.10.105/24, GW 10.1.10.1 por 8 horas"     |
            |<-------------------------------------------------------------+
            |                                                              |
            | 3. [R] REQUEST (¡Sigue siendo BROADCAST a 255.255.255.255!)  |
            |    "¡Acepto la oferta de 10.1.10.1! (Y si había otro DHCP,   |
            |     que retire su oferta porque ya elegí a este)"            |
            +------------------------------------------------------------->|
            |                                                              |
            | 4. [A] ACKNOWLEDGE / ACK (Confirmación final + Lease)        |
            |    "Confirmado, 10.1.10.105 es tuya. Renovala a las 4 hs(T1)"|
            |<-------------------------------------------------------------+
```

> **💡 ¿Qué pasa si hay un segundo servidor DHCP pirata (*Rogue DHCP*) en la misma VLAN?**
> Como el paso 1 (`Discover`) es un grito en Broadcast, **los dos servidores lo escuchan y el cliente acepta el `Offer` del que le conteste un milisegundo más rápido**. Si alguien enchufa un router TP-Link hogareño por una de sus bocas LAN a la pared de la oficina, ese TP-Link contesta instantáneamente entregándole a las PCs de la empresa la IP `192.168.0.100` con Gateway `192.168.0.1` (que no tiene Internet ni acceso a los servidores), dejando fuera de combate a la mitad de la oficina.

### 2. Cómo funciona *DHCP Relay* (`ip helper-address`) a través de VLANs

Sabemos que los routers **no dejan cruzar paquetes Broadcast de una VLAN a otra**. Entonces, si tu servidor DHCP central (ej. un Windows Server o Linux en la `VLAN 40 — 10.1.40.10`) está en otra red, ¿cómo reciben IP las PCs de la `VLAN 10`?

```text
[PC en VLAN 10]                [Router / Switch L3: 10.1.10.1]             [Servidor DHCP Central]
 (0.0.0.0:68)                   (Tiene DHCP Relay hacia .40.10)              (VLAN 40: 10.1.40.10)
      |                                       |                                        |
      | 1. DHCP Discover (BROADCAST)          |                                        |
      +-------------------------------------->| 2. El Router frena el Broadcast,       |
                                              |    lo envuelve en UNICAST y le estampa |
                                              |    adentro el campo GIADDR=10.1.10.1   |
                                              +--------------------------------------->|
                                                                                       |
                                                   (El Servidor lee GIADDR=10.1.10.1   |
                                                    y dice: "¡Ah, viene de la VLAN 10! |
                                                    Le doy una IP del pool 10.1.10.x") |
```

### Anatomía / Componentes clave de DHCP, DNS y NTP

| Componente / Opción | Código / Puerto | Función real | Qué pasa si está mal |
|---------------------|-----------------|--------------|----------------------|
| **DHCP Option 3 (`Router`) y Option 6 (`DNS`)** | `UDP 67` (Srv) / `UDP 68` (Cli) | `Option 3` entrega el Default Gateway; `Option 6` entrega los servidores DNS | Si falta `Option 3`, la PC solo habla en su VLAN local. Si `Option 6` entrega un DNS caído, anda el ping por IP pero no abre ninguna web |
| **DHCP Timers `T1` (`50%`) y `T2` (`87.5%`)** | Renovación de Lease | A mitad del tiempo (`T1`), la PC le pide renovar en **Unicast** a su servidor DHCP sin cortar la red. Si llega a `T2` sin respuesta, pide en Broadcast. Si llega al `100%`, pierde la IP y cae a **APIPA (`169.254.x.x`)** | Si vas a cambiar de subred o migrar un servidor DHCP, **bajá el Lease Time a `10 minutos` el día anterior** para que todas las PCs tomen el cambio rápido |
| **DHCP Option 43 / 60 / 66 / 150** | Aprovisionamiento automático | `Option 43`: le dice a los APs UniFi/Aruba/Cisco cuál es la IP del Controlador cuando está en otra VLAN. `Option 66/150`: servidor TFTP para teléfonos IP | Sin `Option 43` (o un registro DNS `unifi`), un AP nuevo conectado en la VLAN 20 no encuentra al controlador que vive en la VLAN 40 |
| **DNS (`UDP 53` y `TCP 53`)** | `UDP 53` (Consultas) / `TCP 53` (Respuestas `> 512B`, DNSSEC, Zone Transfers) | Traduce nombres (`A`=IPv4, `AAAA`=IPv6, `CNAME`=Alias, `PTR`=IP a Nombre, `SRV`=Servicios/Active Directory) | **Error común:** abrir solo `UDP 53` en el firewall y bloquear `TCP 53`. Hoy las respuestas grandes con DNSSEC o múltiples registros usan `TCP 53` |
| **NTP (`UDP 123` — *Stratum*)** | `Stratum 0` (Reloj atómico/GPS) → `Stratum 1` → `Stratum 2/3` (Tu Router) | Sincroniza la hora UTC en toda la red. Tu router de borde debe ser cliente NTP de un pool externo y **servidor NTP local** para todas tus VLANs aisladas (como cámaras CCTV) | Un MikroTik sin pila CMOS que se reinicia por corte de luz arranca en el año **1970**: si no sincroniza NTP, **no levantan los túneles WireGuard ni valida certificados HTTPS** |

---

### 3. Split-Horizon DNS (*Split-Brain DNS*): La solución elegante al Hairpin NAT

Si tenés un servidor web interno (`10.1.40.10`) publicado hacia Internet bajo el nombre `sistema.miempresa.com` (IP pública `190.210.50.10`):

- **Desde Internet (DNS Público como Cloudflare / Route53):** Cuando alguien fuera de la oficina pregunta por `sistema.miempresa.com`, el DNS público responde **`190.210.50.10`**.
- **Desde adentro de la empresa (Tu servidor DNS interno / Router):** Configurás un registro estático local para que cuando una PC de la oficina pregunte por `sistema.miempresa.com`, tu DNS interno le responda directamente la IP privada **`10.1.40.10`**.
- **Ventaja doble:** Las PCs de la oficina van directo al servidor a velocidad de LAN (`1 Gbps / 10 Gbps`) sin gastar CPU del router en **Hairpin NAT**.

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

| Servicio / Protección | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Aruba / Ubiquiti / TP-Link | Linux (`dnsmasq` / `isc-dhcp` / `chrony`) |
|-----------------------|----------------------|----------------------|----------------------------|-------------------------------------------|
| **Ver IPs entregadas (DHCP Leases)** | `show ip dhcp binding` | `/ip dhcp-server lease print` | `show dhcp-server leases` | `cat /var/lib/misc/dnsmasq.leases` |
| **Fijar una IP por MAC (Reserva DHCP)** | `ip dhcp pool ...` (`host` + `client-identifier`) | `/ip dhcp-server lease make-static <id>` | *Fixed IP / DHCP Reservation* | `dhcp-host=AA:BB:CC:11:22:33,10.1.10.50` |
| **Configurar DHCP Relay en una VLAN** | En `interface Vlan10`: `ip helper-address 10.1.40.10` | `/ip dhcp-relay add interface=vlan10 dhcp-server=10.1.40.10` | En `vlan 10`: `ip helper-address 10.1.40.10` | `dhcrelay -i eth0.10 10.1.40.10` |
| **Bloquear DHCP piratas en el Switch (*DHCP Snooping*)** | `ip dhcp snooping` + `ip dhcp snooping trust` (solo en el Trunk hacia el router) | En `/interface bridge`: `dhcp-snooping=yes` + en el puerto Trunk `trusted=yes` | `dhcp-snooping` + `dhcp-snooping trust <puerto-uplink>` | `ebtables -A FORWARD -p IPv4 --ip-sport 67 -j DROP` |
| **Registro DNS estático local (Split-DNS)** | `ip host sistema.empresa.com 10.1.40.10` | `/ip dns static add name=sistema.empresa.com address=10.1.40.10` | *Local DNS Record* en Gateway | `address=/sistema.empresa.com/10.1.40.10` |
| **Ver estado de sincronización de reloj NTP** | `show ntp status` / `show ntp associations` | `/system ntp client print` | `show ntp status` | `chronyc tracking` / `timedatectl status` |

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Estado de los Leases DHCP en MikroTik** | `status=bound`, `active-address` asignada, `expires-after` corriendo | Aparecen decenas de entradas con **`status=offered`** que nunca pasan a `bound` (o el log dice `offering lease without success`) | **Bucle o problema de VLAN Asimétrica:** el servidor DHCP escucha el `Discover` del cliente y le manda el `Offer`, pero la respuesta nunca le llega de vuelta al cliente (o hay otro DHCP ganándole de mano) |
| **Alerta de conflicto en el servidor DHCP** | `0` conflictos; cada IP libre se entrega limpio | El log muestra `detected conflict by ARP response for 10.1.10.105` y marca la IP como `busy` | Antes de entregar una IP, el servidor DHCP hace un ping/ARP preventivo: **alguien en la oficina se configuró a mano esa IP fija dentro del rango dinámico del pool DHCP** |
| **Gateway recibido por las PCs en `ipconfig /all` o `ip route`** | `10.1.10.1` (la IP de tu router corporativo) | `192.168.0.1` o `192.168.1.1` con la MAC de un TP-Link/Tenda | **Ataque o accidente de *Rogue DHCP*:** conectaron un router WiFi hogareño por su puerto LAN a la red de la empresa y está repartiendo IPs falsas |
| **Puerto de switch con DHCP Snooping activo pero ninguna PC recibe IP** | Las PCs en puertos `untrusted` reciben IP del router conectado en el puerto `trusted` | Activaste `dhcp-snooping=yes` en el switch y **absolutamente todas las PCs de la empresa perdieron su IP** | Te olvidaste de marcar como **`trusted=yes` (`ip dhcp snooping trust`) el puerto Trunk que sube hacia el router legítimo** (por defecto todos los puertos son `untrusted` y bloquean los `DHCP Offer/ACK` del servidor) |
| **Túnel WireGuard o HTTPS que falla tras corte eléctrico** | El túnel reconecta en segundos al volver la luz | El enlace a Internet volvió, pero WireGuard no hace handshake y el log del router tiene fecha `Jan/02/1970` | **Reloj NTP sin sincronizar:** por ejemplo, pusiste nombres de dominio (`pool.ntp.org`) en el cliente NTP, pero al arrancar en 1970 el DNS con DoH/DNSSEC falló por certificado "aún no válido", creando un huevo-y-gallina. (Usá siempre al menos una IP directa como `time.cloudflare.com` / `162.159.200.1`) |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Entregar por DHCP a las PCs de una empresa con Active Directory un DNS público (`8.8.8.8`) como DNS secundario:**
  - Este es uno de los errores más destructivos en redes Windows corporativas. Muchos administradores ponen en el DHCP: **`DNS 1 = 10.1.40.10` (Controlador de Dominio AD local)** y **`DNS 2 = 8.8.8.8` (Google)** pensando *"si se cae mi servidor local, siguen navegando por Google"*.
  - **Qué pasa realmente:** Los clientes Windows no usan el DNS 2 "solo cuando el 1 se muere para siempre"; ante la mínima demora de 50 ms del DNS 1, **pasan a usar el DNS 2 (`8.8.8.8`) y se quedan consultando ahí**. Cuando un minuto después la PC le pregunta a `8.8.8.8` dónde está `dc01.miempresa.local`, Google contesta **`NXDOMAIN` (Ese dominio no existe)**, y **se rompen las carpetas compartidas, las políticas GPO y el inicio de sesión de Active Directory**.
  - **Regla de oro:** Las PCs internas **SOLO** deben recibir como DNS a tus servidores DNS internos (o tu router), y son esos servidores DNS internos quienes reenvían (*Forwarders*) hacia `1.1.1.1` / `8.8.8.8` las consultas de Internet.
- **❌ Bloquear a las cámaras IP el acceso a Internet sin darles un servidor NTP local:** Si aislás correctamente la VLAN 100 de cámaras para que no salgan a Internet, pero las cámaras vienen configuradas de fábrica buscando la hora en `time.windows.com`, a las pocas semanas cada cámara tendrá una hora distinta y las grabaciones de un robo no tendrán validez pericial. Tu propio router (`10.1.100.1`) debe responderles `UDP 123 (NTP)` localmente.

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

Un lunes a las 08:30 AM, a medida que los empleados llegan y encienden sus computadoras, **la mitad puede trabajar normal y la otra mitad no tiene acceso ni al servidor contable ni a Internet**. Cuando el técnico revisa una de las PCs caídas, ve que tiene asignada la dirección IP `192.168.0.104`, máscara `255.255.255.0` y puerta de enlace `192.168.0.1`, cuando toda la empresa usa la red `10.1.10.0/24`.

### Análisis paso a paso por capas

1. **Síntoma observado:** Computadoras recibiendo por DHCP una subred `192.168.0.x` que no pertenece a la infraestructura de la empresa.
2. **Hipótesis usando el modelo mental (Detección y caza de un *Rogue DHCP* en Capa 2):**
   - Alguien conectó un router WiFi hogareño por uno de sus puertos **LAN** (donde viene encendido de fábrica un servidor DHCP `192.168.0.1`) a una roseta de pared de la VLAN 10.
3. **Evidencia que lo confirma:**
   - Desde la PC afectada miramos la tabla ARP (`arp -a` en Windows / `ip neigh` en Linux) para ver cuál es la **Dirección MAC** de ese falso gateway `192.168.0.1` (o bien activamos la alerta `/ip dhcp-server alert` en MikroTik).
   - Obtenemos la MAC culpable: **`50:C7:BF:AA:BB:CC`** (OUI `50:C7:BF` = **TP-Link**).
   - Entramos por SSH al switch de la oficina y buscamos en qué puerto físico se aprendió esa MAC (`show mac address-table address 50c7.bfaa.bbcc` o `/interface bridge host print where mac-address=50:C7:BF:AA:BB:CC`).
   - El switch nos indica el puerto **`Gi1/0/19`** (Oficina de Marketing). Vamos al escritorio 19 y encontramos un router TP-Link blanco que habían traído de su casa "para tener mejor señal WiFi en el rincón" enchufado por la boca amarilla LAN.
4. **Resolución arquitectónica:**
   - Retiramos el router intruso y, para que nunca más pueda ocurrir en toda la empresa, activamos **DHCP Snooping** en los switches dejando únicamente como **`Trusted`** el puerto Trunk que sube a nuestro router principal.

---

## 🧠 Modelo mental

Pensá en esto como **el proceso de ingreso cuando llegás por primera vez a trabajar a un gran complejo corporativo**:

- **DHCP (`DORA`)** es la mesa de acreditaciones en la entrada: entrás sin credencial (`0.0.0.0`) y preguntás en voz alta *"¡Hola! ¿Dónde me acredito?"* (**Discover**). El recepcionista oficial te ofrece el escritorio `10.1.10.105` (**Offer**), vos gritás *"¡Acepto ese escritorio!"* (**Request**) y te entregan tu credencial válida por 8 horas (**ACK**).
- **DHCP Snooping** es el guardia de seguridad del hall que **solo permite que entregue credenciales el empleado sentado detrás del mostrador oficial (`Puerto Trusted`)**: si un visitante cualquiera en el pasillo (`Puerto Untrusted`) saca un talonario falso e intenta repartir credenciales a los que entran (*Rogue DHCP*), el guardia le confisca los papeles en el acto.
- **DNS** es la guía telefónica interna de la empresa (nadie se acuerda del número de interno `10.1.40.10`, todos buscan `"Contabilidad"`), y **NTP** es el reloj maestro colgado en la pared central para que todas las cámaras de seguridad y fichadas de entrada marquen exactamente la misma hora.

---

## 🔗 Ver también

- [`ipv4-addressing-subnetting-and-vlsm`](ipv4-addressing-subnetting-and-vlsm.md) — Cómo organizar cada subred `/24` dejando rangos separados para IPs estáticas, reservas y pool DHCP
- [`vlans-tagged-untagged-and-trunks`](vlans-tagged-untagged-and-trunks.md) — Por qué una PC cae en `169.254.x.x` (APIPA) cuando el PVID o el Trunk no dejan llegar su `DHCP Discover` al servidor
- [`netops-day-to-day-maintenance-and-observability`](netops-day-to-day-maintenance-and-observability.md) — Cómo monitorear, respaldar en Git y mantener toda esta infraestructura en el día a día
