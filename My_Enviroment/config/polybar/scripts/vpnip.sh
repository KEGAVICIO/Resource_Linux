#!/usr/bin/env bash
# Muestra la IP de la VPN si tun0 existe

IFACE="tun0"

if ip addr show "$IFACE" >/dev/null 2>&1; then
    vpns=$(ip -4 addr show "$IFACE" | awk '/inet /{print $2}' | cut -d/ -f1)
    echo " $vpns"
else
    echo " Disconnected"
fi

