#!/bin/bash
# CachyInstaller — centralized constants
# All magic numbers and shared literals live here.
# Source this file before scripts/common.sh.

[ -n "${_CONSTANTS_LOADED:-}" ] && return 0
_CONSTANTS_LOADED=1

# Minimum free disk space required before installation (in kilobytes = 2 GB)
readonly MIN_DISK_KB=2097152

# Total number of installation steps shown in the progress header
readonly TOTAL_STEPS=8

# Fisher plugin manager install script URL
readonly FISHER_URL="https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish"

# SHA256 checksum of the Fisher install script
# Update this value when Fisher releases a new version:
#   curl -sL "$FISHER_URL" | sha256sum
readonly FISHER_CHECKSUM="<PENDING_UPDATE>"
