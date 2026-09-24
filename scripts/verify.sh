#!/bin/bash
# Post-reboot verification for cachyinstaller.
#
# Run this AFTER rebooting into the freshly enhanced system — it checks
# live, booted state (kernel params, loaded drivers, active services) that
# the install log genuinely cannot: the log only shows what happened during
# install, under installer-specific conditions (high load, no real boot
# cycle yet). This is what actually confirms the install worked, not just
# that commands were issued.
#
# Entirely read-only: no writes, no package operations, no service changes.
# Safe to run any time, repeatedly.
#
# Usage: bash verify.sh [--verbose]

set -uo pipefail

VERBOSE=false
[[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]] && VERBOSE=true

if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[38;2;62;147;175m'; MUTED='\033[38;2;108;112;134m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; MUTED=''; BOLD=''; RESET=''
fi

PASS=0
WARN=0
FAIL=0

ok()   { printf "  ${GREEN}✓${RESET} %s\n" "$1"; PASS=$((PASS+1)); }
warn() { printf "  ${YELLOW}⚠${RESET} %s\n" "$1"; WARN=$((WARN+1)); }
bad()  { printf "  ${RED}✗${RESET} %s\n" "$1"; FAIL=$((FAIL+1)); }
info() { [[ "$VERBOSE" == true ]] && printf "  ${MUTED}·${RESET} %s\n" "$1"; }
section() { printf "\n${BOLD}${BLUE}── %s ──${RESET}\n" "$1"; }

section "Boot"

if [ -d /sys/firmware/efi ]; then
  ok "Booted via UEFI"
else
  warn "Booted via BIOS/legacy — expected on some systems, just noting it"
fi

cmdline=$(cat /proc/cmdline 2>/dev/null || echo "")
if [[ -n "$cmdline" ]]; then
  ok "Kernel command line is populated"
  info "cmdline: $cmdline"
else
  bad "Could not read /proc/cmdline"
fi

if sudo test -d /boot/grub 2>/dev/null || sudo test -d /boot/grub2 2>/dev/null; then
  ok "GRUB installation present"
elif sudo test -d /boot/loader/entries 2>/dev/null || sudo test -d /efi/loader/entries 2>/dev/null; then
  ok "systemd-boot entries present"
else
  warn "Neither GRUB nor systemd-boot entries detected — verify your bootloader manually"
fi

section "CPU & GPU drivers"

cpu_vendor="unknown"
grep -qi "GenuineIntel" /proc/cpuinfo 2>/dev/null && cpu_vendor="intel"
grep -qi "AuthenticAMD" /proc/cpuinfo 2>/dev/null && cpu_vendor="amd"
ok "CPU vendor: ${cpu_vendor}"

if command -v lspci &>/dev/null; then
  gpu_lines=$(lspci -k 2>/dev/null | grep -A3 -iE 'vga|3d controller|display controller')
  if echo "$gpu_lines" | grep -qi "kernel driver in use"; then
    while IFS= read -r drv; do
      ok "GPU kernel driver in use: $drv"
    done < <(echo "$gpu_lines" | grep -i "kernel driver in use" | sed 's/.*: //' | sort -u)
  else
    warn "No GPU kernel driver reported by lspci -k — may still be fine on some setups"
  fi
else
  info "lspci not available, skipping GPU driver check"
fi

section "Storage"

if command -v lsblk &>/dev/null; then
  while IFS= read -r dev; do
    [[ -z "$dev" ]] && continue
    sched_file="/sys/block/$dev/queue/scheduler"
    if [[ -r "$sched_file" ]]; then
      active=$(grep -oE '\[[a-z-]+\]' "$sched_file" 2>/dev/null | tr -d '[]')
      ok "/dev/$dev I/O scheduler: ${active:-unknown}"
    fi
  done < <(lsblk -dn -o NAME 2>/dev/null | grep -vE '^(loop|sr|zram)')
fi

if grep -qE '^\S+\s+/\s+btrfs' /proc/mounts 2>/dev/null; then
  ok "Root filesystem: btrfs"
  if command -v snapper &>/dev/null; then
    if sudo snapper -c root list &>/dev/null; then
      snap_count=$(sudo snapper -c root list 2>/dev/null | awk 'NR>2 && $1 ~ /^[0-9]+$/ {count++} END {print count+0}')
      ok "Snapper is working (${snap_count:-0} existing snapshots)"
      if pacman -Q snap-pac &>/dev/null; then
        ok "snap-pac hook present (pacman snapshots)"
      else
        warn "snap-pac not installed — no auto-snapshot on pacman transactions"
      fi
    else
      bad "'sudo snapper -c root list' failed — snapshots are not working. Check 'sudo btrfs subvolume list /' and /etc/fstab."
    fi
  else
    info "snapper not installed — snapshot checks skipped (expected unless you use btrfs snapshots)"
  fi
elif grep -qE '^\S+\s+/\s+ext4' /proc/mounts 2>/dev/null; then
  ok "Root filesystem: ext4"
fi

section "Security"

if command -v ufw &>/dev/null; then
  if sudo ufw status 2>/dev/null | grep -q "^Status: active"; then
    ok "UFW is active"
  else
    bad "UFW is installed but not active"
  fi
else
  warn "No firewall found (ufw)"
fi

if systemctl is-active --quiet fail2ban 2>/dev/null; then
  jails=$(sudo fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*://;s/,/ /g; s/^[[:space:]]*//')
  if [[ -n "$jails" ]]; then
    ok "fail2ban active, jails: $jails"
    if echo "$jails" | grep -qw sshd; then
      ok "sshd jail is active"
    else
      bad "sshd jail is NOT in the active jail list — SSH is not protected"
    fi
  else
    bad "fail2ban is running but reports zero active jails — check 'sudo fail2ban-client status' and /etc/fail2ban/jail.local"
  fi
elif systemctl list-unit-files fail2ban.service &>/dev/null; then
  bad "fail2ban is installed but not running"
else
  info "fail2ban not installed — skipping"
fi

section "Networking"

if command -v ethtool &>/dev/null; then
  wol_checked=false
  for iface in /sys/class/net/*; do
    ifname=$(basename "$iface")
    [[ "$ifname" == "lo" ]] && continue
    [[ -d "$iface/wireless" ]] && continue
    if ethtool "$ifname" 2>/dev/null | grep -q "Supports Wake-on"; then
      wol_checked=true
      wol_now=$(ethtool "$ifname" 2>/dev/null | awk -F': ' '/Wake-on/{print $2; exit}')
      if [[ "$wol_now" == "g" ]]; then
        ok "Wake-on-LAN enabled on $ifname (Wake-on: g)"
      else
        warn "$ifname supports Wake-on-LAN but it's currently '$wol_now', not 'g' — check the wol-$ifname.service / udev rule"
      fi
    fi
  done
  [[ "$wol_checked" == false ]] && info "No Wake-on-LAN-capable wired interface found — expected on laptops/Wi-Fi-only systems"
else
  info "ethtool not available, skipping Wake-on-LAN check"
fi

section "Maintenance timers"

if systemctl is-enabled --quiet paccache.timer 2>/dev/null; then
  ok "paccache.timer enabled (pacman cache pruning)"
else
  warn "paccache.timer not enabled — pacman cache will grow unbounded"
fi
if systemctl is-enabled --quiet fstrim.timer 2>/dev/null; then
  ok "fstrim.timer enabled (periodic SSD TRIM)"
else
  info "fstrim.timer not enabled (expected on HDD-only systems)"
fi

section "Shell & tools"

current_shell=$(getent passwd "${USER:-$(whoami)}" 2>/dev/null | cut -d: -f7)
if [[ "$current_shell" == *fish* ]]; then
  ok "Default shell is fish"
else
  warn "Default shell is '$current_shell', not fish — log out and back in if you just installed, or check 'chsh -l'"
fi
if command -v starship &>/dev/null; then ok "Starship prompt installed"; else warn "Starship not found"; fi
if command -v fish &>/dev/null; then ok "Fish shell installed"; else bad "Fish shell not found"; fi

if command -v paru &>/dev/null; then
  ok "paru (AUR helper) installed"
elif command -v yay &>/dev/null; then
  ok "yay (AUR helper) installed"
else
  warn "No AUR helper found (paru/yay)"
fi

if pacman -Q steam &>/dev/null || pacman -Q gamemode &>/dev/null; then
  section "Gaming"
  if command -v gamemoded &>/dev/null; then ok "GameMode installed"; else warn "gamemode package present but gamemoded not found"; fi
  pacman -Q steam &>/dev/null && ok "Steam installed"
fi

echo ""
printf "${BOLD}── Summary: ${GREEN}%d passed${RESET}${BOLD}, ${YELLOW}%d warnings${RESET}${BOLD}, ${RED}%d failed${RESET}${BOLD} ──${RESET}\n" "$PASS" "$WARN" "$FAIL"
echo ""
if [[ "$FAIL" -gt 0 ]]; then
  echo "Some checks failed — worth investigating before considering this a clean install."
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo "No failures, but a few things worth a look above."
  exit 0
else
  echo "Everything checked out."
  exit 0
fi
