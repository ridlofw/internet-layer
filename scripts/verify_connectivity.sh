#!/usr/bin/env bash
# ==============================================================================
# IoT Internet Layer Laboratory - Automated Connectivity & Diagnostics Test
# Course: Internet of Things - Universitas Gadjah Mada
# ==============================================================================
set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}[ERROR]${NC} This script must be run as root: sudo bash $0" >&2
  exit 1
fi

TOTAL_TESTS=0
PASSED_TESTS=0

run_test() {
  local test_name="$1"
  local cmd="$2"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))

  echo -n -e "[TEST $TOTAL_TESTS] $test_name ... "
  if eval "$cmd" > /dev/null 2>&1; then
    echo -e "${GREEN}${BOLD}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    echo -e "${RED}${BOLD}[FAIL]${NC}"
  fi
}

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}${BOLD}       IoT Internet Layer Automated Verification Suite         ${NC}"
echo -e "${BLUE}================================================================${NC}"

# Check namespaces
echo -e "\n${BOLD}1. Verifying Network Namespaces Existence:${NC}"
run_test "Namespace 'iot-sensor' exists" "ip netns list | awk '{print \$1}' | grep -qx iot-sensor"
run_test "Namespace 'iot-router' exists" "ip netns list | awk '{print \$1}' | grep -qx iot-router"
run_test "Namespace 'iot-cloud' exists"  "ip netns list | awk '{print \$1}' | grep -qx iot-cloud"

# Check IP Forwarding on Router
echo -e "\n${BOLD}2. Verifying Router IP Forwarding Sysctls:${NC}"
run_test "Router IPv4 Forwarding Enabled (net.ipv4.ip_forward=1)" \
  "[[ \$(ip netns exec iot-router sysctl -n net.ipv4.ip_forward) -eq 1 ]]"
run_test "Router IPv6 Forwarding Enabled (net.ipv6.conf.all.forwarding=1)" \
  "[[ \$(ip netns exec iot-router sysctl -n net.ipv6.conf.all.forwarding) -eq 1 ]]"

# Check IPv4 and IPv6 Connectivity
echo -e "\n${BOLD}3. Verifying End-to-End Connectivity (Sensor -> Cloud):${NC}"
run_test "Sensor to Gateway (r0) IPv4 Ping (10.10.1.1)" \
  "ip netns exec iot-sensor ping -c 2 -W 2 10.10.1.1"
run_test "Sensor to Cloud (c0) IPv4 Ping (10.10.2.2)" \
  "ip netns exec iot-sensor ping -c 2 -W 2 10.10.2.2"
run_test "Sensor to Gateway (r0) IPv6 Ping (2001:db8:1::1)" \
  "ip netns exec iot-sensor ping -6 -c 2 -W 2 2001:db8:1::1"
run_test "Sensor to Cloud (c0) IPv6 Ping (2001:db8:2::2)" \
  "ip netns exec iot-sensor ping -6 -c 2 -W 2 2001:db8:2::2"

# Check Route Resolution
echo -e "\n${BOLD}4. Verifying Route Resolution & Next Hops:${NC}"
run_test "IPv4 Next-Hop via 10.10.1.1" \
  "ip -n iot-sensor route get 10.10.2.2 | grep -q 'via 10.10.1.1'"
run_test "IPv6 Next-Hop via 2001:db8:1::1" \
  "ip -n iot-sensor -6 route get 2001:db8:2::2 | grep -q 'via 2001:db8:1::1'"

# Check Neighbor Resolution Tables
echo -e "\n${BOLD}5. Verifying ARP and IPv6 Neighbor Cache:${NC}"
echo -e "--- IPv4 ARP Table on iot-sensor ---"
ip -n iot-sensor neigh show nud reachable || ip -n iot-sensor neigh show
echo -e "--- IPv6 Neighbor Table on iot-sensor ---"
ip -n iot-sensor -6 neigh show nud reachable || ip -n iot-sensor -6 neigh show

# Summary
echo -e "\n${BLUE}================================================================${NC}"
if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
  echo -e "${GREEN}${BOLD}Verification Complete: All $TOTAL_TESTS / $TOTAL_TESTS tests PASSED!${NC}"
  echo -e "Dual-stack internet layer topology is 100% operational."
else
  echo -e "${YELLOW}${BOLD}Verification Complete: $PASSED_TESTS / $TOTAL_TESTS tests passed.${NC}"
  echo -e "${RED}Some checks failed. Run 'sudo bash scripts/network_lab.sh status' to diagnose.${NC}"
fi
echo -e "${BLUE}================================================================${NC}"
