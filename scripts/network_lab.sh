#!/usr/bin/env bash
# ==============================================================================
# IoT Internet Layer Laboratory - Network Topology Manager
# Isolated, static, dual-stack (IPv4 & IPv6) network namespaces.
# Course: Internet of Things - Universitas Gadjah Mada
# ==============================================================================
set -euo pipefail

# ANSI Color codes for clean terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

NAMES=(iot-sensor iot-router iot-cloud)

# Privilege verification
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}[ERROR]${NC} Script must be run as root. Use: sudo bash $0 {up|down|status}" >&2
  exit 1
fi

exists() {
  ip netns list | awk '{print $1}' | grep -qx "$1"
}

remove_lab() {
  for ns in "${NAMES[@]}"; do
    if exists "$ns"; then
      ip netns del "$ns"
    fi
  done
}

status_lab() {
  echo -e "${BLUE}======================================================${NC}"
  echo -e "${BLUE}        IoT Internet Layer Topology Status            ${NC}"
  echo -e "${BLUE}======================================================${NC}"
  
  local any_active=0
  for ns in "${NAMES[@]}"; do
    if exists "$ns"; then
      any_active=1
      echo -e "\n${GREEN}[Namespace: $ns]${NC}"
      echo -e "--- Interfaces & Addresses ---"
      ip -n "$ns" -br addr
      echo -e "--- IPv4 Routes ---"
      ip -n "$ns" route
      echo -e "--- IPv6 Routes ---"
      ip -n "$ns" -6 route
    else
      echo -e "\n${YELLOW}[Namespace: $ns] NOT FOUND${NC}"
    fi
  done

  if [[ $any_active -eq 1 ]]; then
    echo -e "\n${BLUE}--- Router Forwarding Configuration ---${NC}"
    if exists "iot-router"; then
      echo -n "IPv4 forwarding: "
      ip netns exec iot-router sysctl -n net.ipv4.ip_forward
      echo -n "IPv6 forwarding: "
      ip netns exec iot-router sysctl -n net.ipv6.conf.all.forwarding
    fi
  fi
  echo -e "${BLUE}======================================================${NC}"
}

case "${1:-}" in
  down)
    echo -e "${YELLOW}[*] Tearing down IoT Internet Layer topology...${NC}"
    for ns in "${NAMES[@]}"; do
      if exists "$ns"; then
        # Check running processes inside namespace
        pids=$(ip netns pids "$ns" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
          echo -e "${RED}[ERROR]${NC} Processes still running in $ns (PIDs: $pids). Stop them before cleanup." >&2
          exit 1
        fi
      fi
    done
    remove_lab
    echo -e "${GREEN}[OK]${NC} Lab namespaces removed cleanly."
    exit 0
    ;;

  status)
    status_lab
    exit 0
    ;;

  up)
    ;;

  *)
    echo -e "Usage: sudo bash $0 {up|down|status}"
    echo -e "  up     : Create network namespaces, veth interfaces, and dual-stack routes"
    echo -e "  down   : Clean up and delete lab namespaces"
    echo -e "  status : Display current interface addresses and routing tables"
    exit 1
    ;;
esac

# Pre-flight check: ensure clean state
for ns in "${NAMES[@]}"; do
  if exists "$ns"; then
    echo -e "${RED}[ERROR]${NC} $ns already exists; clean up the previous lab first with 'sudo bash $0 down'." >&2
    exit 1
  fi
done

echo -e "${BLUE}[*] Initializing network namespaces...${NC}"
trap remove_lab ERR

# 1. Create namespaces & bring loopback up
for ns in "${NAMES[@]}"; do
  ip netns add "$ns"
  ip -n "$ns" link set lo up
done

# 2. Create veth peer connections
# Sensor (s0) <---> Router (r0)
ip -n iot-sensor link add s0 type veth peer name r0 netns iot-router
# Router (r1) <---> Cloud (c0)
ip -n iot-router link add r1 type veth peer name c0 netns iot-cloud

# 3. Configure IPv4 Subnets
# Subnet 1 (Sensor-Router): 10.10.1.0/24
ip -n iot-sensor addr add 10.10.1.2/24 dev s0
ip -n iot-router addr add 10.10.1.1/24 dev r0
# Subnet 2 (Router-Cloud): 10.10.2.0/24
ip -n iot-router addr add 10.10.2.1/24 dev r1
ip -n iot-cloud addr add 10.10.2.2/24 dev c0

# 4. Configure IPv6 Subnets (with nodad for rapid lab setup)
# Subnet 1: 2001:db8:1::/64
ip -n iot-sensor -6 addr add 2001:db8:1::2/64 dev s0 nodad
ip -n iot-router -6 addr add 2001:db8:1::1/64 dev r0 nodad
# Subnet 2: 2001:db8:2::/64
ip -n iot-router -6 addr add 2001:db8:2::1/64 dev r1 nodad
ip -n iot-cloud -6 addr add 2001:db8:2::2/64 dev c0 nodad

# 5. Bring link interfaces up
ip -n iot-sensor link set s0 up
ip -n iot-router link set r0 up
ip -n iot-router link set r1 up
ip -n iot-cloud link set c0 up

# 6. Enable routing & packet forwarding in iot-router
ip netns exec iot-router sysctl -qw net.ipv4.ip_forward=1
ip netns exec iot-router sysctl -qw net.ipv6.conf.all.forwarding=1

# 7. Install static routes
# IPv4 static routing
ip -n iot-sensor route add 10.10.2.0/24 via 10.10.1.1
ip -n iot-cloud route add 10.10.1.0/24 via 10.10.2.1
# IPv6 static routing
ip -n iot-sensor -6 route add 2001:db8:2::/64 via 2001:db8:1::1
ip -n iot-cloud -6 route add 2001:db8:1::/64 via 2001:db8:2::1

trap - ERR
echo -e "${GREEN}[OK] READY: iot-sensor <-> iot-router <-> iot-cloud${NC}"
echo -e "Run 'sudo bash $0 status' to inspect configured IP addresses and routes."
