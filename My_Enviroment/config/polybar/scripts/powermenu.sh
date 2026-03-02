#!/usr/bin/env bash
set -euo pipefail

ROFI="${ROFI_BIN:-/usr/bin/rofi}"
THEME="${HOME}/.config/rofi/powermenu.rasi"

# Pausar sxhkd para evitar atajos mientras está el menú
if pgrep -x sxhkd >/dev/null 2>&1; then
  pkill -STOP sxhkd
  trap 'pkill -CONT sxhkd >/dev/null 2>&1 || true' EXIT
fi

# Detectar locker
lock_screen() {
  if command -v betterlockscreen >/dev/null 2>&1; then
    betterlockscreen -l
  elif command -v i3lock >/dev/null 2>&1; then
    i3lock -n
  elif command -v xlock >/dev/null 2>&1; then
    xlock
  else
    notify-send "No hay locker instalado" "Instala betterlockscreen o i3lock"
    return 1
  fi
}

# Opciones (con iconos nerd-font opcionales)
OPTIONS=$'  Bloq\n  Suspend\n  Reboot\n  Shutdown\n󰍃  Logout'

choice="$(printf "%s" "$OPTIONS" | "${ROFI}" -no-config -dmenu -i -p "Profile" ${THEME:+-theme "$THEME"})" || exit 0

case "$choice" in
  "  Bloq"|Bloq)
    lock_screen
    ;;
  "  Suspend"|Suspend)
    systemctl suspend
    ;;
  "  Reboot"|Reboot)
    systemctl reboot
    ;;
  "  Shutdown"|Shutdown)
    systemctl poweroff
    ;;
  "󰍃  Logout"|"Logout")
      # Cerrar sesión en bspwm
      bspc quit || true
      # Como fallback: terminar la sesión actual
      #loginctl terminate-session "$(loginctl | awk '/tty|pts/{print $1; exit}')" || loginctl kill-user "$USER" || true
    ;;
  *)
    exit 0
    ;;
esac

