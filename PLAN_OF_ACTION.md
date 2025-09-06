# BookVerse Helm Platform – Plan of Action

This plan outlines the flow, algorithms, and logic to scaffold and flesh out the Helm repository for BookVerse. It targets the `charts/platform` chart, integrates with GitOps (Argo CD Applications), and supports multiple environments via `values-*.yaml`.

## Goals

- Single platform chart aggregating `web`, `inventory`, `recommendations`, `recommendations-worker`, `checkout` and deploying them as one unit.
- One platform version controls all component image tags; per-service overrides are possible but discouraged.
- Environment-driven configuration (dev/qa/staging/prod) with overridable images, env vars, and ingress.
- Simple, static deployments: readiness/liveness probes, fixed replicas/resources, no HPA/PDB by default.
- GitOps-friendly structure compatible with `bookverse-demo-assets/gitops/apps/*/platform.yaml`.
- Emphasis on demo simplicity, readability, elegance, and easy maintenance.

## Demo principles and constraints

- The platform application is the authoritative deployment unit; individual services are internal implementation details.
- Static resources and replicas (typically 1) for simplicity; do not introduce autoscaling in the demo.
- Plain HTTP by default; TLS is not mandatory. Can be enabled later if needed.
- No Kubernetes monitoring stack (e.g., Prometheus/Grafana) is included; the focus is on JFrog Platform.
- Avoid managing sensitive data; prefer ConfigMaps and non-sensitive env vars. If a Secret is required, reference a pre-created Secret by name rather than templating secret data in-repo.

## High-level Flow

1. Inputs resolved (values layering):
   - Chart defaults `values.yaml` → environment overrides `values-<env>.yaml` → optional Helm `--set` overrides
   - Image registry and repositories resolved via `global.imageRegistry` and per-service `repository`/`tag`
2. Template rendering:
   - Generate Deployments, Services, Ingresses, ConfigMaps; no HPA/PDB by default
3. Argo CD sync loop:
   - ArgoCD Applications point to chart path and env value files; automated sync applies deltas
4. Runtime behavior:
   - Services register DNS names, web ingresses route external traffic (TLS disabled by default), services communicate by internal service DNS over HTTP

## Chart Structure (target)

- `charts/platform/Chart.yaml`: chart metadata
- `charts/platform/values.yaml`: safe defaults (no secrets), sensible dev defaults
- `charts/platform/values-<env>.yaml`: env-specific images, tags, URL bases, ingress hosts, resource classes
- `templates/`
  - Deployments: `deployment-*.yaml`
  - Services: `service-*.yaml`
  - Ingresses: `ingress-*.yaml`
  - Config: `configmap-*.yaml`, `secret-*.yaml` (optional)
  - Operational: `NOTES.txt`

## Algorithms and Logic

### 1) Image Resolution

Decision logic for image reference per service `svc` in {web, inventory, recommendations, recommendations.worker, checkout}. The platform version is authoritative; internal services inherit this version unless explicitly overridden.

```txt
platformTag = default(.Values.platform.version, default(.Chart.AppVersion, "latest"))

if .Values.svc.repository != "":
  imageRepo = .Values.svc.repository
else if .Values.global.imageRegistry != "":
  imageRepo = printf "%s/%s" .Values.global.imageRegistry defaultRepoSuffixForSvc
else:
  imageRepo = ""  # force explicit override

imageTag = default(.Values.svc.tag, platformTag)
image = printf "%s:%s" imageRepo imageTag
```

Rationale: The platform version provides a single source of truth for the demo. Microservices are internal; independent version resolution is unnecessary and can be confusing.

### 2) Environment Variables and Cross-service URLs

For internal communication, prefer ClusterIP service names and ports. Compute base URLs:

```txt
INVENTORY_BASE_URL = printf "http://%s" (include .Release.Namespace) ? "inventory.%s.svc.cluster.local" : "inventory"
RECOMMENDATIONS_BASE_URL = "http://recommendations"
CHECKOUT_BASE_URL = "http://checkout"
```

Expose externally only via web ingress. Keep service DNS stable using matching `metadata.name` and `spec.selector` labels.

### 3) Probes

Apply service-specific health endpoints and timing:

- `web`: GET `/` on port `.Values.web.port`
- `inventory`, `recommendations`, `checkout`: GET `/health` on their ports

Timings (adjustable via values if needed):

```txt
readiness: initialDelay=5s, period=10s
liveness: initialDelay=15s, period=20s
```

### 4) ConfigMaps and Mounted Resources

`recommendations` uses:

- ConfigMap `recommendations-config` with `recommendations-settings.yaml` when `recommendations.config.enabled`
- ConfigMap `recommendations-resources` with `stopwords.txt` when `recommendations.resources.enabled`

