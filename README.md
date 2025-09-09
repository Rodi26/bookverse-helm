# BookVerse Helm

Platform-centric Helm charts for the BookVerse demo.

## Charts

- charts/platform: Deploys web and microservices used by the platform release

## CI

- `Helm CI` lints and packages the chart; upload to JFrog is a placeholder until connectivity is available.
- `Platform release handler` listens to `repository_dispatch` (PROD) and pins versions in `charts/platform/values.yaml`, then packages the chart.

## Local packaging

```bash
helm lint charts/platform
helm package charts/platform --destination dist
```
