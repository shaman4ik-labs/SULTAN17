#!/usr/bin/env bash
# Next-pass Sultan17 gs201 only. Do NOT run in the current ReSukiSU bump.
# Sultan CONFIG_INTEGRATE_MODULES=y → every symbol must be =y, never =m.
#
# Usage:
#   inject-netfilter-tproxy.sh <path/to/arch/arm64/configs/gs201_defconfig>
#   inject-netfilter-tproxy.sh --verify <path/to/.config>
set -euo pipefail

# TPROXY target already selects NF_TPROXY_IPV4/IPV6.
# IP6_NF_NAT is the real hole on public gs201_defconfig (no ip6tables -t nat).
# XT_TARGET_TPROXY / XT_MATCH_SOCKET / REDIRECT / mangle / policy routing
# are already =y in the tree; we force them so olddefconfig cannot drop them.
SYMS_Y=(
  CONFIG_NETFILTER=y
  CONFIG_NETFILTER_ADVANCED=y
  CONFIG_NF_CONNTRACK=y
  CONFIG_NF_NAT=y
  CONFIG_NF_NAT_REDIRECT=y
  CONFIG_NF_TPROXY_IPV4=y
  CONFIG_NF_TPROXY_IPV6=y
  CONFIG_NF_SOCKET_IPV4=y
  CONFIG_NF_SOCKET_IPV6=y
  CONFIG_NETFILTER_XT_TARGET_TPROXY=y
  CONFIG_NETFILTER_XT_MATCH_SOCKET=y
  CONFIG_NETFILTER_XT_TARGET_MARK=y
  CONFIG_IP_NF_IPTABLES=y
  CONFIG_IP_NF_MANGLE=y
  CONFIG_IP_NF_NAT=y
  CONFIG_IP_NF_TARGET_REDIRECT=y
  CONFIG_IP6_NF_IPTABLES=y
  CONFIG_IP6_NF_MANGLE=y
  CONFIG_IP6_NF_NAT=y
  CONFIG_IP6_NF_TARGET_MASQUERADE=y
  CONFIG_IP_ADVANCED_ROUTER=y
  CONFIG_IP_MULTIPLE_TABLES=y
  CONFIG_IPV6_MULTIPLE_TABLES=y
  # VpnService (Surfshark). Compass stays TPROXY/REDIRECT, not this TUN.
  CONFIG_TUN=y
)

# CONFIG_VPN is unused by Compass; leave unset (not the tun char device).
SYMS_N=(
  CONFIG_VPN
)

force_y() {
  local cfg=$1 line=$2
  local key=${line%%=*}
  if grep -qE "^(# ${key} is not set|${key}=)" "$cfg"; then
    sed -i -E "s/^# ${key} is not set$/${line}/; s/^${key}=.*/${line}/" "$cfg"
  else
    printf '%s\n' "$line" >> "$cfg"
  fi
}

force_n() {
  local cfg=$1 key=$2
  if grep -qE "^${key}=" "$cfg"; then
    sed -i -E "s/^${key}=.*/# ${key} is not set/" "$cfg"
  fi
}

verify() {
  local cfg=$1 rc=0
  local line key
  for line in "${SYMS_Y[@]}"; do
    key=${line%%=*}
    if grep -qE "^${key}=y$" "$cfg"; then
      echo "cfg OK   ${key}=y"
    else
      echo "::error::cfg MISSING ${key}=y"
      rc=1
    fi
  done
  for key in "${SYMS_N[@]}"; do
    if grep -qE "^${key}=[ym]$" "$cfg"; then
      echo "::error::cfg FORBIDDEN ${key} is set"
      rc=1
    else
      echo "cfg OK   ${key} unset"
    fi
  done
  return "$rc"
}

if [ "${1:-}" = "--verify" ]; then
  [ -n "${2:-}" ] && [ -f "$2" ] || { echo "usage: $0 --verify <config>"; exit 2; }
  verify "$2"
  exit
fi

CFG=${1:-}
[ -n "$CFG" ] && [ -f "$CFG" ] || { echo "usage: $0 <gs201_defconfig>"; exit 2; }

for line in "${SYMS_Y[@]}"; do
  force_y "$CFG" "$line"
done
for key in "${SYMS_N[@]}"; do
  force_n "$CFG" "$key"
done
echo "netfilter tproxy/ip6nat forced into $CFG"
verify "$CFG"
