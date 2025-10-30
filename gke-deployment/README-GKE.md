# 🚀 BookVerse Deployment on Google Kubernetes Engine (GKE)

Cette configuration est **spécialement conçue pour GKE** et utilise les fonctionnalités Google Cloud natives.

## 📂 Structure des Fichiers GKE

```
gke-deployment/
├── README-GKE.md                      # Ce fichier - Guide de déploiement GKE
├── values-gke.yaml                    # Configuration Helm pour GKE
├── GKE_DEPLOYMENT.md                  # Documentation détaillée
├── setup-gke-ingress.sh              # Script de configuration de l'IP statique
├── deploy-to-gke.sh                  # Script de déploiement automatisé
└── k8s-manifests/                    # Manifests Kubernetes pour GKE
    ├── 01-namespace.yaml             # Namespaces (dev/qa/staging/prod)
    ├── 02-managed-certificate.yaml   # Certificats Google-managed
    ├── 03-gke-ingress.yaml           # Ingress avec IP statique globale
    └── 04-image-pull-secret.yaml.template  # Template pour secrets JFrog
```

## ⚡ Déploiement Rapide (Production Ready)

### Prérequis

- Cluster GKE en cours d'exécution
- `kubectl` configuré pour votre cluster
- `gcloud` CLI authentifié
- `helm` v3+ installé
- Domaine configuré (exemple: `bookverse.rodolphef.org`)

### Étape 1: Réserver une IP Statique Globale

```bash
# Définir votre projet GCP
export PROJECT_ID="your-gcp-project-id"
export STATIC_IP_NAME="bookverse-web-ip"

# Réserver l'IP statique globale
gcloud compute addresses create $STATIC_IP_NAME \
  --global \
  --project=$PROJECT_ID

# Récupérer l'IP
export STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME \
  --global \
  --project=$PROJECT_ID \
  --format="value(address)")

echo "📌 IP Statique réservée: $STATIC_IP"
```

### Étape 2: Configurer le DNS

Créez un enregistrement DNS A pointant vers votre IP statique:

**Option A: Google Cloud DNS**
```bash
export DNS_ZONE="your-dns-zone"
export DOMAIN="bookverse.rodolphef.org"

gcloud dns record-sets create ${DOMAIN}. \
  --zone=$DNS_ZONE \
  --type=A \
  --ttl=300 \
  --rrdatas=$STATIC_IP
```

**Option B: Configuration DNS manuelle**
```
Type: A
Nom: bookverse.rodolphef.org
Valeur: VOTRE_IP_STATIQUE
TTL: 300
```

### Étape 3: Créer les Namespaces

```bash
kubectl apply -f k8s-manifests/01-namespace.yaml
```

### Étape 4: Configurer les Secrets JFrog

```bash
# Variables JFrog
export JFROG_REGISTRY="rodolphefplus.jfrog.io"
export JFROG_USER="votre-utilisateur"
export JFROG_TOKEN="votre-token"

# Créer le secret pour chaque namespace
for NS in bookverse-dev bookverse-qa bookverse-staging bookverse-prod; do
  kubectl create secret docker-registry jfrog-docker-pull \
    --docker-server=$JFROG_REGISTRY \
    --docker-username=$JFROG_USER \
    --docker-password=$JFROG_TOKEN \
    --namespace=$NS
done
```

**OU générer le fichier manuellement:**

```bash
# Générer le Docker config en base64
cat > /tmp/.dockerconfigjson << EOF
{
  "auths": {
    "$JFROG_REGISTRY": {
      "auth": "$(printf "%s:%s" "$JFROG_USER" "$JFROG_TOKEN" | base64)"
    }
  }
}
EOF

# Encoder en base64
BASE64_CONFIG=$(base64 -w 0 /tmp/.dockerconfigjson)  # Linux
# BASE64_CONFIG=$(base64 -i /tmp/.dockerconfigjson)  # macOS

# Remplacer PLACEHOLDER dans 04-image-pull-secret.yaml.template
sed "s/PLACEHOLDER_BASE64_DOCKERCONFIG/$BASE64_CONFIG/g" \
  k8s-manifests/04-image-pull-secret.yaml.template > \
  k8s-manifests/04-image-pull-secret.yaml

# Appliquer
kubectl apply -f k8s-manifests/04-image-pull-secret.yaml
```

### Étape 5: Créer les Certificats Google-Managed

```bash
kubectl apply -f k8s-manifests/02-managed-certificate.yaml
```

⚠️ **Important**: La provisioning du certificat prend **15-60 minutes** après la configuration DNS.

Vérifier le statut:
```bash
kubectl describe managedcertificate bookverse-web-cert-prod -n bookverse-prod
```

### Étape 6: Déployer BookVerse avec Helm

```bash
cd /Users/rodolphefontaine/bookverse-demo/bookverse-helm

# Déploiement Production
helm upgrade --install bookverse-platform ../charts/platform \
  --namespace bookverse-prod \
  --values values-gke.yaml \
  --create-namespace \
  --wait

# OU utiliser le script automatisé
./deploy-to-gke.sh
```

### Étape 7: Appliquer l'Ingress GKE

```bash
kubectl apply -f k8s-manifests/03-gke-ingress.yaml
```

### Étape 8: Vérifier le Déploiement

