# TODO — Hoja de Ruta Priorizada (Fase 2 de `learning-network-guides`)

> **Guía de continuación para ejecutar con modelos como DeepSeek 4.1 Flash (1M de contexto):**
> Cada prioridad representa **1 rama auxiliar y 1 Pull Request** siguiendo las reglas de [`AGENTS.md`](AGENTS.md) (`pnpm validate` con 0 errores, sin push directo a `main` y sin auto-merge). Copiá y pegá el bloque **"🤖 Prompt listo para DeepSeek 4.1 Flash"** de la prioridad que quieras ejecutar.

---

## 🔴 Prioridad 1 — Sistema de *Active Recall*, Flashcards Multi-Vendor y Desafíos con Respuesta Oculta (`<details>`)

- **Valor para el estudiante humano:** Transforma la lectura pasiva en entrenamiento activo. Utiliza etiquetas HTML `<details><summary>👀 Ver respuesta / comando exacto</summary>...</details>` (nativas en GitHub Markdown y permitidas en nuestro `.markdownlint.jsonc`) para que el estudiante se ponga a prueba a sí mismo antes de revelar la solución.
- **Archivos a crear/modificar:**
  1. `reference/active-recall-flashcards-and-drills.md` — **100 ejercicios rápidos divididos en 4 mazos de memoria muscular:**
     - *Mazo 1 (Traducción en 5 segundos):* "¿Cómo ves la tabla MAC, las VLANs del trunk o los vecinos OSPF en Cisco vs MikroTik vs Aruba vs Linux?"
     - *Mazo 2 (Lectura de consolas rotas):* Se muestra un fragmento real de consola con un error sutil (ej. `Gi1/0/2(I)`, `EXSTART/DR`, `10.1.10.1/32` mal puesto en MikroTik, `PVID` desalineado o falta de flag `H`) y el humano debe responder qué está roto antes de desplegar la solución.
     - *Mazo 3 (Cálculo mental CIDR/VLSM en 15 segundos):* Ejercicios rápidos de subredes `/30`, `/29`, `/28`, `/23` y detección de CGNAT/APIPA.
     - *Mazo 4 (Trampas mortales de guardia):* "¿Qué pasa si escribís `switchport trunk allowed vlan 50` sin `add`?", "¿Por qué tu Simple Queue marca `0 bps`?", etc.
  2. Agregar al final de los 14 archivos de `concepts/*.md` una sección corta `## 🧪 Autoevaluación rápida (Active Recall)` con **3 preguntas clave con `<details>`** que validen que el lector realmente entendió el modelo mental antes de pasar al siguiente capítulo.
  3. Actualizar `reference/README.md` y `README.md`.

### 🤖 Prompt listo para DeepSeek 4.1 Flash (Prioridad 1)

