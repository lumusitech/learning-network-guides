#!/bin/sh
# =============================================================================
# break-and-fix.sh — Entrenador de guardia a ciegas ("Break & Fix")
# -----------------------------------------------------------------------------
# Inyecta una falla SECRETA en un laboratorio ya levantado y te da solo el
# ticket que reporta el usuario. Vos diagnosticás, arreglás y recién ahí corrés
# 'verify' para saber si de verdad resolviste la causa raíz.
#
# Uso:
#   sh labs/break-and-fix.sh list                 # Lista las 8 misiones (sin revelar la causa)
#   sh labs/break-and-fix.sh break <1..8|random>  # Inyecta la falla y muestra el ticket
#   sh labs/break-and-fix.sh hint  <1..8>         # Pista de capa OSI (sin regalar el comando)
#   sh labs/break-and-fix.sh verify <1..8>        # Comprueba si arreglaste el incidente
#
# Requiere: docker y el laboratorio de la misión levantado (ver labs/README.md).
# =============================================================================
set -eu

usage() {
  cat <<'EOF'
Entrenador Break & Fix — guardia a ciegas

Uso:
  sh labs/break-and-fix.sh list                 Lista las 8 misiones disponibles
  sh labs/break-and-fix.sh break <1..8|random>  Inyecta la falla y muestra el ticket
  sh labs/break-and-fix.sh hint  <1..8>         Da una pista de capa OSI
  sh labs/break-and-fix.sh verify <1..8>        Verifica si el incidente quedó resuelto

Ejemplo completo:
  docker compose -f labs/docker-compose.lab04-nat-hairpin-mtu.yml up -d
  sh labs/break-and-fix.sh break 5
  sh labs/break-and-fix.sh hint 5
  sh labs/break-and-fix.sh verify 5
EOF
}

err() { printf '%s\n' "$*" >&2; }

need() {
  # need <contenedor> ... : corta si alguno no está corriendo.
  for c in "$@"; do
    if ! docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep -q 'true'; then
      err "ERROR: el contenedor '$c' no está corriendo."
      err "Levantá el laboratorio correspondiente y esperá ~15 s antes de usarlo."
      exit 1
    fi
  done
}

ok()  { printf '\n✅ INCIDENTE RESUELTO — %s\n' "$1"; exit 0; }
ko()  { printf '\n❌ Aún falla.\n🚦 Pista de capa OSI: %s\n' "$1"; exit 1; }

resolve_mission() {
  case "$1" in
    1|2|3|4|5|6|7|8) printf '%s' "$1" ;;
    random)
      r="$(od -An -N1 -tu1 /dev/urandom | tr -d ' ')"
      printf '%s' "$(( r % 8 + 1 ))"
      ;;
    *)
      err "Misión inválida: '$1' (usá un número del 1 al 8, o 'random')."
      exit 2
      ;;
  esac
}

list_missions() {
  cat <<'EOF'
================================================================================
  MISIONES DE GUARDIA (Break & Fix) — 8 incidentes reales
================================================================================
  #  Laboratorio requerido        Ticket que reporta el usuario
--------------------------------------------------------------------------------
  1  lab01-vlan-roas              La PC de la VLAN 10 perdió acceso al servidor de la VLAN 20
  2  lab03-ospf-and-vrrp          OSPF no pasa de EXSTART y la sucursal no aprende rutas
  3  lab03-ospf-and-vrrp          La adyacencia OSPF no se forma (tipo de red del enlace)
  4  lab03-ospf-and-vrrp          El tráfico al Data Center sale por el enlace lento
  5  lab04-nat-hairpin-mtu        El ERP abre desde Internet/4G pero NO desde la oficina
  6  lab04-nat-hairpin-mtu        Las descargas grandes se congelan (las chicas andan)
  7  integrative                  El túnel está UP, pero la sucursal ve todo con la misma IP
  8  lab03-ospf-and-vrrp          OSPF se cayó de golpe en un router (el ping directo anda)
--------------------------------------------------------------------------------
  Comandos:  break <#>   ·   hint <#>   ·   verify <#>
================================================================================
EOF
}

