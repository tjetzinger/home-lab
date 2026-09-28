# ADR-019: Keep k3s-master's Own LAN Out of Tailscale's Routing Table

**Status:** Accepted
**Date:** 2026-09-28
**Related:** [ADR-016](ADR-016-cluster-update-campaign.md) (the upgrade that added kube-proxy metrics)

## Context

From **2026-09-24 03:14 UTC** Prometheus could not reach the control-plane node. All five of the
master's scrape targets were down - kube-proxy (`:10249`), three kubelet endpoints (`:10250`) and
node-exporter (`:9100`) - producing 5 of the 11 active alerts. Nobody noticed for four days because
`TargetDown` is a `warning`, and only `critical` reaches the phone.

It was not a firewall (`ufw` inactive), not a reboot, and not any change made on 2026-09-21/22.

### The evidence

A pod on k3s-worker-01 reached k3s-worker-01's node-exporter in 10 ms. Every port on the master
timed out. A packet capture on the master during one failing connection showed why:

```
eth0        In   192.168.2.22.52179 > 192.168.2.20.9100    SYN arrives over the LAN
tailscale0  Out  192.168.2.20.9100  > 192.168.2.22.52179   SYN-ACK leaves via Tailscale
```

**Asymmetric routing.** The reply never reaches worker-02 as a valid answer, so the client
retransmits until it times out.

### The mechanism

Tailscale on Linux uses policy routing. Its rule `5270: lookup 52` is evaluated **before**
`32766: lookup main`, and on the master table 52 held:

```
192.168.2.0/24 dev tailscale0
```

So a route into the tunnel beat the master's directly-connected `192.168.2.0/24 dev eth0`.

That route exists because the master both **accepts** subnet routes (`RouteAll: true`, set by
`--accept-routes` in `infrastructure/k3s/README.md`) and sits on a subnet another node advertises:

| Node | Advertises | Primary on 2026-09-28 |
|---|---|---|
| k3s-master | `192.168.2.0/24` | no - standby |
| `nas` (Synology, since 2023) | `192.168.2.0/24` | **yes** |

Two advertisers of one prefix form a Tailscale high-availability pair with one elected primary.
While the master was primary it installed no route to its own LAN, and everything worked. With `nas`
primary, the master sends its LAN traffic to `nas` through the tunnel.

**Inferred, not proven:** the primary moved to `nas` at 09-24 03:14. Tailscale does not move it back
while `nas` stays healthy. Without a fix this recurs on every future flip.

### Why it hid

Only connections **initiated to the master's LAN IP from the LAN** broke:

- Flannel runs over `100.x` Tailscale addresses (`flannel-iface: tailscale0`) - unaffected.
- k3s agents use the advertise address `100.84.89.67` after bootstrap - unaffected.
- Traffic the master initiates goes out through `nas` and returns the same way - slow, but works.

### Upstream

This is known, open Tailscale behaviour: issues #1227, #14995, #15055. A March 2026 comment on
#14995 describes this exact symptom on k3s with flannel. Tailscale prefers tailnet routes even over
a local LAN on purpose, so a coffee-shop network with the same DHCP range cannot silently bypass
encryption.

## Decision

Add Tailscale's documented workaround (*LAN traffic prioritization with overlapping subnet routes*)
on k3s-master:

```bash
ip rule add to 192.168.2.0/24 priority 2500 lookup main
```

Priority 2500 is evaluated ahead of Tailscale's 5200-5500 range. Traffic **to** the master's own LAN
uses `main`, and so `eth0`, whatever table 52 holds.

The rule is not persistent, so it is installed as a systemd oneshot:
[`infrastructure/k3s/tailscale-lan-rule.service`](../../infrastructure/k3s/tailscale-lan-rule.service).
Its `ExecStartPre` deletes any existing copy first, because `ip rule add` does not deduplicate.

### Alternatives rejected

| Option | Why not |
|---|---|
| `tailscale set --accept-routes=false` on the master | Also drops `192.168.0.0/24`, so the master loses the GPU worker's LAN. Fixes this subnet by breaking another. |
| Stop `nas` advertising `192.168.2.0/24` | Removes real redundancy for remote access when the master is down, and only hides the bug until a second advertiser appears again. |
| Leave it, fix the alert | The master would stay unreachable from its own LAN whenever `nas` is primary. |