```text
Lee AGENTS.md, carga la skill `network-reference-creator` y `network-concepts-creator`, crea una rama `feat/active-recall-drills-and-quizzes` desde `main` y ejecuta la Prioridad 1:
1. Crea `reference/active-recall-flashcards-and-drills.md` con 60+ ejercicios de memoria muscular divididos en 4 bloques: (1) Traducción rápida CLI Cisco ↔ MikroTik v7 ↔ Aruba ↔ Linux, (2) "Encuentra el bug en esta salida de consola" con outputs reales rotos, (3) Cálculo mental rápido de CIDR/VLSM/CGNAT, y (4) Preguntas trampa de operación segura (Safe Mode, trunk add, bridge1 tagged, NAT bypass). Usa bloques desplegables `<details><summary>👀 Ver solución explicada</summary>...</details>` dejando siempre líneas en blanco alrededor de los bloques internos para que el humano piense antes de ver la respuesta.
2. En cada uno de los 14 archivos de `concepts/*.md`, agrega justo antes de `## 🔗 Ver también` una sección `## 🧪 Autoevaluación rápida (Active Recall)` con 3 preguntas prácticas de razonamiento sobre ese concepto y sus respuestas ocultas dentro de `<details>`.
3. Enlaza la nueva referencia en `reference/README.md` y actualiza el contador en `README.md`.
4. Ejecuta `pnpm lint:md:fix && pnpm validate` hasta tener 0 errores, haz commit en español, push de la rama y abre la PR sin hacer merge.
```

---

## 🔴 Prioridad 2 — Proyecto Integrador Capstone: "Construir y Operar una Empresa Multi-Sede de Cero a Producción" (4–6 horas)

- **Valor para el estudiante humano:** Es el examen final práctico equivalente al proyecto integrador de `learning-sys-admin-guides`. En lugar de practicar temas sueltos, el humano construye una topología completa desde el cableado y el direccionamiento hasta el failover y la resolución de un incidente múltiple.
- **Archivos a crear/modificar:**
  1. `scenarios/maintenance/04-integrative-capstone-enterprise-network.md` — Proyecto guiado dividido en **5 Fases progresivas**:
     - **Fase 1:** Diseño de direccionamiento (`10.1.<VLAN>.0/24` y `10.2.<VLAN>.0/24`) y Switching Capa 2 (`VLANs 10, 20, 40, 99, 100, 200`, `RSTP Root 4096 + BPDU Guard`, `LACP 802.3ad` y `DHCP Snooping`).
     - **Fase 2:** Enrutamiento Inter-VLAN, redundancia de Default Gateway con **VRRP + WAN Tracking** y failover Dual-WAN con **Rutas Recursivas (`scope=10` / `target-scope=11`)**.
     - **Fase 3:** Firewall Stateful Zero-Trust entre las 6 zonas, publicación de servidor con **DNAT + Split-DNS + Hairpin NAT** y control de ancho de banda con **PCQ + `fq-codel`**.
     - **Fase 4:** Interconexión con la Sucursal 2 mediante túnel **WireGuard Site-to-Site (`MTU 1420` + `MSS Clamping`)** corriendo **OSPFv2 (`point-to-point`)** encima.
     - **Fase 5:** Auditoría final, backup automatizado `.rsc` a Git y checklist de validación de 25 puntos.
  2. `labs/docker-compose.integrative.yml` — Entorno Docker Compose completo de 6 contenedores (`rtr-sede1`, `sw-core`, `rtr-sede2`, `srv-erp`, `pc-staff`, `cliente-wan`) para ejecutar el Proyecto Integrador completo en la propia PC.
  3. Actualizar `scenarios/README.md`, `labs/README.md` y `README.md`.

### 🤖 Prompt listo para DeepSeek 4.1 Flash (Prioridad 2)

```text
Lee AGENTS.md, carga las skills `network-scenarios-creator` y `network-labs-creator`, crea una rama `feat/integrative-capstone-project` desde `main` y ejecuta la Prioridad 2:
1. Crea `scenarios/maintenance/04-integrative-capstone-enterprise-network.md`: el Proyecto Integrador Capstone de 5 fases (4-6 horas) que une todo el repositorio (Fase 1: VLSM + Switching L2 VLANs/RSTP/LACP/DHCP Snooping; Fase 2: Inter-VLAN + VRRP con WAN Tracking + Dual-WAN Recursivo; Fase 3: Firewall Zero-Trust 6 zonas + DNAT/Hairpin/Split-DNS + QoS PCQ/fq-codel; Fase 4: Túnel WireGuard Site-to-Site + OSPFv2 ptp + MSS Clamping; Fase 5: Observabilidad SNMPv3/Syslog, Backup Git y Checklist de 20 pruebas de aceptación) con soluciones completas tanto en Cisco IOS como en MikroTik RouterOS v7 y Linux.
2. Crea `labs/docker-compose.integrative.yml` con una topología funcional de 6 servicios Alpine + FRRouting + WireGuard/iptables para practicar el proyecto integrador en local.
3. Enlaza el proyecto integrador en `scenarios/README.md`, `labs/README.md` y destácalo en `README.md`.
4. Ejecuta `pnpm lint:md:fix && pnpm validate` (0 errores), haz commit, push y abre la PR sin hacer merge.
```

---

## 🟡 Prioridad 3 — Simulador Interactivo "Break & Fix" en `labs/` (Entrenador de Guardia a Ciegas)

- **Valor para el estudiante humano:** Cuando uno mismo rompe el laboratorio para probar algo, ya sabe qué rompió. Para entrenar el cerebro de diagnóstico real, un script debe **inyectar una falla secreta al azar (o por número de misión)** y otro script debe evaluar si el humano logró repararla.
- **Archivos a crear/modificar:**
  1. `labs/break-and-fix.sh` (script POSIX `sh`, validado con ShellCheck) con cuatro subcomandos:
     - `./labs/break-and-fix.sh list`: lista las 8 misiones de guardia disponibles sin revelar la causa raíz.
     - `./labs/break-and-fix.sh break <1..8|random>`: inyecta en silencio una de 8 fallas reales sobre los contenedores de laboratorio y le imprime al estudiante **únicamente el ticket que reporta el usuario** (ej. *"Ticket #03: El ping entre routers anda, pero las rutas de la sucursal desaparecieron"* → por detrás el script cambió el MTU a `1400` o cambió el tipo de red OSPF a `broadcast`, o metió una regla `DROP` o rompió el *Hairpin NAT*).
     - `./labs/break-and-fix.sh hint <1..8>`: le da una pista de qué capa OSI mirar sin regalarle el comando.
     - `./labs/break-and-fix.sh verify <1..8>`: comprueba con pruebas reales (`ping`, `curl`, `vtysh show ip ospf neighbor`, `conntrack`) si el estudiante solucionó la causa raíz y le da feedback (`✅ INCIDENTE RESUELTO` o `❌ Aún falla: pista de capa OSI`).
  2. Documentar el modo entrenamiento en `labs/README.md`.

### 🤖 Prompt listo para DeepSeek 4.1 Flash (Prioridad 3)

```text
Lee AGENTS.md, carga la skill `network-labs-creator`, crea una rama `feat/labs-break-and-fix-trainer` desde `main` y ejecuta la Prioridad 3:
1. Crea un script POSIX `labs/break-and-fix.sh` (compatible con `/bin/sh` sin bashismos, limpio bajo `shellcheck`) que funcione sobre los laboratorios de `labs/` con 4 comandos: `list`, `break <1..8|random>`, `hint <1..8>` y `verify <1..8>`.
2. Implementa 8 misiones reales de troubleshooting ciego: (1) VLAN faltante en interfaz trunk ROAS, (2) MTU Mismatch 1420 vs 1500 trabando OSPF en ExStart, (3) Network-type mismatch ptp vs broadcast en OSPF, (4) Costo OSPF invertido mandando tráfico por enlace lento, (5) Triángulo roto de Hairpin NAT desde PC interna, (6) Agujero negro de MTU/MSS sin TCP MSS Clamping, (7) Regla de Masquerade general pisando tráfico privado sin filtro WAN, y (8) Bloqueo de protocolo IP 89 (OSPF) en cadena INPUT.
3. Documenta cómo usar el entrenador de guardia en `labs/README.md`.
4. Ejecuta `pnpm lint:md:fix && pnpm validate` (y `shellcheck labs/break-and-fix.sh` si está instalado), haz commit, push y abre la PR sin hacer merge.
```

---

## 🟡 Prioridad 4 — Ingeniería Física de Racks, Selección de Hardware Real y Dimensionamiento de UPS

- **Valor para el estudiante humano:** Conecta el software con el hierro real. Enseña qué modelo físico comprar según el tamaño de la empresa, cómo distribuir los equipos en las unidades (`U`) de un rack para que no se recalienten ni sea un caos de cables, cómo poner a tierra equipos exteriores y cómo calcular cuántos minutos reales aguanta una UPS.
- **Archivos a crear/modificar:**
  1. `guides/08-operations/rack-design-ups-and-hardware-selection.md` — Guía completa de ingeniería física:
     - **Anatomía y orden de un Rack Profesional de arriba hacia abajo (`U42 → U1`):** Por qué la bandeja óptica ODF va arriba de todo, por qué se intercala **1 Patch Panel de 24 bocas cada 1 Switch de 24 bocas** con patchcords cortos de `15–20 cm` (eliminando los organizadores horizontales llenos de espaguetis de 2 metros), dónde va el Router de borde, los servidores y por qué las **UPS siempre van en las unidades inferiores (`U1–U4`)** por centro de gravedad y temperatura.
     - **Flujo de aire (*Front-to-Back Airflow*):** Pasillos fríos/calientes y paneles ciegos (*Blanking Panels*).
     - **Dimensionamiento Eléctrico y UPS:** Diferencia entre **`VA` (*Volt-Amperes*)** y **`Watts` reales** (Factor de Potencia `PF = 0.7` a `0.9`), por qué las fuentes con PFC activo exigen **UPS de Onda Senoidal Pura (*Pure Sine Wave*)** o **Doble Conversión Online**, cómo calcular el tiempo de autonomía en minutos y cómo monitorear la UPS por **SNMP / NUT (*Network UPS Tools*)**.
     - **Puesta a Tierra y Descargas Atmosféricas (ESD):** Cable FTP con fichas blindadas RJ45 metálicas y protectores de sobretensión (`ETH-SP-G2`) para cámaras y antenas exteriores.
  2. `reference/hardware-selection-and-sizing-matrix.md` — Matriz práctica de dimensionamiento por escala (`Oficina Pequeña 20 usuarios`, `PYME 100 usuarios`, `Empresa 500 usuarios / Campus`, `Data Center / WISP`): qué modelos reales de **MikroTik**, **Cisco**, **Aruba** y **Ubiquiti** elegir, cuánto caudal real enrutan con Firewall/Queue/IPsec activos y qué licencias/SFP llevan.
  3. Actualizar `guides/README.md` y `reference/README.md`.

### 🤖 Prompt listo para DeepSeek 4.1 Flash (Prioridad 4)

```text
Lee AGENTS.md, carga las skills `network-guides-creator` y `network-reference-creator`, crea una rama `feat/physical-rack-ups-and-hardware-sizing` desde `main` y ejecuta la Prioridad 4:
1. Crea `guides/08-operations/rack-design-ups-and-hardware-selection.md` siguiendo la plantilla de guías: diagrama ASCII de un rack profesional unidad por unidad (ODF óptica arriba, intercalado Patch Panel 24p + Switch 24p con patchcords de 20cm, Router Core, Servidores y UPS Senoidal/Online abajo), cálculo real de UPS (VA vs Watts, Factor de Potencia, autonomía en baterías y monitoreo por SNMP/NUT) y protección contra descargas ESD/rayos en enlaces exteriores PoE.
2. Crea `reference/hardware-selection-and-sizing-matrix.md` con tablas comparativas de modelos reales recomendados (MikroTik RB5009, CCR2004, CCR2116, CRS326, CRS328-24P, CRS354; Cisco Catalyst 1200/1300/9200L/9300 e ISR 1100/4300; Aruba Instant On 1930/1960 y CX 6100/6200; Ubiquiti UniFi Pro Max / Enterprise) detallando caudal real con Firewall/QoS/VPN, presupuesto PoE y caso de uso.
3. Enlaza ambos archivos en `guides/README.md`, `reference/README.md` y actualiza los contadores en `README.md`.
4. Ejecuta `pnpm lint:md:fix && pnpm validate` (0 errores), haz commit, push y abre la PR sin hacer merge.
```

---

## 🟢 Prioridad 5 — Módulo de IPv6 Dual-Stack en la Vida Real y BGP Práctico (`concepts/` + `guides/03-routing-l3/`)

- **Valor para el estudiante humano:** Quita el miedo a **IPv6** y a **BGP**. Hoy todos los proveedores de fibra entregan un prefijo IPv6 (`/56` o `/64` vía `DHCPv6-PD`) y los Data Centers modernos usan BGP. Explicarlo con la misma claridad de analogías y tablas multi-vendor del resto del repo cierra la brecha hacia nivel Senior.
- **Archivos a crear/modificar:**
  1. `concepts/ipv6-dual-stack-ndp-and-slaac.md` — Modelo mental de IPv6 sin dolor: estructura de 128 bits, reglas de abreviación (`::`), los 3 tipos de direcciones que todo ingeniero ve en consola (**Link-Local `fe80::/10`**, **Global Unicast `2000::/3`** y **Unique Local `fd00::/8` — el RFC 1918 de IPv6**), por qué en IPv6 **no existe ARP ni Broadcast** y cómo lo reemplaza **NDP (*Neighbor Discovery Protocol* sobre `ICMPv6` tipo `133/134/135/136`)**, y cómo funciona **SLAAC + `DHCPv6 Prefix Delegation (PD)`**.
  2. `guides/03-routing-l3/ipv6-dual-stack-and-firewall.md` — Cómo recibir un prefijo `/56` o `/48` del proveedor en MikroTik RouterOS v7 (`/ipv6 dhcp-client`), repartir `/64` automáticamente a las VLANs internas (`from-pool=`), configurar en Cisco IOS y Linux, y **cómo armar el Firewall IPv6 (`/ipv6 firewall filter`)** (recordando que en IPv6 **no hay NAT que esconda a las PCs**, por lo que un error en la cadena `FORWARD` de IPv6 deja a todas las PCs expuestas directamente a Internet, y que jamás se debe bloquear `ICMPv6` porque rompe NDP y SLAAC).
  3. `guides/03-routing-l3/bgp-ebgp-multihoming-and-filters.md` — Configuración práctica de **eBGP** entre Sistemas Autónomos (`AS 65001 ↔ AS 65002`) en Cisco IOS, MikroTik RouterOS v7 (`/routing bgp connection` y `/routing filter rule`) y Linux FRRouting, con filtros de entrada/salida obligatorios para no convertirse en tránsito accidental de Internet.
  4. Actualizar `concepts/README.md`, `guides/README.md` y `README.md`.

### 🤖 Prompt listo para DeepSeek 4.1 Flash (Prioridad 5)

```text
Lee AGENTS.md, carga las skills `network-concepts-creator` y `network-guides-creator`, crea una rama `feat/ipv6-dual-stack-and-bgp` desde `main` y ejecuta la Prioridad 5:
1. Crea el concepto #15 `concepts/ipv6-dual-stack-ndp-and-slaac.md` explicando IPv6 práctico: bloques `fe80::/10` (Link-Local), `2000::/3` (GUA) y `fd00::/8` (ULA), cómo ICMPv6 Neighbor Discovery (RS/RA/NS/NA) reemplaza a ARP y DHCP, cómo funciona DHCPv6 Prefix Delegation (/56 -> múltiples /64 por VLAN) y por qué bloquear ICMPv6 rompe toda la red.
2. Crea la guía `guides/03-routing-l3/ipv6-dual-stack-and-firewall.md` con implementación completa en MikroTik RouterOS v7, Cisco IOS y Linux, haciendo énfasis en el Firewall Stateful IPv6 (`input` y `forward` sin NAT).
3. Crea la guía `guides/03-routing-l3/bgp-ebgp-multihoming-and-filters.md` enseñando eBGP práctico (`TCP 179`), atributos esenciales (`AS-Path`, `Local-Preference`, `Weight`, `MED`) y filtros de prefijos en Cisco IOS, MikroTik RouterOS v7 (`/routing bgp template/connection` + `/routing filter rule`) y FRRouting (`vtysh`).
4. Actualiza `concepts/README.md`, `guides/README.md` y los contadores de `README.md`.
5. Ejecuta `pnpm lint:md:fix && pnpm validate` (0 errores), haz commit, push y abre la PR sin hacer merge.
```

---

## 🟢 Prioridad 6 — Script de Validación Técnica y Pedagógica Automatizada (`scripts/validate_netops.sh`)

- **Valor para el repositorio y para futuros modelos de IA:** Igual que `learning-sys-admin-guides` tiene `scripts/validate_sre.sh`, este script protege la calidad técnica del repositorio cada vez que un modelo rápido como DeepSeek 4.1 Flash crea o edita archivos.
- **Qué verificará automáticamente `scripts/validate_netops.sh` (integrado en `pnpm validate` y GitHub Actions CI):**
  1. **Cero enlaces internos rotos:** Verifica que todo enlace relativo `[texto](ruta.md)` apunte a un archivo real existente en el disco.
  2. **Cero sintaxis deprecada de RouterOS v6:** Falla si alguien escribe comandos eliminados en RouterOS v7 como `/routing ospf network`, `/interface ethernet set ... master-port=`, `/ip ipsec peer ... dh-group=` (que en v7 vive en `profile`), o `/interface wireless` viejo sin aclarar v7.
  3. **Secciones obligatorias presentes:** Verifica que todo archivo en `concepts/*.md` contenga la frase `"Pensá en esto como"` y el diccionario multi-vendor, y que todo escenario en `scenarios/*/*.md` tenga sección de `Mitigación y Rollback`.

### 🤖 Prompt listo para DeepSeek 4.1 Flash (Prioridad 6)

```text
Lee AGENTS.md, crea una rama `feat/validate-netops-ci-guardrails` desde `main` y ejecuta la Prioridad 6:
1. Crea `scripts/validate_netops.sh` (script POSIX `/bin/sh` con `set -eu`) que valide automáticamente:
   - Que todos los enlaces relativos Markdown `](...md)` en `README.md`, `concepts/`, `guides/`, `scenarios/`, `reference/` y `labs/` apunten a archivos que existan realmente en el repositorio.
   - Que ningún archivo en `guides/` o `scenarios/` use comandos deprecados de RouterOS v6 (`/routing ospf network add`, `master-port=`).
   - Que todos los documentos en `concepts/` (excepto `README.md`) incluyan la frase `"Pensá en esto como"` en su sección de Modelo Mental.
