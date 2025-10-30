# BookVerse Deployment on Google Kubernetes Engine (GKE)

This guide walks you through deploying BookVerse on GKE with external access via Google Cloud Load Balancer.

## Prerequisites

- GKE cluster running
- `kubectl` configured to access your cluster
- `gcloud` CLI installed and authenticated
- `helm` v3+ installed
- Domain name configured (e.g., `bookverse.rodolphef.org`)

## Quick Start

### 1. Reserve Static IP Address

```bash
# Reserve a global static IP
gcloud compute addresses create bookverse-web-ip \
  --global \
  --project=YOUR_PROJECT_ID

# Get the IP address
STATIC_IP=$(gcloud compute addresses describe bookverse-web-ip \
  --global \
  --format="value(address)")

echo "Static IP: $STATIC_IP"
```

### 2. Configure DNS

Point your domain to the static IP:

**Option A: Google Cloud DNS**
```bash
gcloud dns record-sets create bookverse.rodolphef.org. \
  --zone=YOUR_DNS_ZONE \
  --type=A \
  --ttl=300 \
  --rrdatas=$STATIC_IP
```

**Option B: Manual DNS Configuration**
- DNS Record Type: `A`
- Name: `bookverse.rodolphef.org`
- Value: `YOUR_STATIC_IP`
- TTL: `300`

### 3. Create Namespace

```bash
kubectl create namespace bookverse-prod
```

### 4. Configure Image Pull Secret

Create a secret to pull images from JFrog:

```bash
# Create Docker config JSON
export JFROG_USER="your-username"
export JFROG_TOKEN="your-token-or-password"
export JFROG_REGISTRY="rodolphefplus.jfrog.io"

kubectl create secret docker-registry jfrog-docker-pull \
  --docker-server=$JFROG_REGISTRY \
  --docker-username=$JFROG_USER \
  --docker-password=$JFROG_TOKEN \
  --docker-email=your-email@example.com \
  --namespace=bookverse-prod
```

### 5. Setup TLS Certificate

**Option A: Google-Managed Certificate (Recommended)**

```bash
cat > bookverse-managed-cert.yaml << 'EOF'
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: bookverse-web-cert
  namespace: bookverse-prod
spec:
  domains:
    - bookverse.rodolphef.org
EOF

kubectl apply -f bookverse-managed-cert.yaml
```

Then update `values-gke.yaml` to add this annotation:
```yaml
web:
  ingress:
    annotations:
      networking.gke.io/managed-certificates: bookverse-web-cert
```

**Option B: Let's Encrypt with cert-manager**

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer
cat > letsencrypt-issuer.yaml << 'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: gce
EOF

kubectl apply -f letsencrypt-issuer.yaml
```

Then update `values-gke.yaml`:
```yaml
web:
  ingress:
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
```

### 6. Deploy BookVerse

```bash
cd /path/to/bookverse-helm

# Deploy with GKE-optimized values
helm upgrade --install bookverse-platform ./charts/platform \
  --namespace bookverse-prod \
  --values charts/platform/values-gke.yaml \
  --create-namespace
```

### 7. Verify Deployment

```bash
# Check ingress status
kubectl get ingress -n bookverse-prod

# Check managed certificate status (if using Google-managed cert)
kubectl describe managedcertificate bookverse-web-cert -n bookverse-prod

# Check pods
kubectl get pods -n bookverse-prod

# Check services
kubectl get svc -n bookverse-prod
```

### 8. Monitor Certificate Provisioning

Google-managed certificates can take 15-60 minutes to provision:

```bash
# Watch certificate status
kubectl get managedcertificate bookverse-web-cert -n bookverse-prod -w

# Status should change from:
# PROVISIONING → ACTIVE
```

### 9. Test Access

Once DNS propagates and certificate is active:

```bash
# Test HTTP access
curl http://bookverse.rodolphef.org

# Test HTTPS access
curl https://bookverse.rodolphef.org

# Check in browser
open https://bookverse.rodolphef.org
```

## Architecture

```
Internet
   ↓
Google Cloud Load Balancer (Static IP: YOUR_IP)
   ↓
GKE Ingress Controller
   ↓
┌─────────────────────────────────────┐
│  BookVerse Services (bookverse-prod)│
├─────────────────────────────────────┤
│  → Web (/)                          │
│  → Inventory (/api/v1/books)        │
│  → Recommendations (/recommendations)│
│  → Checkout (/checkout)             │
└─────────────────────────────────────┘
```

## Configuration Files

### values-gke.yaml
The GKE-specific configuration includes:
- `className: gce` - Uses GKE Ingress controller
- `kubernetes.io/ingress.global-static-ip-name` - References your static IP
- TLS configuration for HTTPS
- Optimized resource limits for GKE

### Static IP Configuration
```yaml
web:
  ingress:
    annotations:
      kubernetes.io/ingress.global-static-ip-name: bookverse-web-ip
```

## Troubleshooting

### Ingress Not Getting External IP

```bash
# Check ingress events
kubectl describe ingress platform-web -n bookverse-prod

# Check backend health
kubectl get backendconfig -n bookverse-prod
```

### Certificate Not Provisioning

```bash
# Google-managed certificate must have:
# 1. DNS record pointing to static IP
# 2. Domain ownership verification
# 3. 15-60 minutes provisioning time

# Check status
kubectl describe managedcertificate bookverse-web-cert -n bookverse-prod
```

### 502/503 Errors

```bash
# Check pod health
kubectl get pods -n bookverse-prod
kubectl logs -n bookverse-prod -l app=platform-web

# Check service endpoints
kubectl get endpoints -n bookverse-prod
```

## Update Deployment

To update image tags:

```bash
helm upgrade bookverse-platform ./charts/platform \
  --namespace bookverse-prod \
  --values charts/platform/values-gke.yaml \
  --set web.tag=NEW_VERSION \
  --set inventory.tag=NEW_VERSION
```

## Cleanup

To remove all resources:

```bash
# Delete Helm release
helm uninstall bookverse-platform -n bookverse-prod

# Delete namespace
kubectl delete namespace bookverse-prod

# Delete static IP (optional)
gcloud compute addresses delete bookverse-web-ip --global
```

## Security Considerations

1. **Image Pull Secrets**: Stored as Kubernetes secret with JFrog credentials
2. **TLS**: Enforced with Google-managed or Let's Encrypt certificates
3. **Network Policies**: Consider adding NetworkPolicy resources for pod-to-pod traffic
4. **RBAC**: Ensure proper service account permissions

## Cost Optimization

- Use **regional** static IP if traffic is region-specific (cheaper than global)
- Configure **autoscaling** based on traffic patterns
- Use **preemptible nodes** for non-production environments

## References

- [GKE Ingress Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress)
- [Google-Managed Certificates](https://cloud.google.com/kubernetes-engine/docs/how-to/managed-certs)
- [Static IP Addresses](https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address)

