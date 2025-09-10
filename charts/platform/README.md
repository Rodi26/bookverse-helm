# BookVerse Platform Chart

A simple, demo-focused Helm chart that aggregates the BookVerse services (web, inventory, recommendations, recommendations-worker, checkout) and deploys them as a single platform application.

## Key concepts

- Single platform version controls all component image tags via `platform.version`.
- Static replicas and simple probes; no HPA/PDB by default for demo simplicity.
- HTTP-only by default; web ingress is optional and configurable.
- Services communicate over internal ClusterIP DNS names.

## Values overview

- `platform.version`: Tag applied to all images unless a service-specific `tag` is set.
- `global.imageRegistry`: Base registry for images.
- `web.ingress`: `{ enabled, className, host, tls: { enabled, secretName } }`
- `web.service.type`: Service type for web (default `ClusterIP`).
- `*.replicas`, `*.port`, `*.env`: Per-service settings.
- `recommendations.config` and `recommendations.resources`: Optional config/resource ConfigMaps.
  

## Quickstart

Render:

```bash
helm template bookverse charts/platform -f charts/platform/values.yaml
```

Install:

```bash
helm upgrade --install bookverse charts/platform \
  -n bookverse --create-namespace \
  -f charts/platform/values.yaml
```

Set a new platform version:

```bash
# Update platform.version in the single values.yaml
sed -i '' 's/platform:\n  version: ".*"/platform:\n  version: "prod-2025-09-06"/' charts/platform/values.yaml
```

## Ingress

- Enable via `web.ingress.enabled: true` and set `web.ingress.host`.
- If you do not have an ingress controller, either:
  - Use `kubectl port-forward svc/platform-web 8080:80`, or
  - Set `web.service.type: LoadBalancer`.

## Environments

- Single `values.yaml` is used (no env overlays). Argo CD Applications reference this chart directly without additional value files.

## Notes

This chart is intended for demo purposes. Security, TLS, monitoring, and scaling are intentionally minimal by default. Enhance as needed for non-demo scenarios.
