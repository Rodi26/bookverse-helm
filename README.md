# BookVerse Helm

Platform-centric Helm charts for the BookVerse demo.

## Charts
- charts/platform: Deploys web and microservices used by the platform release

## CI
- `Helm CI` lints and packages the chart; upload to JFrog is a placeholder until connectivity is available.
- `On Platform Release` listens to repository_dispatch `platform_release` and (placeholder) bumps the chart.

## Local packaging
```
helm lint charts/platform
helm package charts/platform --destination dist
```
