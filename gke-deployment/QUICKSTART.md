# ⚡ BookVerse GKE - Démarrage Rapide

Configuration **spécialement conçue pour GKE** - complètement séparée des autres configurations.

## 🎯 Déploiement en 5 Minutes

### 1️⃣ Réserver l'IP Statique

```bash
cd /Users/rodolphefontaine/bookverse-demo/bookverse-helm/gke-deployment

export PROJECT_ID="votre-project-gcp"

gcloud compute addresses create bookverse-web-ip --global --project=$PROJECT_ID
STATIC_IP=$(gcloud compute addresses describe bookverse-web-ip --global --format="value(address)")

echo "✅ IP Statique: $STATIC_IP"
```

### 2️⃣ Configurer DNS

**Créer un enregistrement A:**
- Nom: `bookverse.rodolphef.org`
- Type: A
- Valeur: `$STATIC_IP`
- TTL: 300

### 3️⃣ Créer les Ressources Kubernetes

```bash
# Namespaces
kubectl apply -f k8s-manifests/01-namespace.yaml

# Certificat Google-Managed
kubectl apply -f k8s-manifests/02-managed-certificate.yaml

# Secrets JFrog
./generate-docker-secret.sh
# Suivre les instructions affichées
```

### 4️⃣ Déployer BookVerse

**Option A: Script Automatisé (Recommandé)**
```bash
export NAMESPACE=bookverse-prod
export DOMAIN=bookverse.rodolphef.org
export JFROG_REGISTRY=rodolphefplus.jfrog.io

./deploy-to-gke.sh
```

**Option B: Déploiement Manuel**
```bash
cd /Users/rodolphefontaine/bookverse-demo/bookverse-helm

helm upgrade --install bookverse-platform ./charts/platform \
  --namespace bookverse-prod \
  --values gke-deployment/values-gke.yaml
```

### 5️⃣ Appliquer l'Ingress

```bash
kubectl apply -f k8s-manifests/03-gke-ingress.yaml
```

## ⏱️ Temps d'Attente

- **Déploiement initial**: 2-5 minutes
- **Certificat SSL**: 15-60 minutes (provisioning Google)
- **Propagation DNS**: 5 minutes à quelques heures

## ✅ Vérification

```bash
# Tout en un
kubectl get all,ingress,managedcertificate -n bookverse-prod
```

## 🌐 Accès

Une fois le certificat actif (ACTIVE):
```
https://bookverse.rodolphef.org
```

## 📁 Fichiers GKE (Tous Séparés)

```
gke-deployment/                    ← Dossier GKE isolé
├── README-GKE.md                  ← Guide principal GKE
├── QUICKSTART.md                  ← Ce fichier
├── GKE_DEPLOYMENT.md              ← Documentation détaillée
├── values-gke.yaml                ← Values Helm GKE
├── setup-gke-ingress.sh          ← Setup IP statique
├── deploy-to-gke.sh              ← Déploiement automatisé
├── generate-docker-secret.sh     ← Générer secrets JFrog
└── k8s-manifests/                ← Manifests K8s GKE
    ├── 01-namespace.yaml
    ├── 02-managed-certificate.yaml
    ├── 03-gke-ingress.yaml
    └── 04-image-pull-secret.yaml.template
```

## ⚠️ Important

✅ **Aucun fichier original modifié**
✅ **Configuration GKE 100% séparée**
✅ **Peut coexister avec ArgoCD/Traefik**
✅ **Basée sur votre exemple Artifactory fonctionnel**

## 🆘 Support

Consultez `README-GKE.md` ou `GKE_DEPLOYMENT.md` pour plus de détails.

