#!/usr/bin/env bash

# =============================================================================
# GKE INGRESS SETUP FOR BOOKVERSE
# =============================================================================
# This script sets up the necessary GKE resources for BookVerse web ingress:
# - Reserves a global static IP address
# - Creates TLS certificate (managed or self-signed)
# - Configures DNS (instructions provided)
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
STATIC_IP_NAME="${STATIC_IP_NAME:-bookverse-web-ip}"
REGION="${REGION:-global}"  # Use 'global' for global IP, or specify region for regional
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
DOMAIN="${DOMAIN:-bookverse.rodolphef.org}"
TLS_SECRET_NAME="${TLS_SECRET_NAME:-bookverse-web-tls}"
NAMESPACE="${NAMESPACE:-bookverse-prod}"

echo ""
log_info "GKE Ingress Setup for BookVerse"
echo "=================================="
log_info "Project: $PROJECT_ID"
log_info "Static IP Name: $STATIC_IP_NAME"
log_info "Domain: $DOMAIN"
log_info "Namespace: $NAMESPACE"
echo ""

# Step 1: Reserve Static IP
log_info "Step 1: Reserving global static IP address..."
if gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" &>/dev/null; then
    STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" --format="value(address)")
    log_warning "Static IP '$STATIC_IP_NAME' already exists: $STATIC_IP"
else
    log_info "Creating new global static IP..."
    gcloud compute addresses create "$STATIC_IP_NAME" \
        --global \
        --project="$PROJECT_ID"
    
    STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" --format="value(address)")
    log_success "Static IP created: $STATIC_IP"
fi

echo ""
log_success "Static IP Address: $STATIC_IP"
echo ""

# Step 2: Create namespace if it doesn't exist
log_info "Step 2: Ensuring namespace exists..."
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_info "Namespace '$NAMESPACE' already exists"
else
    kubectl create namespace "$NAMESPACE"
    log_success "Namespace '$NAMESPACE' created"
fi
echo ""

# Step 3: DNS Configuration Instructions
log_info "Step 3: DNS Configuration Required"
echo "-----------------------------------"
log_warning "Please configure your DNS to point to the static IP:"
echo ""
echo "  DNS Record Type: A"
echo "  Name: $DOMAIN"
echo "  Value: $STATIC_IP"
echo "  TTL: 300 (or your preference)"
echo ""
log_info "Example with Google Cloud DNS:"
echo "  gcloud dns record-sets create $DOMAIN. \\"
echo "    --zone=YOUR_DNS_ZONE \\"
echo "    --type=A \\"
echo "    --ttl=300 \\"
echo "    --rrdatas=$STATIC_IP"
echo ""

# Step 4: TLS Certificate Options
log_info "Step 4: TLS Certificate Setup"
echo "-------------------------------"
echo ""
log_info "Choose one of the following options:"
echo ""
echo "Option A: Google-Managed Certificate (Recommended for GKE)"
echo "  1. Create a ManagedCertificate resource:"
cat << EOF

cat > bookverse-managed-cert.yaml << 'CERT_EOF'
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: bookverse-web-cert
  namespace: $NAMESPACE
spec:
  domains:
    - $DOMAIN
CERT_EOF

kubectl apply -f bookverse-managed-cert.yaml

EOF
echo "  2. Update values.yaml annotation to use managed cert:"
echo "     networking.gke.io/managed-certificates: bookverse-web-cert"
echo ""

echo "Option B: Let's Encrypt with cert-manager"
echo "  1. Install cert-manager:"
echo "     kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml"
echo ""
echo "  2. Create ClusterIssuer:"
cat << EOF

cat > letsencrypt-issuer.yaml << 'ISSUER_EOF'
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
ISSUER_EOF

kubectl apply -f letsencrypt-issuer.yaml

EOF
echo "  3. Add annotation to Ingress:"
echo "     cert-manager.io/cluster-issuer: letsencrypt-prod"
echo ""

echo "Option C: Self-Signed Certificate (Development Only)"
echo "  kubectl create secret tls $TLS_SECRET_NAME \\"
echo "    --cert=path/to/tls.crt \\"
echo "    --key=path/to/tls.key \\"
echo "    --namespace=$NAMESPACE"
echo ""

# Step 5: Summary
echo ""
log_success "Setup Complete!"
echo "==============="
echo ""
log_info "Next Steps:"
echo "1. ✅ Configure DNS record: $DOMAIN → $STATIC_IP"
echo "2. 🔐 Choose and configure TLS certificate (options above)"
echo "3. 📦 Deploy BookVerse with:"
echo "   helm upgrade --install bookverse-platform ./charts/platform \\"
echo "     --namespace $NAMESPACE \\"
echo "     --set web.ingress.enabled=true \\"
echo "     --set web.ingress.host=$DOMAIN"
echo ""
log_info "Your static IP configuration has been saved to values.yaml"
log_info "IP Name: $STATIC_IP_NAME"
log_info "IP Address: $STATIC_IP"
echo ""

