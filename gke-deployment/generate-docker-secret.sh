#!/usr/bin/env bash

# =============================================================================
# GENERATE DOCKER PULL SECRET FOR GKE
# =============================================================================
# This script generates the base64-encoded Docker config for JFrog registry
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Configuration
JFROG_REGISTRY="${JFROG_REGISTRY:-rodolphefplus.jfrog.io}"
JFROG_USER="${JFROG_USER}"
JFROG_TOKEN="${JFROG_TOKEN}"

echo ""
log_info "Docker Pull Secret Generator for GKE"
echo "====================================="
echo ""

# Check for required variables
if [[ -z "$JFROG_USER" ]]; then
    log_warning "JFROG_USER not set"
    read -p "Enter JFrog username: " JFROG_USER
fi

if [[ -z "$JFROG_TOKEN" ]]; then
    log_warning "JFROG_TOKEN not set"
    read -sp "Enter JFrog token/password: " JFROG_TOKEN
    echo ""
fi

log_info "Registry: $JFROG_REGISTRY"
log_info "Username: $JFROG_USER"
echo ""

# Generate Docker config
log_info "Generating Docker config..."
cat > /tmp/.dockerconfigjson << EOF
{
  "auths": {
    "$JFROG_REGISTRY": {
      "auth": "$(printf "%s:%s" "$JFROG_USER" "$JFROG_TOKEN" | base64)"
    }
  }
}
EOF

# Encode to base64
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    BASE64_CONFIG=$(base64 -i /tmp/.dockerconfigjson)
else
    # Linux
    BASE64_CONFIG=$(base64 -w 0 /tmp/.dockerconfigjson)
fi

log_success "Docker config generated!"
echo ""

# Option 1: Direct kubectl apply
log_info "Option 1: Apply directly with kubectl"
echo "========================================"
echo ""

for NS in bookverse-dev bookverse-qa bookverse-staging bookverse-prod; do
    echo "kubectl create secret docker-registry jfrog-docker-pull \\"
    echo "  --docker-server=$JFROG_REGISTRY \\"
    echo "  --docker-username=$JFROG_USER \\"
    echo "  --docker-password='$JFROG_TOKEN' \\"
    echo "  --namespace=$NS"
    echo ""
done

# Option 2: Generate YAML file
log_info "Option 2: Generate Kubernetes YAML file"
echo "=========================================="
echo ""

OUTPUT_FILE="k8s-manifests/04-image-pull-secret.yaml"
sed "s/PLACEHOLDER_BASE64_DOCKERCONFIG/$BASE64_CONFIG/g" \
  k8s-manifests/04-image-pull-secret.yaml.template > "$OUTPUT_FILE"

log_success "Generated: $OUTPUT_FILE"
echo ""
log_info "Apply with:"
echo "  kubectl apply -f $OUTPUT_FILE"
echo ""

# Option 3: Show base64 value
log_info "Option 3: Base64 value (for manual replacement)"
echo "=================================================="
echo ""
echo "$BASE64_CONFIG"
echo ""

# Cleanup
rm -f /tmp/.dockerconfigjson

log_success "Done! Choose one of the options above to create your secrets."
echo ""