Mount logic:

```txt
if config.enabled: mount at config.mountPath
if resources.enabled: mount at resources.mountPath
```

Worker shares the same mounts and reads refresh interval from `recommendations.worker.refreshSeconds`.

### 5) Optional Components

- `recommendations-worker` is controlled by `recommendations.worker.enabled`.
- Feature flags for the demo: `web.ingress.enabled`, `recommendations.config.enabled`, `recommendations.resources.enabled`. No HPA/PDB toggles in the demo.

### 6) Ingress Strategy

Ingress is required only for `web`. Algorithm:

```txt
if .Values.web.ingress.enabled:
  host = .Values.web.ingress.host  # e.g. web.dev.bookverse.local
  annotations = merge(.Values.web.ingress.annotations, classDefaults)
  tls = optional from .Values.web.ingress.tls
  backend → service-web:port
```

Defaults: support NGINX ingress; TLS disabled by default; allow class name override via `.Values.web.ingress.className`.

### 7) Service Types and Ports

- All internal services: ClusterIP by default
- `web` service exposed through Ingress; can switch to LoadBalancer when `.Values.web.service.type == LoadBalancer`

### 8) Fixed replicas and simple resources

Values design (static):

```txt
svc.replicas: integer (default: 1)
svc.resources: { requests: { cpu, memory }, limits: { cpu, memory } }
```

Rendering logic:

```txt
Render a Deployment with spec.replicas = .Values.svc.replicas (fallback 1).
Do not render HPA or PDB in the demo.
```

### 9) Secrets Management

- For the demo, avoid storing sensitive values. Prefer ConfigMaps and plain env vars.
- If a Secret is truly required, reference a pre-created Secret by name and inject via `valueFrom.secretKeyRef`. Do not template Secret data into the chart by default.

### 10) Namespacing and Release Names

- Keep object names stable and readable: `name: <svc>` or `platform-<svc>` for web. Selectors use `app: <svc>` labels.
- ArgoCD sets namespace via Application spec; templates should not hardcode namespaces.

## Deliverables and Edits

1) Values expansion
   - Add a `platform.version` value that controls all component image tags.
   - Extend `values.yaml` with sections for:
     - `web.ingress` (with `enabled`, `className`, `host`, `tls.enabled` default false), `web.resources`, `web.replicas`, `web.service.type`
     - Per service: `replicas`, `resources`; optional `secrets` (by reference only)
2) Templates additions
   - `templates/ingress-web.yaml`: ensure `enabled` flag, className support, TLS disabled by default
   - Keep existing Deployments/Services/ConfigMaps; do not add HPA or PDB templates for the demo
3) Hardening (lightweight for demo)
   - Optionally expose `securityContext` and `podSecurityContext` values, but keep defaults minimal
4) Documentation and examples
   - Update chart `README.md` with install commands, values schema, and the platform-version model
   - Provide example `values-qa.yaml` and `values-staging.yaml` aligned with ArgoCD apps

## GitOps Flow with Argo CD

- Apps in `bookverse-demo-assets/gitops/apps/*/platform.yaml` already point to this chart with the right value files.
- On commit to `main` of the Helm repo:
  - ArgoCD detects change, syncs per environment
  - Rollouts happen per Deployment strategy; replicas are static and controlled via values

## Testing Strategy

1. Local dry-runs:
   - `helm template charts/platform -f charts/platform/values.yaml`
   - Add `-f values-dev.yaml` to verify env overlay
2. Linting:
   - `helm lint charts/platform`
3. Kind/minikube smoke tests:
   - Install dev overlay and confirm pods ready, services discoverable, ingress reachable
4. CI suggestions:
   - Chart schema validation, kubeconform, and conftest for policy checks

## Rollout and Observability

- Set rolling update strategy on Deployments
- No Kubernetes monitoring stack (Prometheus/Grafana) included in the demo; rely on ArgoCD app status, `kubectl get pods`, readiness/liveness, and logs

## Backlog (Future Enhancements)

- Autoscaling (HPA) and PDBs for resilience
- TLS termination and certificate management
- External Secrets integration for sensitive configs
- ServiceMonitors/Grafana dashboards and NetworkPolicies
- Canary/BlueGreen strategies using Argo Rollouts

## Acceptance Criteria

- All services deploy successfully in dev via ArgoCD using `values-dev.yaml`.
- A single platform version applies to all component images by default.
- Web is exposed via Ingress when enabled and routes to service over HTTP (TLS disabled by default).
- Recommendations mount config and resources correctly; worker runs only when enabled and respects refresh interval.
- Lint/template checks pass and docs updated.
