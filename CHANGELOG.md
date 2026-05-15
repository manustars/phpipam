# Changelog

All notable changes to this chart are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Chart version follows [Semantic Versioning](https://semver.org/).

---

## [0.1.0] — 2026-05-15

### Added
- Initial release
- `web` deployment (phpipam-www) with liveness/readiness probes, HPA, PDB support
- `cron` deployment (phpipam-cron), always single replica with `Recreate` strategy
- Built-in MariaDB deployment (`mariadb.enabled=true`) with PVC and credential secrets
- External database support (`mariadb.enabled=false` + `database.host`)
- Image versioning: tag defaults to `Chart.appVersion`; digest support for immutable deployments
- Separate secrets for phpIPAM DB credentials and MariaDB root credentials
- `database.existingSecret` and `mariadb.auth.existingSecret` for bring-your-own-secret
- ConfigMap checksum annotations on pods (automatic restart on config change)
- Ingress with TLS support
- NetworkPolicy for web and cron pods
- PodDisruptionBudget for web pods
- HPA (autoscaling/v2) for web pods
- Persistent volumes for logos, CA certificates, and MariaDB data
- `global.imageRegistry` override for air-gapped environments
- `app.disableInstaller` flag to lock down the web installer after setup
- Outbound proxy support (`app.proxy.*`)
- Full `extraEnv`, `extraVolumes`, `extraVolumeMounts` extension points on all deployments