# -----------------------------------------------------------------------------
# MISIÓN 1 — VLAN sin servicio en el enlace ROAS (lab01)
# -----------------------------------------------------------------------------
m1_break() {
  docker exec lab01-router sh -c "ip link set dev eth0.10 type vlan id 30 2>/dev/null || true"
  cat <<'EOF'

================================================================================
  🎫 TICKET #01 — "La PC de Staff se quedó sin red"
================================================================================
  Usuario: el puesto 10.1.10.50 (VLAN 10 de Datos) no puede llegar al servidor
           de la VLAN 20 (10.1.20.10). Antes andaba. El resto de la empresa navega
           y las otras VLANs funcionan con normalidad.
  Síntoma: ping 10.1.20.10 responde "Destination Host Unreachable"/timeout.
================================================================================
EOF
}

m1_hint() {
  cat <<'EOF'
🧭 Capa 2 (Enlace de datos):
   En Router-on-a-Stick cada VLAN vive en una subinterfaz del mismo cable (trunk).
   Si el TAG de la subinterfaz del router no coincide con el de la PC, la trama
   se pierde en el enlace.
   Mirá: en el router, `ip -d link show` / `ip -d link show eth0.10`, y en el
   switch el `bridge vlan show`. Comparalo con la subinterfaz de la PC.
EOF
}

m1_verify() {
  need lab01-router lab01-pc-vlan10
  if docker exec lab01-pc-vlan10 ping -c1 -W2 10.1.20.10 >/dev/null 2>&1; then
    ok "la PC de la VLAN 10 vuelve a alcanzar el servidor de la VLAN 20."
  fi
  ko "revisá el TAG/PVID de la subinterfaz de la VLAN 10 en el router (Capa 2)."
}

# -----------------------------------------------------------------------------
# MISIÓN 2 — MTU distinta entre vecinos OSPF (lab03)
# -----------------------------------------------------------------------------
m2_break() {
  docker exec lab03-rtr2 ip link set dev eth0 mtu 1420
  docker exec lab03-rtr2 vtysh -c 'clear ip ospf process' >/dev/null 2>&1 || true
  docker exec lab03-rtr1 vtysh -c 'clear ip ospf process' >/dev/null 2>&1 || true
  cat <<'EOF'

================================================================================
  🎫 TICKET #02 — "La sucursal dejó de ver el Data Center"
================================================================================
  Usuario: desde la Sucursal (RTR2) ya no se llega a la red del Data Center.
           El ping entre routers responde perfecto, pero OSPF no aprende rutas.
  Síntoma: `show ip ospf neighbor` muestra el vecino trabado en EXSTART/EXCHANGE.
================================================================================
EOF
}

m2_hint() {
  cat <<'EOF'
🧭 Capa 3 (Red):
   La adyacencia OSPF negocia el tamaño máximo de paquete (MTU) en los paquetes
   DBD. Si los dos extremos no coinciden, queda trabada en EXSTART/EXCHANGE.
   Mirá: `ip link show eth0` en ambos routers y `show ip ospf neighbor`.
EOF
}

m2_verify() {
  need lab03-rtr1 lab03-rtr2
  if docker exec lab03-rtr1 vtysh -c 'show ip ospf neighbor' 2>/dev/null | grep '10.0.0.2' | grep -q 'Full'; then
    ok "la adyacencia OSPF con RTR2 (10.0.0.2) volvió a Full."
  fi
  ko "compará el MTU de las interfaces del enlace en ambos routers (Capa 3)."
}

# -----------------------------------------------------------------------------
# MISIÓN 3 — Tipo de red OSPF incompatible (lab03)
# -----------------------------------------------------------------------------
m3_break() {
  docker exec lab03-rtr2 vtysh -c 'configure terminal' \
    -c 'interface eth0' -c 'ip ospf network non-broadcast' -c 'exit' >/dev/null 2>&1 || true
  docker exec lab03-rtr2 vtysh -c 'clear ip ospf process' >/dev/null 2>&1 || true
  cat <<'EOF'

================================================================================
  🎫 TICKET #03 — "OSPF no levanta en un enlace que sí tiene conectividad"
================================================================================
  Usuario: el enlace entre dos routers responde por ping, pero la adyacencia
           OSPF no se forma. Las rutas dinámicas nunca aparecen.
  Síntoma: `show ip ospf neighbor` queda vacío o en INIT/DOWN.
================================================================================
EOF
}

