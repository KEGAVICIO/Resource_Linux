#!/bin/bash

echo "[*] Iniciando la instalación de tu entorno Red Team..."

# 1. Detectar el gestor de paquetes e instalar dependencias
echo "[*] Detectando tu distribución de Linux..."

if command -v pacman &> /dev/null; then
    echo "[+] Arch Linux detectado. Usando pacman..."
    sudo pacman -Syu --needed bspwm sxhkd polybar rofi kitty picom zsh zsh-theme-powerlevel10k obsidian ttf-hack-nerd

elif command -v apt &> /dev/null; then
    echo "[+] Debian/Ubuntu/Kali detectado. Usando apt..."
    sudo apt update
    sudo apt install -y bspwm sxhkd polybar rofi kitty picom zsh fonts-hack-ttf

elif command -v dnf &> /dev/null; then
    echo "[+] Fedora detectado. Usando dnf..."
    sudo dnf install -y bspwm sxhkd polybar rofi kitty picom zsh

else
    echo "[!] No se reconoció el gestor de paquetes (pacman, apt o dnf)."
    echo "[!] Por favor, instala las dependencias manualmente."
    exit 1
fi

# 2. Crear el directorio principal de configuraciones si no existe
echo "[*] Preparando directorios..."
mkdir -p ~/.config

# 3. Copiar todas las configuraciones al sistema
echo "[*] Copiando tus dotfiles..."
# Copia todo lo que está dentro de tu carpeta config/ hacia ~/.config/
cp -r config/* ~/.config/

# Copia los archivos ocultos de tu terminal a la raíz de tu usuario
cp .zshrc ~/.zshrc
cp .p10k.zsh ~/.p10k.zsh

# 4. Asignar permisos de ejecución a los scripts
echo "[*] Dando permisos de ejecución a los scripts clave..."
chmod +x ~/.config/bspwm/bspwmrc
chmod +x ~/.config/polybar/launch.sh
chmod +x ~/.config/polybar/scripts/*.sh

echo "[*] ¡Entorno instalado con éxito!"
echo "[*] IMPORTANTE: Escribe 'zsh' en tu terminal para aplicar el nuevo shell."
echo "[*] Presiona Super + Alt + R para recargar bspwm."
