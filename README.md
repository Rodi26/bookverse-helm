# BookVerse Helm Charts

Demo-ready Kubernetes deployment charts for the BookVerse platform, showcasing JFrog AppTrust capabilities with infrastructure-as-code patterns.

## 🎯 Demo Purpose & Patterns

This service demonstrates the **Infrastructure-as-Code Application Pattern** - showcasing how Kubernetes deployments, Helm charts, and infrastructure configurations can be managed in AppTrust.

### ⚙️ **Infrastructure-as-Code Application Pattern**
- **What it demonstrates**: Application versions built from Helm charts, Kubernetes manifests, and deployment configurations
- **AppTrust benefit**: Infrastructure deployments promoted together ensuring environment consistency across stages (DEV → QA → STAGING → PROD)
- **Real-world applicability**: DevOps teams, infrastructure automation, and Kubernetes-native applications

This service is **infrastructure-focused** - it demonstrates how infrastructure can be reliably versioned and promoted through enterprise deployment pipelines.

## 🏗️ Helm Charts Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  BookVerse Platform                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                ┌─────────────────────────┐                  │
│                │     Helm Charts         │                  │
│                │                         │                  │
│                │ Infrastructure-as-Code  │                  │
│                │ ┌─────────────────────┐ │                  │
│                │ │  Platform Charts    │ │                  │
│                │ │  (Services, DBs)    │ │                  │
│                │ └─────────────────────┘ │                  │
│                │ ┌─────────────────────┐ │                  │
│                │ │ Environment Config  │ │                  │
│                │ │   (Values Files)    │ │                  │
│                │ └─────────────────────┘ │                  │
│                │ ┌─────────────────────┐ │                  │
│                │ │ Kubernetes YAML     │ │                  │
│                │ │    Manifests        │ │                  │
│                │ └─────────────────────┘ │                  │
│                └─────────────────────────┘                  │
│                          │                                  │
│          ┌───────────────┼───────────────┐                  │
│          │               │               │                  │
│          ▼               ▼               ▼                  │
│    [DEV Cluster]   [QA Cluster]   [PROD Cluster]           │
│                                                             │
└─────────────────────────────────────────────────────────────┘

AppTrust Promotion Pipeline:
DEV → QA → STAGING → PROD
 │     │       │        │
 └─────┴───────┴────────┘
   Helm Charts & Configs
   Deploy to Each Environment
```

## 🔧 JFrog AppTrust Integration

This service creates multiple artifacts per application version:

1. **Helm Charts** - Packaged Kubernetes deployment charts
2. **Kubernetes Manifests** - Raw YAML deployment files
3. **Configuration Files** - Environment-specific values files
4. **SBOMs** - Software Bill of Materials for infrastructure dependencies
5. **Test Reports** - Infrastructure validation and deployment testing
6. **Build Evidence** - Comprehensive infrastructure deployment attestations

Each artifact moves together through the promotion pipeline: DEV → QA → STAGING → PROD.

For the non-JFrog evidence plan and gates, see: `../bookverse-demo-init/docs/EVIDENCE_PLAN.md`.

## 🔄 Workflows

- [`ci.yml`](.github/workflows/ci.yml) — CI: chart validation, packaging, publish artifacts/build-info, AppTrust version and evidence
- [`promote.yml`](.github/workflows/promote.yml) — Promote the helm app version through stages with evidence
- [`promotion-rollback.yml`](.github/workflows/promotion-rollback.yml) — Roll back a promoted helm application version (demo utility)
