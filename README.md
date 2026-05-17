# phpIPAM Helm Chart

[![Helm](https://img.shields.io/badge/Helm-%3E%3D3.12-0f1689?logo=helm)](https://helm.sh)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-%3E%3D1.23-326ce5?logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![phpIPAM](https://img.shields.io/badge/phpIPAM-1.8-4cae4c)](https://phpipam.net)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue)](LICENSE)

A production-ready Helm chart for **[phpIPAM](https://phpipam.net)** — Open Source IP Address Management.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installing the Chart](#installing-the-chart)
- [Uninstalling the Chart](#uninstalling-the-chart)
- [Configuration](#configuration)
  - [Global](#global)
  - [Web Deployment](#web-deployment)
  - [Cron Deployment](#cron-deployment)
  - [Database](#database)
  - [Application](#application)
  - [Service](#service)
  - [Ingress](#ingress)
  - [Persistence](#persistence)
  - [Built-in MariaDB](#built-in-mariadb)
  - [Autoscaling, PDB, NetworkPolicy](#autoscaling-pdb-networkpolicy)
- [Image Versioning](#image-versioning)
- [Use Cases](#use-cases)
- [Upgrading](#upgrading)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This chart deploys phpIPAM on a Kubernetes cluster and includes:

| Component | Description |
|-----------|-------------|
| **web** | Apache/PHP frontend — scalable, supports multiple replicas |
| **cron** | Network discovery daemon — always runs as a single replica |
| **mariadb** | Optional built-in MariaDB StatefulSet — or point to an external DB |

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
              └──────────┬───────────────────────────┘
                         │
              ┌──────────▼───────────────────────────┐
              │         Deployment: cron             │
              │      (1 replica enforced, Recreate)  │
              │   NET_ADMIN + NET_RAW capabilities   │
              └──────────┬───────────────────────────┘
                         │
         ┌───────────────▼────────────────────────────────┐
         │  mariadb.enabled = true                         │
         │    StatefulSet: mariadb ──► PVC: mariadb-data   │
         │    Service: mariadb (ClusterIP + headless)      │
         ├────────────────────────────────────────────────┤
         │  mariadb.enabled = false                        │
         │    External database  (database.host required)  │
         └────────────────────────────────────────────────┘
```

> **Important:** phpIPAM requires `NET_ADMIN` and `NET_RAW` capabilities for ping/SNMP
> network discovery. `allowPrivilegeEscalation: true` is therefore mandatory.
> This chart is **incompatible with the Kubernetes `restricted` Pod Security Standard**.
> Use the `baseline` PSS or a custom policy that allows these capabilities.

## Prerequisites

| Requirement | Minimum version |
|-------------|----------------|
| Kubernetes | 1.23 |
| Helm | 3.12 |
| PersistentVolume provisioner | Required when any `persistence.*.enabled=true` |

## Quick Start

```bash
helm repo add phpipam https://manustars.github.io/phpipam
helm repo update

# With built-in MariaDB
helm install phpipam phpipam/phpipam -n ipam --create-namespace \
  --set mariadb.enabled=true \
  --set database.password=changeme \
  --set mariadb.auth.rootPassword=changeme-root

# With an external database
helm install phpipam phpipam/phpipam -n ipam --create-namespace \
  --set database.host=mydb.internal \
  --set database.password=mysecret
```

## Installing the Chart

### 1. Add the Helm repository

```bash
helm repo add phpipam https://manustars.github.io/phpipam
helm repo update
```

### 2. Prepare your values file

```bash
helm show values phpipam/phpipam > my-values.yaml
# Edit my-values.yaml — at minimum change the passwords
```

### 3. Install

```bash
helm install phpipam phpipam/phpipam \
  --namespace ipam \
  --create-namespace \
  --values my-values.yaml
```

### 4. First-time setup

If `mariadb.enabled=true` and `dbInit.enabled=true` (both default), the chart automatically
imports the phpIPAM schema via a post-install Job — no web installer needed.

Once the Job completes, disable the installer permanently:

```bash
helm upgrade phpipam phpipam/phpipam --reuse-values --set app.disableInstaller=true
```

If you are using an external database, open phpIPAM in the browser and follow the web
installer, then run the command above.

## Uninstalling the Chart

```bash
helm uninstall phpipam -n ipam
```

> **Warning:** PersistentVolumeClaims are protected with `helm.sh/resource-policy: keep`
> and are **not** deleted automatically on uninstall. Remove them manually when no longer needed:
>
> ```bash
> kubectl delete pvc -n ipam -l app.kubernetes.io/instance=phpipam
> ```

---

## Configuration

### Global

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Global registry override — useful for air-gapped clusters | `""` |
| `global.imagePullSecrets` | Global image pull secrets | `[]` |
| `global.storageClass` | Global StorageClass for all PVCs | `""` |
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the fully-qualified resource name | `""` |

### Web Deployment

| Parameter | Description | Default |
|-----------|-------------|---------|
| `web.image.repository` | phpipam-www image repository | `phpipam/phpipam-www` |
| `web.image.tag` | Image tag. Leave empty to track `Chart.appVersion` | `""` |
| `web.image.digest` | Image digest — takes precedence over tag | `""` |
| `web.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `web.replicaCount` | Number of web pods | `1` |
| `web.resources` | CPU/memory requests and limits | see [values.yaml](values.yaml) |
| `web.containerSecurityContext` | Container security context | `allowPrivilegeEscalation: true` + NET_ADMIN/NET_RAW |
| `web.livenessProbe` | Liveness probe | HTTP GET `/` |
| `web.readinessProbe` | Readiness probe | HTTP GET `/` |
| `web.nodeSelector` | Node selector | `{}` |
| `web.tolerations` | Tolerations | `[]` |
| `web.affinity` | Affinity rules | `{}` |
| `web.topologySpreadConstraints` | Topology spread constraints | `[]` |
| `web.extraEnv` | Extra environment variables | `[]` |
| `web.extraVolumes` | Extra volumes | `[]` |
| `web.extraVolumeMounts` | Extra volume mounts | `[]` |

### Cron Deployment

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cron.enabled` | Deploy the network discovery cron | `true` |
| `cron.image.repository` | phpipam-cron image repository | `phpipam/phpipam-cron` |
| `cron.image.tag` | Image tag. Leave empty to track `Chart.appVersion` | `""` |
| `cron.image.digest` | Image digest — takes precedence over tag | `""` |
| `cron.scanInterval` | Discovery scan interval | `1h` |
| `cron.resources` | CPU/memory requests and limits | see [values.yaml](values.yaml) |
| `cron.extraEnv` | Extra environment variables | `[]` |

> The cron deployment is **always `replicas: 1`** with `strategy: Recreate`. This is
> enforced by the chart — running multiple cron instances causes duplicate discovery jobs.

### Database

| Parameter | Description | Default |
|-----------|-------------|---------|
| `database.host` | External DB host — required when `mariadb.enabled=false` | `""` |
| `database.port` | DB port | `3306` |
| `database.name` | DB name | `phpipam` |
| `database.user` | DB username | `phpipam` |
| `database.password` | DB password — ignored when `existingSecret` is set | `phpipamadmin` |
| `database.webHost` | MySQL GRANT host (`%` = any pod IP) | `%` |
| `database.existingSecret` | Name of an existing secret containing the password | `""` |
| `database.existingSecretPasswordKey` | Key inside `existingSecret` | `database-password` |

### Application

| Parameter | Description | Default |
|-----------|-------------|---------|
| `app.timezone` | Container timezone | `UTC` |
| `app.base` | Base path for sub-path reverse proxy deployments | `/` |
| `app.trustXForwardedFor` | Trust `X-Forwarded-For` header | `false` |
| `app.disableInstaller` | Disable the web installer after first setup | `false` |
| `app.debug` | Enable debug mode | `false` |
| `app.offlineMode` | Block all outbound internet requests | `false` |
| `app.proxy.enabled` | Enable outbound HTTP proxy | `false` |
| `app.proxy.server` | Proxy host | `""` |
| `app.proxy.port` | Proxy port | `""` |

### Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | `ClusterIP`, `NodePort`, or `LoadBalancer` | `ClusterIP` |
| `service.port` | Service port | `80` |
| `service.nodePort` | NodePort value — only for `NodePort` type | `""` |
| `service.annotations` | Service annotations | `{}` |
| `service.loadBalancerIP` | Load balancer IP — only for `LoadBalancer` type | `""` |

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.className` | IngressClass name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Hostname and path rules | see [values.yaml](values.yaml) |
| `ingress.tls` | TLS configuration | `[]` |

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.logo.enabled` | Persist custom logos | `true` |
| `persistence.logo.size` | PVC size | `1Gi` |
| `persistence.logo.accessMode` | PVC access mode | `ReadWriteOnce` |
| `persistence.logo.storageClass` | StorageClass override | `""` |
| `persistence.logo.existingClaim` | Use an existing PVC | `""` |
| `persistence.ca.enabled` | Persist custom CA certificates | `true` |
| `persistence.ca.size` | PVC size | `100Mi` |
| `persistence.ca.accessMode` | PVC access mode | `ReadWriteOnce` |
| `persistence.ca.existingClaim` | Use an existing PVC | `""` |

> For multi-replica web deployments, set `accessMode: ReadWriteMany` on both PVCs
> and use a StorageClass that supports it (NFS, CephFS, Azure Files, AWS EFS, etc.).

### Built-in MariaDB

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mariadb.enabled` | Deploy MariaDB as a StatefulSet within this chart | `false` |
| `mariadb.image.repository` | MariaDB image repository | `mariadb` |
| `mariadb.image.tag` | MariaDB image tag | `lts` |
| `mariadb.image.digest` | Image digest — takes precedence over tag | `""` |
| `mariadb.auth.rootPassword` | MariaDB root password | `root-phpipamadmin` |
| `mariadb.auth.existingSecret` | Existing secret with the root password | `""` |
| `mariadb.auth.existingSecretRootPasswordKey` | Key inside `existingSecret` | `mariadb-root-password` |
| `mariadb.persistence.enabled` | Persist MariaDB data | `true` |
| `mariadb.persistence.size` | PVC size | `8Gi` |
| `mariadb.persistence.storageClass` | StorageClass override | `""` |
| `mariadb.persistence.existingClaim` | Use an existing PVC | `""` |
| `mariadb.mycnf` | Custom MariaDB configuration (`my.cnf` content) | `""` |
| `mariadb.resources` | CPU/memory requests and limits | see [values.yaml](values.yaml) |
| `mariadb.args` | Extra arguments passed to the MariaDB process | `[]` |
| `mariadb.extraEnv` | Extra environment variables for the MariaDB container | `[]` |

> `database.password` is the **single source of truth** for the DB user password.
> It is used by both the MariaDB container (`MARIADB_PASSWORD`) and the phpIPAM
> web/cron containers (`IPAM_DATABASE_PASS`).

> MariaDB data PVCs created via `volumeClaimTemplates` survive `helm uninstall` by design.

### Autoscaling, PDB, NetworkPolicy

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable HPA for web pods | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `5` |
| `autoscaling.targetCPUUtilizationPercentage` | CPU scale target | `80` |
| `podDisruptionBudget.enabled` | Enable PDB for web pods | `false` |
| `podDisruptionBudget.minAvailable` | Minimum available pods | `1` |
| `networkPolicy.enabled` | Enable NetworkPolicy | `false` |
| `networkPolicy.allowExternal` | Allow external traffic to reach web pods | `true` |

---

## Image Versioning

The chart resolves `web` and `cron` images in this priority order:

```
digest (sha256:...)        ←  highest priority — immutable, recommended for production
    ↓ if empty
tag   (e.g. "1.8")         ←  explicit version pin
    ↓ if empty
Chart.appVersion ("1.8")   ←  default, updated with each chart release
```

The `mariadb` image always requires an explicit tag (`lts`, `11.4`, `10.11`, …) because
its versioning is independent of phpIPAM.

### Pin web and cron to a specific phpIPAM version

```yaml
web:
  image:
    tag: "1.8"

cron:
  image:
    tag: "1.8"
```

Supported tags: `latest`, `nightly`, `1.8`, `1.7`, `v1.8.x` (static snapshots).

### Pin to an immutable digest (recommended for production)

```bash
# Retrieve the digest
docker pull phpipam/phpipam-www:1.8
docker inspect phpipam/phpipam-www:1.8 --format='{{index .RepoDigests 0}}'
# phpipam/phpipam-www@sha256:abc123...
```

```yaml
web:
  image:
    digest: "sha256:abc123..."
cron:
  image:
    digest: "sha256:def456..."
```

---

## Use Cases

### External database

```yaml
mariadb:
  enabled: false

database:
  host: "mydb.internal"
  port: 3306
  name: phpipam
  user: phpipam
  password: "mysecretpassword"
```

### External DB with an existing Kubernetes secret

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

### Custom MariaDB configuration

```yaml
mariadb:
  enabled: true
  mycnf: |
    [mysqld]
    innodb_buffer_pool_size = 256M
    character-set-server   = utf8mb4
    collation-server        = utf8mb4_unicode_ci
```

### Ingress with TLS via cert-manager

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
> Set `$session_storage = "database";` in phpIPAM's `config.php` after the first install.

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

### Air-gapped / private registry

```yaml
global:
  imageRegistry: registry.internal.example.com
  imagePullSecrets:
    - name: internal-registry-secret

web:
  image:
    tag: "1.8"

cron:
  image:
    tag: "1.8"
```

---

## Upgrading

Refer to [CHANGELOG.md](CHANGELOG.md) for breaking changes before upgrading.

### General upgrade

```bash
helm repo update
helm upgrade phpipam phpipam/phpipam --namespace ipam --reuse-values
```

### Upgrading phpIPAM (application version)

1. Read the [phpIPAM release notes](https://phpipam.net/news/) for any required database migrations.
2. **Back up the database** before proceeding.
3. Upgrade to the chart version that ships the new phpIPAM release:

```bash
helm repo update
helm upgrade phpipam phpipam/phpipam --namespace ipam --reuse-values --version <chart-version>
```

phpIPAM runs database migrations automatically on the first boot after a version change.

---

## Troubleshooting

### Pods rejected — `NET_ADMIN` / `NET_RAW` capabilities

If your cluster enforces the `restricted` Pod Security Standard, phpIPAM pods will fail admission.

```bash
kubectl describe pod -n ipam <pod-name> | grep -A5 "Warning\|Forbidden"
```

**Fix:** Apply the `baseline` PSS to the namespace:

```bash
kubectl label namespace ipam \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=baseline
```

### Cannot connect to the database

```bash
# Check that MariaDB is ready
kubectl get pods -n ipam -l app.kubernetes.io/component=database

# Check MariaDB logs
kubectl logs -n ipam statefulset/phpipam-mariadb

# Verify the password in the secret
kubectl get secret phpipam-db-credentials -n ipam \
  -o jsonpath='{.data.database-password}' | base64 -d
```

### Pods restart after a config or secret change

This is expected behaviour. The chart annotates pods with checksums of the ConfigMap and
Secret. Any value change triggers an automatic rolling restart so pods always run with
the latest configuration.

### PVC stuck in `Pending`

```bash
kubectl describe pvc -n ipam
```

Ensure a default StorageClass exists, or set one explicitly:

```bash
kubectl get storageclass
helm upgrade phpipam phpipam/phpipam --reuse-values --set global.storageClass=standard
```

### phpIPAM reports the wrong source IP behind a reverse proxy

Set `app.trustXForwardedFor: true` to enable `IPAM_TRUST_X_FORWARDED`.

---

## Security Considerations

| Area | Recommendation |
|------|---------------|
| **Default credentials** | Always change `database.password` and `mariadb.auth.rootPassword` in production |
| **Existing secrets** | Use `database.existingSecret` and `mariadb.auth.existingSecret` — keep credentials out of `values.yaml` and version control |
| **Image pinning** | Pin to a digest (`web.image.digest`) for immutable, auditable production deployments |
| **Disable installer** | Set `app.disableInstaller: true` immediately after the first setup |
| **Network isolation** | Enable `networkPolicy.enabled: true` to restrict traffic between components |
| **Capabilities** | `NET_ADMIN` + `NET_RAW` are required for ping/SNMP. If you don't use network scanning, remove them via `web.containerSecurityContext.capabilities` — ping will stop working |
| **TLS** | Always terminate TLS at the Ingress in production |
| **Service account** | `automountServiceAccountToken: false` is set by default |

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository and create a feature branch
2. Clone locally and test with `helm lint .` and `helm template test .`
3. Update [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]`
4. Open a Pull Request describing what changed and why

---

## License

This chart is licensed under the [GNU General Public License v3.0](LICENSE).

phpIPAM is © phpipam.net and is independently licensed under GPL-3.0.