m3_hint() {
  cat <<'EOF'
🧭 Capa 3 (Red):
   El "tipo de red" OSPF (point-to-point, broadcast, non-broadcast, ...) define
   cómo se envían los Hellos. Si un extremo espera Hellos que el otro no manda,
   la vecindad nunca se forma.
   Mirá: `show ip ospf interface eth0` en ambos routers.
EOF
}

m3_verify() {
  need lab03-rtr1 lab03-rtr2
  if docker exec lab03-rtr1 vtysh -c 'show ip ospf neighbor' 2>/dev/null | grep '10.0.0.2' | grep -q 'Full'; then
    ok "la adyacencia OSPF con RTR2 (10.0.0.2) volvió a Full."
  fi
  ko "revisá el tipo de red OSPF del enlace y que sea point-to-point en ambos (Capa 3)."
}

# -----------------------------------------------------------------------------
# MISIÓN 4 — Costos OSPF invertidos (lab03)
# -----------------------------------------------------------------------------
m4_break() {
  docker exec lab03-rtr2 vtysh -c 'configure terminal' \
    -c 'interface eth0' -c 'ip ospf cost 100' -c 'exit' \
    -c 'interface eth1' -c 'ip ospf cost 10' -c 'exit' >/dev/null 2>&1 || true
  cat <<'EOF'

================================================================================
  🎫 TICKET #04 — "Todo lo de la Sucursal va lento"
================================================================================
  Usuario: los usuarios de la Sucursal se quejan de lentitud al llegar al Data
           Center, aunque el enlace principal (fibra) está sano y el backup es
           mucho más lento.
  Síntoma: el tráfico hacia 10.3.40.0/24 sale por el enlace de respaldo.
================================================================================
EOF
}

m4_hint() {
  cat <<'EOF'
🧭 Capa 3 (Red):
   OSPF elige la ruta con el COSTO total más bajo. Un costo mal puesto hace que
   el tráfico preferido salga por el enlace lento.
   Mirá: `show ip route ospf` (Next Hop de 10.3.40.0/24) y `show ip ospf interface`.
EOF
}

m4_verify() {
  need lab03-rtr1 lab03-rtr2
  if docker exec lab03-rtr2 vtysh -c 'show ip route 10.3.40.0/24' 2>/dev/null | grep -q '10.0.255.1'; then
    ok "el tráfico al Data Center vuelve por el enlace principal."
  fi
  ko "revisá los costos OSPF de cada enlace y forzá el camino de costo bajo (Capa 3)."
}

