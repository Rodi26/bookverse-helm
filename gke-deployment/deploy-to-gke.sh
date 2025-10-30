#!/usr/bin/env bash

# =============================================================================
# BOOKVERSE GKE DEPLOYMENT SCRIPT
# =============================================================================
# Quick deployment script for BookVerse on Google Kubernetes Engine
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
STATIC_IP_NAME="${STATIC_IP_NAME:-bookverse-web-ip}"
DOMAIN="${DOMAIN:-bookverse.rodolphef.org}"
NAMESPACE="${NAMESPACE:-bookverse-prod}"
JFROG_REGISTRY="${JFROG_REGISTRY:-rodolphefplus.jfrog.io}"
RELEASE_NAME="${RELEASE_NAME:-bookverse-platform}"

echo ""
log_info "BookVerse GKE Deployment"
echo "========================="
log_info "Project: $PROJECT_ID"
log_info "Namespace: $NAMESPACE"
log_info "Domain: $DOMAIN"
log_info "Static IP: $STATIC_IP_NAME"
echo ""

# Step 1: Check prerequisites
log_info "Checking prerequisites..."
MISSING_TOOLS=()

command -v kubectl >/dev/null 2>&1 || MISSING_TOOLS+=("kubectl")
command -v helm >/dev/null 2>&1 || MISSING_TOOLS+=("helm")
command -v gcloud >/dev/null 2>&1 || MISSING_TOOLS+=("gcloud")

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    log_error "Missing required tools: ${MISSING_TOOLS[*]}"
    exit 1
fi
log_success "All tools available"
echo ""

# Step 2: Reserve Static IP
log_info "Reserving static IP address..."
if gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" &>/dev/null; then
    STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" --format="value(address)")
    log_warning "Static IP already exists: $STATIC_IP"
else
    gcloud compute addresses create "$STATIC_IP_NAME" --global --project="$PROJECT_ID"
    STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" --format="value(address)")
    log_success "Static IP created: $STATIC_IP"
fi
echo ""

# Step 3: Create namespace
log_info "Creating namespace..."
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_info "Namespace '$NAMESPACE' already exists"
else
    kubectl create namespace "$NAMESPACE"
    log_success "Namespace created"
fi
echo ""

# Step 4: Check/Create Image Pull Secret
log_info "Checking image pull secret..."
if kubectl get secret jfrog-docker-pull -n "$NAMESPACE" &>/dev/null; then
    log_warning "Image pull secret already exists"
else
    log_warning "Image pull secret 'jfrog-docker-pull' not found in namespace $NAMESPACE"
    log_info "Please create it with:"
    echo ""
    echo "  kubectl create secret docker-registry jfrog-docker-pull \\"
    echo "    --docker-server=$JFROG_REGISTRY \\"
    echo "    --docker-username=YOUR_USER \\"
    echo "    --docker-password=YOUR_TOKEN \\"
    echo "    --namespace=$NAMESPACE"
    echo ""
    read -p "Press Enter to continue (or Ctrl+C to abort)..."
fi
echo ""

# Step 5: Create Managed Certificate
log_info "Creating Google-managed certificate..."
cat > /tmp/bookverse-managed-cert.yaml << EOF
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: bookverse-web-cert
  namespace: $NAMESPACE
spec:
  domains:
    - $DOMAIN
EOF

kubectl apply -f /tmp/bookverse-managed-cert.yaml
log_success "Managed certificate resource created"
rm /tmp/bookverse-managed-cert.yaml
echo ""

# Step 6: Deploy with Helm
log_info "Deploying BookVerse with Helm..."
cd "$(dirname "$0")/.."

helm upgrade --install "$RELEASE_NAME" ./charts/platform \
  --namespace "$NAMESPACE" \
  --values ./charts/platform/values-gke.yaml \
  --set web.ingress.host="$DOMAIN" \
  --create-namespace \
  --wait \
  --timeout 5m

log_success "BookVerse deployed successfully!"
echo ""

# Step 7: Display status
log_info "Deployment Status:"
echo "==================="
echo ""
kubectl get ingress -n "$NAMESPACE"
echo ""
kubectl get pods -n "$NAMESPACE"
echo ""

# Step 8: Display next steps
log_success "Deployment Complete!"
echo ""
log_warning "IMPORTANT: Configure DNS before accessing"
echo "DNS Configuration:"
echo "  Type: A"
echo "  Name: $DOMAIN"
echo "  Value: $STATIC_IP"
echo ""
log_info "Certificate provisioning may take 15-60 minutes"
log_info "Check status with:"
echo "  kubectl describe managedcertificate bookverse-web-cert -n $NAMESPACE"
echo ""
log_info "Once DNS propagates and certificate is active, access at:"
echo "  https://$DOMAIN"
echo ""

