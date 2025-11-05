#!/usr/bin/env bash
#
# AMD BC-250 Undervolt Control Menu (single self-contained script)
# Modes:
#  1) Gaming mode      - loop 2000 MHz / 925 mV
#  2) Balanced mode    - loop 1500 MHz / 810 mV
#  3) Power saving     - loop 1000 MHz / 700 mV
#  4) Restore stock    - reset OD table (no loop)
#
# NOTE:
# - This script assumes the BC-250 is exposed as /sys/class/drm/card1
# - Requires amdgpu OverDrive/PP features enabled (e.g. amdgpu.ppfeaturemask=0xffffffff)
# - Use at your own risk. Undervolting/overclocking can cause instability or damage.

DEV="/sys/class/drm/card1/device/pp_od_clk_voltage"
PIDFILE="/run/bc250-uv-loop.pid"

require_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo:"
    echo "  sudo ./bc250-control.sh"
    exit 1
  fi
}

wait_for_device() {
  while [ ! -e "$DEV" ]; do
    echo "Waiting for $DEV ..."
    sleep 2
  done
}

stop_loop() {
  # Kill by PID file if present
  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
      echo "Stopping undervolt loop (PID $PID) ..."
      kill "$PID" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
  fi

  # Extra safety: kill any stray loop processes
  pkill -f "bc250-uv-mode-loop" 2>/dev/null || true
}

start_loop() {
  local mhz="$1"
  local mv="$2"

  # Stop any previous loop first
  stop_loop

  echo "Starting undervolt loop: ${mhz} MHz / ${mv} mV ..."
  (
    echo "BC-250 undervolt mode loop started: ${mhz} MHz / ${mv} mV" >&2
    # Tag this process name so pkill can find it easily
    exec -a bc250-uv-mode-loop bash -c '
      DEV="'"$DEV"'"
      MHZ="'"$mhz"'"
      MV="'"$mv"'"
      while true; do
        if [ -e "$DEV" ]; then
          echo "vc 0 ${MHZ} ${MV}" > "$DEV" 2>/dev/null
          echo c                   > "$DEV" 2>/dev/null
        fi
        sleep 5
      done
    '
  ) &
  echo $! > "$PIDFILE"
  echo "Loop started with PID $(cat "$PIDFILE")."
}

gaming_mode() {
  echo "[Gaming mode] 2000 MHz / 925 mV (loop)"
  start_loop 2000 925
}

balanced_mode() {
  echo "[Balanced mode] 1500 MHz / 810 mV (loop)"
  start_loop 1500 810
}

power_saving_mode() {
  echo "[Power saving mode] 1000 MHz / 700 mV (loop)"
  start_loop 1000 700
}

restore_stock() {
  echo "[Restore stock] Stopping loops and resetting OD..."
  stop_loop
  echo "r" > "$DEV" 2>/dev/null
  sleep 1
  echo "Current OD state:"
  cat "$DEV"
}

show_menu() {
  clear
  cat << 'BANNER'
 ________  ________                  _______  ________  ________            
|\   __  \|\   ____\                /  ___  \|\   ____\|\   __  \           
\ \  \|\ /\ \  \___|  ____________ /__/|_/  /\ \  \___|\ \  \|\  \          
 \ \   __  \ \  \    |\____________\__|//  / /\ \_____  \ \  \\\  \         
  \ \  \|\  \ \  \___\|____________|   /  /_/__\|____|\  \ \  \\\  \        
   \ \_______\ \_______\              |\________\____\_\  \ \_______\       
    \|_______|\|_______|               \|_______|\_________\|_______|       
                                                \|_________|                
                                                                            
                                                                            
 ________  ________  ________   _________  ________  ________  ___          
|\   ____\|\   __  \|\   ___  \|\___   ___\\   __  \|\   __  \|\  \         
\ \  \___|\ \  \|\  \ \  \\ \  \|___ \  \_\ \  \|\  \ \  \|\  \ \  \        
 \ \  \    \ \  \\\  \ \  \\ \  \   \ \  \ \ \   _  _\ \  \\\  \ \  \       
  \ \  \____\ \  \\\  \ \  \\ \  \   \ \  \ \ \  \\  \\ \  \\\  \ \  \____  
   \ \_______\ \_______\ \__\\ \__\   \ \__\ \ \__\\ _\\ \_______\ \_______\
    \|_______|\|_______|\|__| \|__|    \|__|  \|__|\|__|\|_______|\|_______|
                                                                            
                                                                            
BANNER
  echo
  echo " AMD BC-250 Undervolt Control"
  echo
  echo " [1] Gaming mode      (loop 2000 MHz / 925 mV)"
  echo " [2] Balanced mode    (loop 1500 MHz / 810 mV)"
  echo " [3] Power saving     (loop 1000 MHz / 700 mV)"
  echo " [4] Restore stock OD table (no loop)"
  echo " [0] Exit"
  echo
}

main() {
  require_root
  wait_for_device

  while true; do
    show_menu
    read -rp "Choose an option: " opt
    case "$opt" in
      1)
        gaming_mode
        read -rp "Press Enter to return to menu..."
        ;;
      2)
        balanced_mode
        read -rp "Press Enter to return to menu..."
        ;;
      3)
        power_saving_mode
        read -rp "Press Enter to return to menu..."
        ;;
      4)
        restore_stock
        read -rp "Press Enter to return to menu..."
        ;;
      0)
        echo "Exiting..."
        exit 0
        ;;
      *)
        echo "Invalid option."
        sleep 1
        ;;
    esac
  done
}

main