# -----------------------------------------------------------------------------
# MISIÓN 5 — Hairpin NAT roto (lab04)
# -----------------------------------------------------------------------------
m5_break() {
  docker exec lab04-fw-borde sh -c \
    "iptables -t nat -D POSTROUTING -s 10.1.40.0/24 -d 10.1.40.10 -p tcp --dport 8080 -j MASQUERADE 2>/dev/null || true"
  cat <<'EOF'

================================================================================
  🎫 TICKET #05 — "La web interna no abre desde la oficina"
================================================================================
  Usuario: el ERP publicado (http://203.0.113.2:8080) abre perfecto desde el
           celular con datos (4G/Internet), pero desde las PCs de la propia
           oficina queda cargando y da timeout.
  Síntoma: desde el cliente externo responde; desde la PC interna, no.
================================================================================
EOF
}

m5_hint() {
  cat <<'EOF'
🧭 Capa 3/4 (NAT):
   Cuando una PC interna llama a la IP PÚBLICA del router, la respuesta del
   servidor intenta salir directo por la LAN y el cliente no la reconoce.
   Faltó el "Hairpin NAT" (una regla de srcnat/masquerade para ese tráfico).
   Mirá: `iptables -t nat -S` o `/ip firewall nat print` en el firewall.
EOF
}

m5_verify() {
  need lab04-fw-borde lab04-pc-interna
  if docker exec lab04-pc-interna sh -c \
       "curl -s -m3 http://203.0.113.2:8080 | grep -q 'Conexion Exitosa'" 2>/dev/null; then
    ok "la oficina ya puede abrir el ERP por su URL pública (Hairpin NAT OK)."
  fi
  ko "agregá la regla de Hairpin NAT (srcnat/masquerade) para el tráfico interno (Capa 3/4)."
}

# -----------------------------------------------------------------------------
# MISIÓN 6 — Agujero negro de MTU sin MSS Clamping (lab04)
# -----------------------------------------------------------------------------
m6_break() {
  docker exec lab04-srv-web sh -c "dd if=/dev/zero of=/srv/www/big.html bs=1000 count=300 2>/dev/null || true"
  docker exec lab04-fw-borde sh -c "
    ip link set dev eth0 mtu 1400;
    iptables -C OUTPUT -p icmp --icmp-type fragmentation-needed -j DROP 2>/dev/null || \
      iptables -A OUTPUT -p icmp --icmp-type fragmentation-needed -j DROP
  "
  cat <<'EOF'

================================================================================
  🎫 TICKET #06 — "Las descargas grandes se congelan"
================================================================================
  Usuario: la web del ERP abre bien, pero al bajar un archivo grande (o un PDF
           pesado) la descarga se traba al 10% y nunca termina. Los archivos
           chicos sí andan.
  Síntoma: las transferencias grandes se estancan; las pequeñas, perfectas.
================================================================================
EOF
}

m6_hint() {
  cat <<'EOF'
🧭 Capa 3/4 (MTU / MSS):
   La salida a Internet perdió MTU (como en PPPoE o una VPN) y el servidor manda
   paquetes más grandes de lo que el enlace soporta. Falta el "TCP MSS Clamping"
   para que el servidor negocie segmentos que entren por el enlace.
   Mirá: `ip link show eth0` en el firewall y `iptables -t mangle -S`.
EOF
}

m6_verify() {
  need lab04-fw-borde lab04-cliente-externo
  if docker exec lab04-cliente-externo curl -s -m6 -f -o /dev/null http://203.0.113.2:8080/big.html 2>/dev/null; then
    ok "las descargas grandes vuelven a completarse (MSS/path MTU OK)."
  fi
  ko "activá el TCP MSS Clamping en el firewall (mangle FORWARD) (Capa 3/4)."
}

# -----------------------------------------------------------------------------
# MISIÓN 7 — Masquerade general pisando el tráfico entre sedes (integrative)
# -----------------------------------------------------------------------------
m7_break() {
  docker exec rtr-sede1 iptables -t nat -I POSTROUTING 1 -s 10.1.0.0/16 -j MASQUERADE
  cat <<'EOF'

================================================================================
  🎫 TICKET #07 — "La sucursal ve toda la Casa Central con la misma IP"
================================================================================
  Usuario: el túnel entre sedes está UP y OSPF en Full, pero los servicios de la
           Sucursal reciben TODO el tráfico de la Casa Central con una única
           dirección. Algunos filtros por IP dejaron de funcionar.
  Síntoma: el tráfico entre sedes sale "camuflado" con la IP del router.
================================================================================
EOF
}

m7_hint() {
  cat <<'EOF'
🧭 Capa 3/4 (NAT):
   La regla de salida a Internet debe filtrar por INTERFAZ (out-interface / -o
   eth0). Si NAT-eás toda la subred sin filtro, también pisás el tráfico
   privado que va por el túnel hacia la otra sede.
   Mirá: `iptables -t nat -S POSTROUTING` o `/ip firewall nat print`.
EOF
}

m7_verify() {
  need rtr-sede1
  rules="$(docker exec rtr-sede1 iptables -t nat -S POSTROUTING 2>/dev/null || true)"
  # Debe existir la regla correcta (filtrada por eth0)...
  if ! printf '%s\n' "$rules" | grep -q -- '-s 10.1.0.0/16 -o eth0 -j MASQUERADE'; then
    ko "restaurá la regla de masquerade filtrada por la interfaz WAN (Capa 3/4)."
  fi
  # ...y NO debe existir una regla amplia que NAT-e toda la subred sin filtro.
  if printf '%s\n' "$rules" | grep -E -- '-s 10\.1\.0\.0/16 (-j MASQUERADE|-o (eth1|wg0))' | grep -qv 'eth0'; then
    ko "todavía hay una regla de masquerade SIN filtro de interfaz (Capa 3/4)."
  fi
  ok "el NAT quedó acotado a la salida a Internet y el tráfico entre sedes preserva su IP origen."
}

# -----------------------------------------------------------------------------
# MISIÓN 8 — Protocolo IP 89 (OSPF) bloqueado en INPUT (lab03)
# -----------------------------------------------------------------------------
m8_break() {
  docker exec lab03-rtr2 sh -c \
    "command -v iptables >/dev/null 2>&1 || (apk add --no-cache iptables >/dev/null 2>&1 || true)"
  docker exec lab03-rtr2 sh -c \
    "iptables -C INPUT -p 89 -j DROP 2>/dev/null || iptables -A INPUT -p 89 -j DROP" >/dev/null 2>&1 || true
  docker exec lab03-rtr2 vtysh -c 'clear ip ospf process' >/dev/null 2>&1 || true
  cat <<'EOF'

================================================================================
  🎫 TICKET #08 — "Se cayó OSPF en un router y no vuelve"
================================================================================
  Usuario: un router dejó de aprender rutas OSPF de repente. El ping directo
           entre los routers responde bien, pero la adyacencia no se forma.
  Síntoma: `show ip ospf neighbor` vacío, aunque hay conectividad IP.
================================================================================
EOF
}

m8_hint() {
  cat <<'EOF'
🧭 Capa 3/4 (Firewall local):
   OSPF no usa TCP ni UDP: viaja directamente sobre el protocolo IP 89. Una regla
   del firewall LOCAL del router (cadena INPUT) que dropee ese protocolo mata la
   adyacencia sin afectar al ping.
   Mirá: `iptables -S` / `/ip firewall filter print` en el router sospechoso.
EOF
}

m8_verify() {
  need lab03-rtr1 lab03-rtr2
  if docker exec lab03-rtr1 vtysh -c 'show ip ospf neighbor' 2>/dev/null | grep '10.0.0.2' | grep -q 'Full'; then
    ok "la adyacencia OSPF con RTR2 (10.0.0.2) volvió a Full (el firewall local ya no bloquea OSPF)."
  fi
  ko "revisá el firewall INPUT del router: puede estar bloqueando el protocolo IP 89 (Capa 3/4)."
}

# -----------------------------------------------------------------------------
# DISPATCH
# -----------------------------------------------------------------------------
do_break() {
  n="$(resolve_mission "$1")"
  printf 'Inyectando la misión #%s en silencio...\n' "$n"
  case "$n" in
    1) need lab01-router;                 m1_break ;;
    2) need lab03-rtr1 lab03-rtr2;        m2_break ;;
    3) need lab03-rtr1 lab03-rtr2;        m3_break ;;
    4) need lab03-rtr1 lab03-rtr2;        m4_break ;;
    5) need lab04-fw-borde lab04-pc-interna; m5_break ;;
    6) need lab04-fw-borde lab04-srv-web; m6_break ;;
    7) need rtr-sede1;                    m7_break ;;
    8) need lab03-rtr1 lab03-rtr2;        m8_break ;;
  esac
}

do_hint() {
  n="$(resolve_mission "$1")"
  case "$n" in
    1) m1_hint ;; 2) m2_hint ;; 3) m3_hint ;; 4) m4_hint ;;
    5) m5_hint ;; 6) m6_hint ;; 7) m7_hint ;; 8) m8_hint ;;
  esac
}

do_verify() {
  n="$(resolve_mission "$1")"
  case "$n" in
    1) m1_verify ;; 2) m2_verify ;; 3) m3_verify ;; 4) m4_verify ;;
    5) m5_verify ;; 6) m6_verify ;; 7) m7_verify ;; 8) m8_verify ;;
  esac
}

main() {
  cmd="${1:-}"
  arg="${2:-}"
  case "$cmd" in
    list)                list_missions ;;
    break)               do_break "$arg" ;;
    hint)                do_hint "$arg" ;;
    verify)              do_verify "$arg" ;;
    ""|-h|--help|help)   usage ;;
    *)
      err "Comando desconocido: '$cmd'"
      usage
      exit 2
      ;;
  esac
}

main "$@"
