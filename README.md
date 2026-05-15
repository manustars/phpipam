# phpIPAM Helm Chart

A production-ready Helm chart for [phpIPAM](https://phpipam.net) — Open Source IP Address Management.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [TL;DR](#tldr)
- [Installing](#installing)
- [Uninstalling](#uninstalling)
- [Configuration](#configuration)
- [Image Versioning](#image-versioning)
- [Use Cases](#use-cases)
- [Upgrading](#upgrading)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

---

## Overview

This chart deploys phpIPAM on a Kubernetes cluster. It includes:

| Component | Description |
|-----------|-------------|
| **web** | Apache/PHP frontend (scalable, multiple replicas supported) |
| **cron** | Network discovery daemon (always single replica) |
| **mariadb** | Optional built-in MariaDB container (or point to an external DB) |

## Architecture

```
                        ┌─────────────────┐
                        │     Ingress      │  (optional)
                        └────────┬────────┘
                                 │
                        ┌────────▼────────┐
                        │    Service      │  ClusterIP / NodePort / LB
                        └────────┬────────┘
                                 │
              ┌──────────────────▼──────────────────┐
              │         Deployment: web              │
              │      (N replicas, RollingUpdate)     │
              │   NET_ADMIN + NET_RAW capabilities   │
              └──────────────────┬──────────────────┘
                                 │
              ┌──────────────────▼──────────────────┐
              │         Deployment: cron             │
              │      (1 replica, Recreate)           │
              │   NET_ADMIN + NET_RAW capabilities   │
              └──────────────────┬──────────────────┘
                                 │
               ┌─────────────────▼────────────────────┐
               │  mariadb.enabled=true                 │
               │    Deployment: mariadb  ──► PVC data  │
               │    Service: mariadb                   │
               ├───────────────────────────────────────┤
               │  mariadb.enabled=false                │
               │    External DB (database.host)        │
               └───────────────────────────────────────┘
```

> **Note:** phpIPAM requires `NET_ADMIN` and `NET_RAW` capabilities for ping and SNMP network
> discovery. This means `allowPrivilegeEscalation: true` is mandatory and the chart is
> incompatible with the Kubernetes `restricted` Pod Security Standard.
> Use the `baseline` PSS or a custom policy that allows these capabilities.

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Kubernetes  | ≥ 1.23  |
| Helm        | ≥ 3.12  |
| PV provisioner | Required if any `persistence.*.enabled=true` |

## TL;DR

```bash
# Built-in MariaDB (default)
helm install phpipam . -n ipam --create-namespace

# External database
helm install phpipam . -n ipam --create-namespace \
  --set mariadb.enabled=false \
  --set database.host=mydb.internal \
  --set database.password=mysecret
```

## Installing

### 1. Prepare values

Copy and edit the default values file:

```bash
cp values.yaml my-values.yaml
# Edit my-values.yaml with your settings
```

### 2. Install

```bash
helm install phpipam . \
  --namespace ipam \
  --create-namespace \
  --values my-values.yaml
```

### 3. First-time setup

After installation, open phpIPAM in the browser and follow the web installer:

1. Choose **"MySQL import instructions"** → **"Automatic database installation"**
2. Enter the credentials shown in the post-install NOTES
3. Once setup is complete, **disable the installer** to prevent re-running it:

```bash
helm upgrade phpipam . --reuse-values --set app.disableInstaller=true
```

## Uninstalling

```bash
helm uninstall phpipam -n ipam
```

> **Warning:** PersistentVolumeClaims are **not** deleted automatically. Remove them manually if no longer needed:
> ```bash
> kubectl delete pvc -n ipam -l app.kubernetes.io/instance=phpipam
> ```

---

## Configuration

### Global

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Global registry override (useful for air-gapped clusters) | `""` |
| `global.imagePullSecrets` | Global image pull secrets | `[]` |
| `global.storageClass` | Global StorageClass for all PVCs | `""` |
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the fully-qualified resource name | `""` |

### Web Deployment (`web.*`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `web.image.repository` | phpipam-www image | `phpipam/phpipam-www` |
| `web.image.tag` | Image tag. Empty = `Chart.appVersion` | `""` |
| `web.image.digest` | Image digest (overrides tag) | `""` |
| `web.replicaCount` | Number of web pods | `1` |
| `web.resources` | CPU/memory requests and limits | see values.yaml |
| `web.containerSecurityContext` | Container security context | `allowPrivilegeEscalation: true, NET_ADMIN, NET_RAW` |
| `web.livenessProbe` | Liveness probe configuration | HTTP GET `/` |
| `web.readinessProbe` | Readiness probe configuration | HTTP GET `/` |
| `web.nodeSelector` | Node selector | `{}` |
| `web.tolerations` | Tolerations | `[]` |
| `web.affinity` | Affinity rules | `{}` |
| `web.topologySpreadConstraints` | Topology spread constraints | `[]` |
| `web.extraEnv` | Extra environment variables | `[]` |

### Cron Deployment (`cron.*`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cron.enabled` | Deploy the network discovery cron | `true` |
| `cron.image.repository` | phpipam-cron image | `phpipam/phpipam-cron` |
| `cron.image.tag` | Image tag. Empty = `Chart.appVersion` | `""` |
| `cron.image.digest` | Image digest (overrides tag) | `""` |
| `cron.scanInterval` | Discovery scan interval | `1h` |
| `cron.resources` | CPU/memory requests and limits | see values.yaml |

> The cron deployment is always `replicas: 1` with `strategy: Recreate`. This is enforced
> by the chart and cannot be overridden — running multiple cron instances causes duplicate
> discovery jobs.

### Database (`database.*`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `database.host` | External DB host. Required when `mariadb.enabled=false` | `""` |
| `database.port` | DB port | `3306` |
| `database.name` | DB name | `phpipam` |
| `database.user` | DB username | `phpipam` |
| `database.password` | DB password (ignored if `existingSecret` is set) | `phpipamadmin` |
| `database.webHost` | MySQL GRANT host (`%` = any pod IP) | `%` |
| `database.existingSecret` | Existing secret name with DB password | `""` |
| `database.existingSecretPasswordKey` | Key inside `existingSecret` | `database-password` |

### Application (`app.*`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `app.timezone` | Container timezone (`TZ`) | `UTC` |
| `app.base` | Base path for sub-path reverse proxy deployments | `/` |
| `app.trustXForwardedFor` | Trust `X-Forwarded-For` header | `false` |
| `app.disableInstaller` | Disable the web installer (set after first setup) | `false` |
| `app.debug` | Enable debug mode | `false` |
| `app.offlineMode` | Block all internet requests | `false` |
| `app.proxy.*` | Outbound HTTP proxy settings | see values.yaml |

### Service (`service.*`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | `ClusterIP`, `NodePort`, `LoadBalancer` | `ClusterIP` |
| `service.port` | Service port | `80` |
| `service.nodePort` | NodePort value (only for `NodePort` type) | `""` |
| `service.annotations` | Service annotations | `{}` |

### Ingress (`ingress.*`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Hostnames and paths | see values.yaml |
| `ingress.tls` | TLS configuration | `[]` |

### Persistence (`persistence.*`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.logo.enabled` | Persist custom logos | `true` |
| `persistence.logo.size` | PVC size | `1Gi` |
| `persistence.logo.accessMode` | PVC access mode | `ReadWriteOnce` |
| `persistence.logo.existingClaim` | Use an existing PVC | `""` |
| `persistence.ca.enabled` | Persist custom CA certificates | `true` |
| `persistence.ca.size` | PVC size | `100Mi` |
| `persistence.ca.existingClaim` | Use an existing PVC | `""` |

> For multi-replica web deployments, set `accessMode: ReadWriteMany` and use a storage class
> that supports it (e.g. NFS, CephFS, Azure Files, EFS).

### Built-in MariaDB (`mariadb.*`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mariadb.enabled` | Deploy MariaDB as a container | `true` |
| `mariadb.image.repository` | MariaDB image | `mariadb` |
| `mariadb.image.tag` | MariaDB image tag | `lts` |
| `mariadb.image.digest` | Image digest (overrides tag) | `""` |
| `mariadb.auth.rootPassword` | MariaDB root password | `root-phpipamadmin` |
| `mariadb.auth.existingSecret` | Existing secret with root password | `""` |
| `mariadb.persistence.enabled` | Persist MariaDB data | `true` |
| `mariadb.persistence.size` | PVC size | `8Gi` |
| `mariadb.persistence.existingClaim` | Use an existing PVC | `""` |
| `mariadb.resources` | CPU/memory requests and limits | see values.yaml |

> The user password (`MARIADB_PASSWORD`) is always sourced from `database.password` /
> `database.existingSecret` — it is the single source of truth shared between the MariaDB
> container and the phpIPAM web/cron containers.

### Autoscaling, PDB, NetworkPolicy

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable HPA for web pods | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `5` |
| `autoscaling.targetCPUUtilizationPercentage` | CPU target | `80` |
| `podDisruptionBudget.enabled` | Enable PDB for web pods | `false` |
| `podDisruptionBudget.minAvailable` | Min available pods | `1` |
| `networkPolicy.enabled` | Enable NetworkPolicy | `false` |
| `networkPolicy.allowExternal` | Allow external traffic to web pods | `true` |

---

## Image Versioning

The chart implements a three-tier image resolution for `web` and `cron`:

```
digest (sha256:...)   ← highest priority, immutable
    ↓ (if empty)
tag   (e.g. "1.8")   ← explicit override
    ↓ (if empty)
Chart.appVersion      ← default, in sync with chart release
```

### Pin to a specific phpIPAM version

```yaml
# values.yaml
web:
  image:
    tag: "1.8"          # or "1.7", "latest", "nightly"

cron:
  image:
    tag: "1.8"          # keep in sync with web
```

### Pin to an immutable digest (recommended for production)

```bash
# Get the digest
docker pull phpipam/phpipam-www:1.8
docker inspect phpipam/phpipam-www:1.8 --format='{{index .RepoDigests 0}}'
# → phpipam/phpipam-www@sha256:abc123...
```

```yaml
web:
  image:
    digest: "sha256:abc123..."
cron:
  image:
    digest: "sha256:def456..."
```

### Upgrade phpIPAM version

1. Update `appVersion` in `Chart.yaml` (and bump `version`)
2. Set `web.image.tag: ""` and `cron.image.tag: ""` to follow the new appVersion
3. Run `helm upgrade`

---

## Use Cases

### Minimal — built-in MariaDB (default)

```bash
helm install phpipam . -n ipam --create-namespace
```

### External database

```yaml
# my-values.yaml
mariadb:
  enabled: false

database:
  host: "mydb.internal"
  port: 3306
  name: phpipam
  user: phpipam
  password: "mysecretpassword"
```

```bash
helm install phpipam . -n ipam --create-namespace -f my-values.yaml
```

### External DB with existing Kubernetes secret

```bash
kubectl create secret generic phpipam-db-secret -n ipam \
  --from-literal=database-password=mysecretpassword
```

```yaml
mariadb:
  enabled: false

database:
  host: "mydb.internal"
  existingSecret: "phpipam-db-secret"
  existingSecretPasswordKey: "database-password"
```

### Ingress with TLS (cert-manager)

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "16m"
  hosts:
    - host: ipam.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: phpipam-tls
      hosts:
        - ipam.example.com

app:
  trustXForwardedFor: true
```

### Multi-replica web with HPA

> Requires `ReadWriteMany` storage and database session storage configured in phpIPAM.

```yaml
web:
  replicaCount: 2

persistence:
  logo:
    accessMode: ReadWriteMany
    storageClass: nfs-client
  ca:
    accessMode: ReadWriteMany
    storageClass: nfs-client

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

After scaling up, configure phpIPAM to use database session storage:
set `$session_storage = "database";` in phpIPAM's `config.php`.

### Air-gapped / private registry

```yaml
global:
  imageRegistry: registry.internal.example.com
  imagePullSecrets:
    - internal-registry-secret

web:
  image:
    tag: "1.8"      # explicit tag required when using private mirrors

cron:
  image:
    tag: "1.8"

mariadb:
  image:
    tag: "lts"
```

---

## Upgrading

### General upgrade procedure

```bash
helm upgrade phpipam . --namespace ipam --reuse-values
```

Always check the [CHANGELOG](CHANGELOG.md) before upgrading.

### Chart 0.x → future breaking changes

Breaking changes will be documented in [CHANGELOG.md](CHANGELOG.md) with migration steps.

### Upgrading phpIPAM (application)

1. Check the [phpIPAM release notes](https://phpipam.net/news/) for database migrations.
2. **Backup the database** before upgrading.
3. Update the image tag and upgrade:

```bash
helm upgrade phpipam . --namespace ipam --reuse-values \
  --set web.image.tag=1.8 \
  --set cron.image.tag=1.8
```

4. phpIPAM runs database migrations automatically on first boot after a version upgrade.

---

## Troubleshooting

### Pods not starting — `NET_ADMIN` / `NET_RAW`

phpIPAM requires elevated network capabilities. If your cluster enforces the `restricted`
Pod Security Standard, pods will be rejected.

```bash
kubectl describe pod -n ipam <pod-name> | grep -A5 "Warning\|Error"
```

**Fix:** Apply the `baseline` PSS to the namespace, or add a specific exemption:

```bash
kubectl label namespace ipam \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=baseline
```

### Web installer fails — cannot connect to database

```bash
# Check MariaDB is running and ready
kubectl get pods -n ipam -l app.kubernetes.io/component=database

# Check MariaDB logs
kubectl logs -n ipam deployment/phpipam-mariadb

# Check the credentials match
kubectl get secret phpipam-db-credentials -n ipam -o jsonpath='{.data.database-password}' | base64 -d
```

### Pods restart after config change

This is expected: the chart annotates pods with `checksum/configmap` and `checksum/secret`.
When you change any configuration value, pods roll automatically to pick up the new config.

### PVC in Pending state

```bash
kubectl describe pvc -n ipam phpipam-mariadb-data
```

Check that your cluster has a default StorageClass or set `global.storageClass`:

```bash
kubectl get storageclass
helm upgrade phpipam . --reuse-values --set global.storageClass=standard
```

### phpIPAM reports wrong source IP behind a reverse proxy

Set `app.trustXForwardedFor: true` to enable `IPAM_TRUST_X_FORWARDED`.

---

## Security Considerations

| Area | Guidance |
|------|----------|
| **Default passwords** | Always override `database.password` and `mariadb.auth.rootPassword` in production |
| **Existing secrets** | Use `database.existingSecret` and `mariadb.auth.existingSecret` to keep credentials out of `values.yaml` |
| **Image pinning** | Pin images to a digest (`web.image.digest`) for immutable, auditable deployments |
| **Installer** | Set `app.disableInstaller: true` after first setup |
| **Network** | Enable `networkPolicy.enabled: true` to restrict traffic between components |
| **Capabilities** | `NET_ADMIN` + `NET_RAW` are required. If you don't use network scanning, you can remove them via `web.containerSecurityContext.capabilities` — but ping will stop working |
| **TLS** | Always use TLS in production via Ingress + cert-manager |
| `automountServiceAccountToken` | Disabled by default (`false`) |