2. Agrega en `package.json` los scripts `"lint:sh"` (con `shellcheck` si está disponible) y `"validate:netops": "sh scripts/validate_netops.sh"`, e intégralo en `"validate": "pnpm lint:md && pnpm validate:netops"`.
3. Ejecuta `pnpm validate`, corrige cualquier link o detalle si el script detecta alguno, haz commit, push y abre la PR sin hacer merge.
```

---

## 📋 Resumen Ejecutivo de la Fase 2 (Orden de Ejecución Recomendado)

| Orden | Prioridad | Qué construye | Por qué es ideal para el aprendizaje humano |
|:-----:|-----------|---------------|---------------------------------------------|
| **1º** | **Prioridad 1** | **Active Recall + 100 Flashcards + Quizzes con `<details>`** | Obliga al cerebro humano a recuperar el comando y diagnosticar salidas rotas antes de ver la respuesta |
| **2º** | **Prioridad 2** | **Proyecto Integrador Capstone (5 Fases + Lab 6 nodos)** | Conecta los 14 conceptos y las 24 guías en una sola empresa real construida desde cero |
| **3º** | **Prioridad 3** | **Entrenador "Break & Fix" (`labs/break-and-fix.sh`)** | Rompe los contenedores en secreto para que el estudiante diagnostique incidentes reales a ciegas |
| **4º** | **Prioridad 4** | **Diseño Físico de Racks, UPS y Matriz de Compra de Hardware** | Enseña cómo armar el rack unidad por unidad, calcular baterías UPS y elegir qué switch/router comprar |
| **5º** | **Prioridad 5** | **IPv6 Dual-Stack Práctico (NDP/PD/Firewall) + eBGP Multi-Vendor** | Lleva al estudiante de redes corporativas a nivel Senior / Data Center / ISP |
| **6º** | **Prioridad 6** | **Validador Automático `scripts/validate_netops.sh` en CI** | Blinda el repositorio contra enlaces rotos, comandos viejos de RouterOS v6 o pérdida de formato |

---

## 🔮 Nota al pie — Posible migración de plataforma (Fase 3)

> **Idea a evaluar a futuro (fuera del alcance de las prioridades de esta fase):** migrar la **capa de entrega/consumo** del contenido a un sitio estático generado con **Astro** y estilado con **Tailwind CSS 4**, con enfoque **mobile-first** y **dark-mode-first**.

- **Por qué:** hoy el material se lee en el visor Markdown de GitHub. Un sitio propio mejora la experiencia en el celular (navegación por capítulos, búsqueda, tabla de contenidos, resaltado de sintaxis y **tema oscuro por defecto**), sin perder la portabilidad del contenido.
- **Cómo (sugerido):** Astro **Content Collections** (o `@astrojs/starlight`) renderizando directamente `concepts/`, `guides/`, `scenarios/`, `reference/` y `labs/`; **Tailwind 4** con *tokens* de tema y `prefers-color-scheme` / `class="dark"` como default.
- **Regla de oro:** los archivos **Markdown siguen siendo la fuente de verdad**. El sitio se **genera desde** ellos; no se duplica ni se reescribe el contenido. `pnpm validate` (Markdownlint) sigue siendo el *gate* de calidad antes de publicar.
- **Riesgo/beneficio:** suma un *build* (Node + Astro) y un despliegue (GitHub Pages / Netlify / Cloudflare), pero no toca la autoría ni la estructura pedagógica actual.
