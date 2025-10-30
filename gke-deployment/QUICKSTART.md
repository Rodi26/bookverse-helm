# ⚡ BookVerse GKE - Quick Start

Configuration **specifically designed for GKE** - completely separated from other configurations.

## 🎯 Deploy in 5 Minutes

### 1️⃣ Reserve Static IP

```bash
cd /Users/rodolphefontaine/bookverse-demo/bookverse-helm/gke-deployment

export PROJECT_ID="your-gcp-project"

gcloud compute addresses create bookverse-web-ip --global --project=$PROJECT_ID
STATIC_IP=$(gcloud compute addresses describe bookverse-web-ip --global --format="value(address)")

echo "✅ Static IP: $STATIC_IP"
```

### 2️⃣ Configure DNS

**Create an A record:**
- Name: `bookverse.rodolphef.org`
- Type: A
- Value: `$STATIC_IP`
- TTL: 300

### 3️⃣ Create Kubernetes Resources

```bash
# Namespaces
kubectl apply -f k8s-manifests/01-namespace.yaml

# Google-Managed Certificate
kubectl apply -f k8s-manifests/02-managed-certificate.yaml

# JFrog Secrets
./generate-docker-secret.sh
# Follow the displayed instructions
```

### 4️⃣ Deploy BookVerse

**Option A: Automated Script (Recommended)**
```bash
export NAMESPACE=bookverse-prod
export DOMAIN=bookverse.rodolphef.org
export JFROG_REGISTRY=rodolphefplus.jfrog.io

./deploy-to-gke.sh
```

**Option B: Manual Deployment**
```bash
cd /Users/rodolphefontaine/bookverse-demo/bookverse-helm

helm upgrade --install bookverse-platform ./charts/platform \
  --namespace bookverse-prod \
  --values gke-deployment/values-gke.yaml
```

### 5️⃣ Apply Ingress

```bash
kubectl apply -f k8s-manifests/03-gke-ingress.yaml
```

## ⏱️ Wait Times

- **Initial deployment**: 2-5 minutes
- **SSL Certificate**: 15-60 minutes (Google provisioning)
- **DNS Propagation**: 5 minutes to several hours

## ✅ Verification

```bash
# All-in-one check
kubectl get all,ingress,managedcertificate -n bookverse-prod
```

## 🌐 Access

Once certificate is active (ACTIVE status):
```
https://bookverse.rodolphef.org
```

## 📁 GKE Files (All Separated)

```
gke-deployment/                    ← Isolated GKE folder
├── README-GKE.md                  ← Main GKE guide
├── QUICKSTART.md                  ← This file
├── GKE_DEPLOYMENT.md              ← Detailed documentation
├── values-gke.yaml                ← Helm values for GKE
├── setup-gke-ingress.sh          ← Static IP setup
├── deploy-to-gke.sh              ← Automated deployment
├── generate-docker-secret.sh     ← Generate JFrog secrets
└── k8s-manifests/                ← K8s manifests for GKE
    ├── 01-namespace.yaml
    ├── 02-managed-certificate.yaml
    ├── 03-gke-ingress.yaml
    └── 04-image-pull-secret.yaml.template
```

## ⚠️ Important

✅ **No original files modified**
✅ **100% separated GKE configuration**
✅ **Can coexist with ArgoCD/Traefik**
✅ **Based on your working Artifactory example**

## 🆘 Support

See `README-GKE.md` or `GKE_DEPLOYMENT.md` for more details.
