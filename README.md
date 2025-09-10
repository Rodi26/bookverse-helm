# BookVerse Helm

Platform-centric Helm charts for the BookVerse demo.

## Charts

- charts/platform: Deploys web and microservices used by the platform release

## CI

- `Helm CI` lints and packages the chart; upload to JFrog is a placeholder until connectivity is available.
- `Update K8s` workflow listens to `repository_dispatch` (PROD) and pins versions in `charts/platform/values.yaml`, then lints and pushes commit.

### Update K8s Workflow

This repository contains a workflow at `.github/workflows/update-k8s.yml` that:

- Listens to repository_dispatch events: `update_k8s`, `release_completed`, `platform_release_completed`, `release_complete`
- Resolves the desired platform/app versions from the event payload or falls back to latest in AppTrust
- Updates `charts/platform/values.yaml` (`platform.version` and service tags), lints the chart, and pushes the commit

Manual trigger:

1. Go to Actions → Update K8s → Run workflow
2. Optionally provide `platform_version` input
3. The workflow pins the version(s) and pushes the change, allowing Argo CD to auto-sync

## Local packaging

```bash
helm lint charts/platform
helm package charts/platform --destination dist
```