## Verification (2026-09-28)

| Check | Before | After |
|---|---|---|
| `ip route get 192.168.2.22` on the master | `dev tailscale0 table 52` | `dev eth0` |
| `ip route get 192.168.0.1` on the master | `dev tailscale0 table 52` | `dev tailscale0 table 52` - unchanged |
| Pod on worker-02 → `192.168.2.20:9100` | timeout | HTTP 200 in 0.3 s |
| SYN-ACK in packet capture | leaves on `tailscale0` | leaves on `eth0` |
| Master scrape targets `up` | 0 of 5 | 5 of 5 |
| Firing alerts | 11 | 6 - GPU operator, Watchdog, InfoInhibitor only |

Persistence: the rule survives `systemctl restart tailscaled`; two restarts of the unit leave exactly
one 2500 rule; the unit is enabled.

### Reboot test (2026-09-28 09:47 UTC) - rule held, the control plane did not

The master's first reboot in 258 days. The 2500 rule came back, and `192.168.2.22` routed via
`eth0`. But the control plane stayed down for about **8 minutes**, for a reason unrelated to the rule:

- At boot, tailscaled logged `wgcfg.Reconfig failed: IPC error -22 ... ParseEndpoint: unknown peer`
  at 09:47:19. After that it never put `100.84.89.67` on `tailscale0` - only a link-local IPv6.
  Tailscale itself looked healthy: peers connected, `tailscale status` listed the node.
- k3s then looped: `flannel exited: failed to find IPv4 address for interface tailscale0`.
- `systemctl restart tailscaled` assigned the address at once, and k3s came up by itself.
  kube-state-metrics had crash-looped during the outage and needed one pod delete.

**I think** this is a tailscaled boot race: its router setup was skipped when the first WireGuard
reconfig failed. I have not proven that, nor ruled out the new unit's ordering. The rule unit only
runs `ip rule add` and does not touch tailscaled.

### Boot guard (added the same day)

k3s now waits for the address: a drop-in
([`k3s-wait-tailscale.conf`](../../infrastructure/k3s/k3s-wait-tailscale.conf)) runs
[`wait-tailscale-ip.sh`](../../infrastructure/k3s/wait-tailscale-ip.sh) as `ExecStartPre`. The script
waits up to 60 s for `tailscale ip -4` to appear on `tailscale0`. If it does not, it restarts
tailscaled once, then waits again. If that also fails it exits 1, and `Restart=always` retries k3s.
Both paths were tested on the master: 0.03 s when the address is present, and restart-then-fail
against a missing interface.

Second reboot (10:12 UTC): clean. tailscaled got its address, the guard logged nothing, and k3s was
active 47 s after the reboot. So the boot race did not recur, and the guard's restart path has
**not** yet run for real. Recovery from that path is expected to take about 60-70 s, not 8 minutes.

`ssh k3s-master` resolves through Tailscale. When the master's Tailscale is broken, use
`ssh root@192.168.2.20`.

## Consequences

- **A rebuild from the README is now correct** - the policy-rule step sits directly under the
  `--accept-routes` command that caused the bug.
- **k3s-gpu-worker runs the same pattern but is immune today.** It is the only advertiser of
  `192.168.0.0/24`, so it is always primary. It needs the same rule, with its own subnet, only if a
  second advertiser of that subnet ever appears.
- **Any new node that sits on an advertised subnet and uses `--accept-routes` needs this rule.**
  The symptom to recognise: SYN in on `eth0`, SYN-ACK out on `tailscale0`.
- **A repeat now pages the phone.** `ControlPlaneNodeUnreachable` (critical, 5 min) in
  `monitoring/prometheus/custom-rules.yaml` fires when the control-plane node's node-exporter cannot
  be scraped. It finds the node by role, not by IP. It covers a master that is alive but unreachable -
  this incident. It **cannot** report a dead master: Alertmanager, CoreDNS and Traefik (the phone's
  path to ntfy) all run there, and with the only API server gone nothing reschedules. That needs a
  dead-man switch outside the cluster, fed by the always-firing `Watchdog` alert. Not built.
- **Rollback:** `systemctl disable --now tailscale-lan-rule` - `ExecStop` removes the rule.