```bash
# Vérifier l'ingress
kubectl get ingress -n bookverse-prod

# Vérifier le certificat
kubectl get managedcertificate -n bookverse-prod

# Vérifier les pods
kubectl get pods -n bookverse-prod

# Vérifier l'IP externe
kubectl get ingress bookverse-web-ingress -n bookverse-prod \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## 🔍 Caractéristiques Spécifiques GKE

Basées sur votre exemple Artifactory fonctionnel:

### IP Statique Globale
```yaml
annotations:
  kubernetes.io/ingress.global-static-ip-name: bookverse-web-ip
```

### Ingress Class GCE
```yaml
spec:
  ingressClassName: gce
```

### Certificat Google-Managed
```yaml
annotations:
  networking.gke.io/managed-certificates: bookverse-web-cert-prod
```

### Timeouts & Body Size
```yaml
annotations:
  ingress.kubernetes.io/proxy-body-size: "0"
  ingress.kubernetes.io/proxy-read-timeout: "600"
  ingress.kubernetes.io/proxy-send-timeout: "600"
```

## 🎯 Architecture GKE

```
Internet
   ↓
DNS: bookverse.rodolphef.org → STATIC_IP
   ↓
Google Cloud Load Balancer (Global)
   ├─ IP Statique: bookverse-web-ip
   ├─ Certificat SSL: Google-Managed
   └─ Backend: GKE Ingress Controller
       ↓
   GKE Cluster (bookverse-prod namespace)
   ├─ platform-web (/)
   ├─ inventory (/api/v1/books, /static)
   ├─ recommendations (/recommendations)
   └─ checkout (/checkout)
```

## 🔧 Configuration Variables

Personnalisez dans `values-gke.yaml`:

```yaml
web:
  ingress:
    host: bookverse.rodolphef.org  # Votre domaine
    annotations:
      kubernetes.io/ingress.global-static-ip-name: bookverse-web-ip  # Votre IP
```

## 📊 Monitoring du Déploiement

```bash
# Surveiller les pods
kubectl get pods -n bookverse-prod -w

# Surveiller l'ingress
kubectl get ingress -n bookverse-prod -w

# Surveiller le certificat (attend ACTIVE)
watch -n 10 "kubectl get managedcertificate -n bookverse-prod"

# Logs d'un service
kubectl logs -n bookverse-prod -l app=platform-web --tail=50 -f
```

## ✅ Vérification Post-Déploiement

```bash
# Test HTTP (sera redirigé vers HTTPS)
curl -I http://bookverse.rodolphef.org

# Test HTTPS (une fois le certificat actif)
curl -I https://bookverse.rodolphef.org

# Test dans le navigateur
open https://bookverse.rodolphef.org
```

## 🐛 Dépannage

### Ingress n'obtient pas d'IP externe

```bash
# Vérifier les événements
kubectl describe ingress bookverse-web-ingress -n bookverse-prod

# Vérifier les backends
kubectl get backendconfig -n bookverse-prod

# Vérifier les services
kubectl get svc -n bookverse-prod
```

### Certificat bloqué en PROVISIONING

**Causes communes:**
- DNS non configuré ou non propagé
- Domaine ne pointe pas vers la bonne IP
- Port 80/443 non accessible

**Solutions:**
```bash
# Vérifier le statut du certificat
kubectl describe managedcertificate bookverse-web-cert-prod -n bookverse-prod

# Vérifier DNS
nslookup bookverse.rodolphef.org
dig bookverse.rodolphef.org

# Attendre la propagation DNS (peut prendre plusieurs heures)
```

### Erreurs 502/503

```bash
# Vérifier la santé des pods
kubectl get pods -n bookverse-prod
kubectl logs -n bookverse-prod <pod-name>

# Vérifier les endpoints
kubectl get endpoints -n bookverse-prod

# Vérifier les health checks
kubectl describe pod -n bookverse-prod <pod-name>
```

## 🔄 Mise à Jour

Pour mettre à jour le déploiement:

```bash
# Mettre à jour une image
helm upgrade bookverse-platform ../charts/platform \
  --namespace bookverse-prod \
  --values values-gke.yaml \
  --set web.tag=NEW_VERSION \
  --reuse-values

# Ou redéployer complètement
./deploy-to-gke.sh
```

## 🗑️ Nettoyage

Pour supprimer complètement BookVerse:

```bash
# Supprimer le Helm release
helm uninstall bookverse-platform -n bookverse-prod

# Supprimer les ressources Kubernetes
kubectl delete -f k8s-manifests/03-gke-ingress.yaml
kubectl delete -f k8s-manifests/02-managed-certificate.yaml
kubectl delete namespace bookverse-prod

# Supprimer l'IP statique (optionnel)
gcloud compute addresses delete bookverse-web-ip --global
```

## 💰 Optimisation des Coûts

1. **IP Statique Régionale** (moins chère que globale):
   ```bash
   gcloud compute addresses create bookverse-web-ip \
     --region=us-central1  # au lieu de --global
   ```

2. **Autoscaling**: Configuré dans values-gke.yaml
3. **Preemptible Nodes**: Pour environnements non-prod

## 📚 Références

- [GKE Ingress](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress)
- [Google-Managed Certificates](https://cloud.google.com/kubernetes-engine/docs/how-to/managed-certs)
- [Static IP](https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address)
- Votre exemple Artifactory fonctionnel (utilisé comme référence)

## ⚠️ Notes Importantes

- ✅ Cette configuration est **isolée** des fichiers Helm existants
- ✅ N'écrase **aucun** fichier original
- ✅ Clairement identifiée comme **spécifique GKE**
- ✅ Peut coexister avec d'autres configurations (ArgoCD, Traefik, etc.)

