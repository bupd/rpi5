#!/usr/bin/env bash
set -euo pipefail

IFACE=$(ip -4 route show default | awk '{print $5}' | head -1)
LOCAL_IP=$(ip -4 addr show "$IFACE" | awk '/inet / {split($2,a,"/"); print a[1]}')
SUBNET=$(ip -4 addr show "$IFACE" | awk '/inet / {print $2}')
GATEWAY=$(ip -4 route show default | awk '{print $3}' | head -1)

echo ""
echo "  Scanning network: $SUBNET (interface: $IFACE)"
echo ""

SCAN=$(nmap -sn "$SUBNET" 2>/dev/null)

TOTAL=0
PI_COUNT=0

# collect IPs, MACs, vendors per host
declare -a IPS=()
declare -a MACS=()
declare -a VENDORS=()

CURRENT_IP=""
CURRENT_MAC=""
CURRENT_VENDOR=""

while IFS= read -r line; do
  if [[ "$line" == *"scan report"* ]]; then
    # flush previous host
    if [[ -n "$CURRENT_IP" ]]; then
      IPS+=("$CURRENT_IP")
      MACS+=("${CURRENT_MAC:-}")
      VENDORS+=("${CURRENT_VENDOR:-}")
    fi
    CURRENT_IP=$(echo "$line" | awk '{print $NF}' | tr -d '()')
    CURRENT_MAC=""
    CURRENT_VENDOR=""
  fi

  if [[ "$line" == *"MAC Address"* ]]; then
    CURRENT_MAC=$(echo "$line" | awk '{print $3}')
    CURRENT_VENDOR=$(echo "$line" | sed 's/.*(\(.*\))/\1/')
  fi
done <<< "$SCAN"

# flush last host
if [[ -n "$CURRENT_IP" ]]; then
  IPS+=("$CURRENT_IP")
  MACS+=("${CURRENT_MAC:-}")
  VENDORS+=("${CURRENT_VENDOR:-}")
fi

TOTAL=${#IPS[@]}
echo "  $TOTAL host(s) found:"
echo ""

for i in "${!IPS[@]}"; do
  IP="${IPS[$i]}"
  MAC="${MACS[$i]}"
  VENDOR="${VENDORS[$i]}"

  if [[ "$IP" == "$LOCAL_IP" ]]; then
    LABEL="this machine"
    ICON="*"
  elif [[ "$IP" == "$GATEWAY" ]]; then
    LABEL="gateway"
    ICON=">"
  elif echo "$VENDOR" | grep -qi "raspberry"; then
    LABEL="Raspberry Pi"
    ICON="#"
    PI_COUNT=$((PI_COUNT + 1))
  else
    LABEL="unknown device"
    ICON="?"
  fi

  if [[ -n "$MAC" ]]; then
    echo "  [$ICON] $IP - $LABEL ($VENDOR) [$MAC]"
  else
    echo "  [$ICON] $IP - $LABEL"
  fi
done

echo ""
if [[ $PI_COUNT -gt 0 ]]; then
  echo "  $PI_COUNT Raspberry Pi(s) detected."
  echo ""
fi
