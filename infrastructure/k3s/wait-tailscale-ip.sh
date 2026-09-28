#!/bin/sh
# Install on k3s-master: /usr/local/bin/wait-tailscale-ip (mode 0755)
# Runs as ExecStartPre of k3s.service - see k3s-wait-tailscale.conf and ADR-019.
#
# k3s (flannel-iface: tailscale0, node-ip 100.84.89.67) cannot start until tailscale0
# carries its IPv4 address. On 2026-09-28 tailscaled came up after a reboot WITHOUT that
# address, and k3s looped on "no IPv4 address found for interface tailscale0" until
# tailscaled was restarted by hand. This waits, restarts tailscaled once if needed,
# and otherwise fails so systemd retries k3s (Restart=always).

WAIT_SECONDS=60

has_ip() {
  addr=$(tailscale ip -4 2>/dev/null)
  [ -n "$addr" ] && ip -4 addr show dev tailscale0 2>/dev/null | grep -q "inet $addr/"
}

wait_for_ip() {
  i=0
  while [ "$i" -lt "$WAIT_SECONDS" ]; do
    has_ip && return 0
    sleep 1
    i=$((i + 1))
  done
  return 1
}

wait_for_ip && exit 0

logger -t wait-tailscale-ip "tailscale0 has no IPv4 after ${WAIT_SECONDS}s, restarting tailscaled"
systemctl restart tailscaled
wait_for_ip && exit 0

logger -t wait-tailscale-ip "tailscale0 still has no IPv4 after restart, k3s will retry"
exit 1
