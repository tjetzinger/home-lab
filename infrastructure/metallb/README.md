# MetalLB - LoadBalancer Implementation for Bare Metal

**Story:** 3.1 - Deploy MetalLB for LoadBalancer Services
**Epic:** 3 - Ingress, TLS & Service Exposure
**Namespace:** `infra`

## What It Does

MetalLB provides network load balancer implementation for Kubernetes clusters that don't run on cloud providers. It assigns external IP addresses to LoadBalancer-type Services, enabling direct access to cluster services from the local network.

## Why It Was Chosen

**Decision Rationale:**
- **Bare metal requirement:** Home lab runs on Proxmox (bare metal), not AWS/GCP/Azure
- **No cloud provider integration:** Standard Kubernetes LoadBalancer services remain "Pending" without MetalLB
- **Industry standard:** De facto load balancer solution for self-hosted Kubernetes
- **Layer 2 simplicity:** ARP-based IP allocation works without BGP routing infrastructure

**Alternatives Considered:**
- NodePort services → Rejected (non-standard ports, poor user experience)
- Ingress-only access → Rejected (doesn't cover non-HTTP services, no LoadBalancer IP for Traefik itself)
- HAProxy/Nginx external LB → Rejected (additional infrastructure, manual configuration)
- kube-vip → Considered but rejected (MetalLB more mature, broader community support)

## Key Configuration Decisions

### Operating Mode: Layer 2

MetalLB supports two modes. This deployment uses **Layer 2 (ARP/NDP)**:

**Layer 2 Mode (Chosen):**
- Uses ARP (IPv4) or NDP (IPv6) to announce service IPs
- Simple setup: No BGP router configuration required
- Limitation: All traffic flows through single node (speaker pod on that node)
- Suitable for: Home lab, small-scale deployments

**BGP Mode (Not Used):**
- Integrates with BGP routers for true ECMP load balancing
- Requires: BGP-capable router, additional network configuration
- Not needed for home lab scale

### IP Address Pool

**Configured IP Range:** `192.168.2.100 - 192.168.2.120` (21 addresses)

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: homelab-pool
  namespace: infra
spec:
  addresses:
  - 192.168.2.100-192.168.2.120
```

**Network Context:**
- Cluster nodes: `192.168.2.20-22` (k3s-master, workers)
- Synology NFS: `192.168.2.2`
- Router: `192.168.2.1`
- MetalLB pool: `192.168.2.100-120` (reserved, outside DHCP range)

**IP Allocation:**
- **192.168.2.100:** Traefik LoadBalancer (primary ingress entry point)
- **192.168.2.101-120:** Available for future LoadBalancer services

### L2Advertisement

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: homelab-l2
  namespace: infra
spec:
  ipAddressPools:
  - homelab-pool
```

Layer 2 advertisement announces IPs via ARP to the local network, making them routable from any device on `192.168.2.0/24`.

## How to Access/Use

### Assigning LoadBalancer IP to a Service

Any Service with `type: LoadBalancer` will automatically receive an IP from MetalLB's pool:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-service
spec:
  type: LoadBalancer  # MetalLB assigns external IP
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: example
```

### Check LoadBalancer IP Assignments

View services with external IPs:
```bash
kubectl get svc --all-namespaces --field-selector spec.type=LoadBalancer
```

Example output:
```
NAMESPACE     NAME      TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)
kube-system   traefik   LoadBalancer   10.43.123.45    192.168.2.100    80:30080/TCP,443:30443/TCP
```

### Verify MetalLB Health

Check MetalLB speaker pods (one per node in Layer 2 mode):
```bash
kubectl get pods -n infra -l app.kubernetes.io/component=speaker
kubectl logs -n infra -l app.kubernetes.io/component=speaker
```

Check MetalLB controller:
```bash
kubectl get pods -n infra -l app.kubernetes.io/component=controller
kubectl logs -n infra -l app.kubernetes.io/component=controller
```

### Request Specific IP (Optional)

Services can request a specific IP from the pool using `loadBalancerIP` annotation (deprecated but still functional):

```yaml
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.2.101  # Request specific IP
```

**Note:** This field is deprecated in Kubernetes 1.24+. Future versions should use service-specific IP pools.

## Deployment Details

**Helm Chart:** `metallb/metallb`
**Version:** As specified in deployment values
**Installation:** Story 3.1 implementation

**Components:**
- `metallb-controller` - Watches for LoadBalancer services and assigns IPs
- `metallb-speaker` - DaemonSet running on all nodes, handles Layer 2 advertisements

**CRDs:**
- `IPAddressPool` - Defines available IP ranges
- `L2Advertisement` - Configures Layer 2 mode announcements
- `BGPPeer` - Not used (BGP mode not configured)

## Integration Points

**Traefik Ingress:**
- Traefik Service (type: LoadBalancer) receives `192.168.2.100` from MetalLB
- All `*.home.jetzinger.com` DNS rewrites point to this IP
- Traefik routes traffic to backend services via Ingress/IngressRoute

**Future Services:**
- Additional LoadBalancer services can request IPs from remaining pool (192.168.2.101-120)
- Examples: Database external access, custom TCP/UDP services

## Network Architecture

```
Internet → Tailscale VPN → Home Network (192.168.2.0/24)
                                ↓
                         MetalLB IP Pool (192.168.2.100-120)
                                ↓
                    Traefik LoadBalancer (192.168.2.100)
                                ↓
                    IngressRoute → Backend Services
```

**DNS Resolution:**
- NextDNS rewrites `*.home.jetzinger.com` → `192.168.2.100`
- Traefik (listening on 192.168.2.100) routes based on hostname

## Monitoring

**MetalLB Metrics:**
MetalLB speaker and controller expose Prometheus metrics:
- `metallb_allocator_addresses_in_use_total` - Number of IPs allocated
- `metallb_allocator_addresses_total` - Total IPs in pools
- `metallb_speaker_announced` - Layer 2 announcement status

**Prometheus Scraping:**
kube-prometheus-stack automatically scrapes MetalLB metrics via ServiceMonitor.

## Troubleshooting

**Service Stuck in "Pending" State:**
```bash
# Check controller logs
kubectl logs -n infra deployment/metallb-controller

# Common causes:
# - No available IPs in pool
# - IPAddressPool not created
# - L2Advertisement missing
```

**IP Not Reachable from Network:**
```bash
# Check speaker logs on the node
kubectl logs -n infra daemonset/metallb-speaker

# Verify ARP announcement:
# From another machine on network:
arp -a | grep 192.168.2.100

# Verify node can reach IP:
ping 192.168.2.100
```

**IP Conflict:**
- Ensure MetalLB pool (192.168.2.100-120) is **outside** DHCP range
- Verify no static IPs conflict with pool range
- Check router DHCP configuration

## Security Considerations

**Network Exposure:**
- LoadBalancer IPs are accessible from entire `192.168.2.0/24` subnet
- Services requiring external access should implement authentication
- Consider NetworkPolicies to restrict pod-to-pod traffic

**Tailscale VPN Access:**
- Cluster has **no public internet exposure**
- All external access routed through Tailscale VPN
- MetalLB IPs only accessible from Tailscale network or local LAN

## References

- [MetalLB Documentation](https://metallb.universe.tf/)
- [Layer 2 Configuration Guide](https://metallb.universe.tf/configuration/)
- [Story 3.1 Implementation](../../docs/implementation-artifacts/3-1-deploy-metallb-for-loadbalancer-services.md)
- [Architecture Diagram](../../docs/diagrams/architecture-overview.md)
