#!/usr/bin/env bash
set -euo pipefail

ROFI="${ROFI_BIN:-/usr/bin/rofi}"
THEME="${HOME}/.config/rofi/wifimenu.rasi"

# Detectar interfaz Wi-Fi
WIFI_IF="$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')"
[ -z "${WIFI_IF}" ] && { notify-send "Wi-Fi" "No Wi-Fi device found"; exit 1; }

# Pausar sxhkd mientras está el menú
if pgrep -x sxhkd >/dev/null 2>&1; then
  pkill -STOP sxhkd
  trap 'pkill -CONT sxhkd >/dev/null 2>&1 || true' EXIT
fi

# SSID actual y estado de radio
CURRENT_SSID="$(nmcli -t -f ACTIVE,SSID dev wifi | awk -F: '$1=="yes"{print substr($0,5)}')"
radio_state="$(nmcli -t -f WIFI radio)"   # "enabled" | "disabled"

# Listar redes (IN-USE:SSID:SIGNAL:SECURITY), desescapar "\:"
mapfile -t raw <<<"$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list ifname "$WIFI_IF" --rescan yes | sed 's/\\:/:/g')"

options=()
ssids=()

for line in "${raw[@]}"; do
  IFS=: read -r inuse ssid signal security <<<"$line"
  [ -z "${ssid}" ] && continue  # ocultar SSID vacío (red oculta)

  # Indicador actual
  if [[ "$inuse" == "*" ]] || [[ "$ssid" == "$CURRENT_SSID" ]]; then
    dot="●"
  else
    dot="○"
  fi

  # Barras por nivel
  s=${signal:-0}
  if   (( s >= 75 )); then bars="▂▄▆█"
  elif (( s >= 50 )); then bars="▂▄▆ "
  elif (( s >= 25 )); then bars="▂▄  "
  else                     bars="▂   "
  fi

  # Fila visible
  options+=( "$(printf "%s  %s  [%s %s%%]  (%s)" "$dot" "$ssid" "$bars" "${signal:-0}" "${security:---}")" )
  ssids+=( "$ssid" )
done

# Añadir "Disconnect" solo si hay red actual
if [[ -n "$CURRENT_SSID" ]]; then
  options+=( "  Disconnect ($CURRENT_SSID)" )
  ssids+=( "__DISCONNECT__" )
  # Opción para olvidar la red
  options+=( "  Forget ($CURRENT_SSID)" )
  ssids+=( "__FORGET__" )
fi

# Toggle de radio Wi-Fi
if [[ "$radio_state" == "enabled" ]]; then
  options+=( "  Disable Wi-Fi" )
  ssids+=( "__WIFI_OFF__" )
else
  options+=( "  Enable Wi-Fi" )
  ssids+=( "__WIFI_ON__" )
fi

# Mostrar menú y obtener índice
idx="$(
  printf '%s\n' "${options[@]}" |
  "${ROFI}" -no-config -markup-rows -dmenu -i -p "Wi-Fi" \
    -location 3 -xoffset -45 -yoffset 45 \
    ${THEME:+-theme "$THEME"} \
    -format i
)" || exit 0

choice_ssid="${ssids[$idx]}"
[ -z "${choice_ssid}" ] && exit 0

# Acciones especiales
if [[ "${choice_ssid}" == "__DISCONNECT__" ]]; then
  nmcli device disconnect "$WIFI_IF" && notify-send "Wi-Fi" "Disconnected"
  exit 0
elif [[ "${choice_ssid}" == "__FORGET__" ]]; then
  # Esta es la nueva acción que borra la red guardada
  nmcli connection delete "$CURRENT_SSID" && notify-send "Wi-Fi" "Forgot $CURRENT_SSID"
  exit 0
elif [[ "${choice_ssid}" == "__WIFI_OFF__" ]]; then
  nmcli radio wifi off && notify-send "Wi-Fi" "Wi-Fi disabled"
  exit 0
elif [[ "${choice_ssid}" == "__WIFI_ON__" ]]; then
  nmcli radio wifi on && notify-send "Wi-Fi" "Wi-Fi enabled"
  exit 0
fi

# Si ya está conectado a esa SSID, avisar
if [[ "$choice_ssid" == "$CURRENT_SSID" ]]; then
  notify-send "Wi-Fi" "Already connected to $choice_ssid"
  exit 0
fi

# ¿Requiere password?
security="$(nmcli -t -f SSID,SECURITY dev wifi list ifname "$WIFI_IF" | sed 's/\\:/:/g' | awk -F: -v s="$choice_ssid" '$1==s{print $2; exit}')"

# 1. Comprobar si la red YA está guardada en NetworkManager
if nmcli connection show "$choice_ssid" >/dev/null 2>&1; then
  if nmcli connection up id "$choice_ssid" >/dev/null 2>&1; then
    notify-send "Wi-Fi" "Connected to $choice_ssid"
    exit 0
  else
    notify-send "Wi-Fi" "Error connecting to saved network."
    exit 1
  fi
fi

# 2. Si es una red NUEVA y REQUIERE contraseña
if [[ -n "$security" && "$security" != "--" ]]; then
  pass="$(
    "${ROFI}" -no-config -dmenu -password -p "" \
      -mesg "Password for <b>${choice_ssid}</b>" \
      -location 3 -xoffset -45 -yoffset 45 \
      ${THEME:+-theme "$THEME"} \
      -lines 0 -markup-rows \
      -theme-str 'mainbox { children: [ message, inputbar ]; }' \
      -theme-str 'message { background-color: @bg; text-color: @fg; padding: 6px 10px; }' \
      -theme-str 'entry { background-color: @bg; text-color: @fg; }' < /dev/null
  )" || exit 0

  [ -z "$pass" ] && exit 0

  if nmcli dev wifi connect "$choice_ssid" password "$pass" ifname "$WIFI_IF" >/dev/null 2>&1; then
    notify-send "Wi-Fi" "Connected to $choice_ssid"
  else
    notify-send "Wi-Fi" "Failed to connect (Wrong password?)"
  fi
else
  # 3. Red NUEVA pero ABIERTA (Sin contraseña)
  if nmcli dev wifi connect "$choice_ssid" ifname "$WIFI_IF" >/dev/null 2>&1; then
    notify-send "Wi-Fi" "Connected to $choice_ssid"
  else
    notify-send "Wi-Fi" "Failed to connect"
  fi
fi
