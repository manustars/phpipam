{{/*
Expand the name of the chart.
*/}}
{{- define "phpipam.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this.
*/}}
{{- define "phpipam.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "phpipam.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels — applied to every resource.
*/}}
{{- define "phpipam.labels" -}}
helm.sh/chart: {{ include "phpipam.chart" . }}
{{ include "phpipam.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — used in matchLabels / selector.
*/}}
{{- define "phpipam.selectorLabels" -}}
app.kubernetes.io/name: {{ include "phpipam.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Web component labels.
*/}}
{{- define "phpipam.web.labels" -}}
{{ include "phpipam.labels" . }}
app.kubernetes.io/component: web
{{- end }}

{{/*
Web component selector labels.
*/}}
{{- define "phpipam.web.selectorLabels" -}}
{{ include "phpipam.selectorLabels" . }}
app.kubernetes.io/component: web
{{- end }}

{{/*
Cron component labels.
*/}}
{{- define "phpipam.cron.labels" -}}
{{ include "phpipam.labels" . }}
app.kubernetes.io/component: cron
{{- end }}

{{/*
Cron component selector labels.
*/}}
{{- define "phpipam.cron.selectorLabels" -}}
{{ include "phpipam.selectorLabels" . }}
app.kubernetes.io/component: cron
{{- end }}

{{/*
Service account name.
*/}}
{{- define "phpipam.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "phpipam.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database host — uses bitnami mariadb service name when subchart is enabled,
otherwise requires database.host to be set explicitly.
*/}}
{{- define "phpipam.databaseHost" -}}
{{- if .Values.database.host }}
{{- .Values.database.host }}
{{- else if .Values.mariadb.enabled }}
{{- printf "%s-mariadb" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- fail "database.host is required when mariadb.enabled is false" }}
{{- end }}
{{- end }}

{{/*
Database password secret name.
*/}}
{{- define "phpipam.secretName" -}}
{{- if .Values.database.existingSecret }}
{{- .Values.database.existingSecret }}
{{- else }}
{{- printf "%s-db-credentials" (include "phpipam.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Database password key inside the secret.
*/}}
{{- define "phpipam.secretPasswordKey" -}}
{{- if .Values.database.existingSecret -}}
{{- .Values.database.existingSecretPasswordKey -}}
{{- else -}}
{{- "database-password" -}}
{{- end -}}
{{- end }}

{{/*
Web image.
Resolution order: digest (immutable) > explicit tag > Chart.AppVersion.
*/}}
{{- define "phpipam.web.image" -}}
{{- $registry := coalesce .Values.global.imageRegistry .Values.web.image.registry "docker.io" -}}
{{- if .Values.web.image.digest -}}
{{- printf "%s/%s@%s" $registry .Values.web.image.repository .Values.web.image.digest -}}
{{- else -}}
{{- $tag := default .Chart.AppVersion .Values.web.image.tag -}}
{{- printf "%s/%s:%s" $registry .Values.web.image.repository $tag -}}
{{- end -}}
{{- end }}

{{/*
Cron image.
Resolution order: digest (immutable) > explicit tag > Chart.AppVersion.
*/}}
{{- define "phpipam.cron.image" -}}
{{- $registry := coalesce .Values.global.imageRegistry .Values.cron.image.registry "docker.io" -}}
{{- if .Values.cron.image.digest -}}
{{- printf "%s/%s@%s" $registry .Values.cron.image.repository .Values.cron.image.digest -}}
{{- else -}}
{{- $tag := default .Chart.AppVersion .Values.cron.image.tag -}}
{{- printf "%s/%s:%s" $registry .Values.cron.image.repository $tag -}}
{{- end -}}
{{- end }}

{{/*
MariaDB image.
MariaDB versioning is independent from phpIPAM — always requires an explicit tag.
*/}}
{{- define "phpipam.mariadb.image" -}}
{{- $registry := coalesce .Values.global.imageRegistry .Values.mariadb.image.registry "docker.io" -}}
{{- if .Values.mariadb.image.digest -}}
{{- printf "%s/%s@%s" $registry .Values.mariadb.image.repository .Values.mariadb.image.digest -}}
{{- else -}}
{{- printf "%s/%s:%s" $registry .Values.mariadb.image.repository .Values.mariadb.image.tag -}}
{{- end -}}
{{- end }}

{{/*
Merged imagePullSecrets from global and local scopes.
*/}}
{{- define "phpipam.imagePullSecrets" -}}
{{- $secrets := concat (.Values.global.imagePullSecrets | default list) (.Values.imagePullSecrets | default list) }}
{{- if $secrets }}
imagePullSecrets:
  {{- range $secrets }}
  - name: {{ . }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Logo PVC name.
*/}}
{{- define "phpipam.logoPvcName" -}}
{{- if .Values.persistence.logo.existingClaim }}
{{- .Values.persistence.logo.existingClaim }}
{{- else }}
{{- printf "%s-logo" (include "phpipam.fullname" .) }}
{{- end }}
{{- end }}

{{/*
CA certificates PVC name.
*/}}
{{- define "phpipam.caPvcName" -}}
{{- if .Values.persistence.ca.existingClaim }}
{{- .Values.persistence.ca.existingClaim }}
{{- else }}
{{- printf "%s-ca" (include "phpipam.fullname" .) }}
{{- end }}
{{- end }}

{{/*
MariaDB component labels.
*/}}
{{- define "phpipam.mariadb.labels" -}}
{{ include "phpipam.labels" . }}
app.kubernetes.io/component: database
{{- end }}

{{/*
MariaDB component selector labels.
*/}}
{{- define "phpipam.mariadb.selectorLabels" -}}
{{ include "phpipam.selectorLabels" . }}
app.kubernetes.io/component: database
{{- end }}

{{/*
MariaDB root-password secret name.
*/}}
{{- define "phpipam.mariadb.secretName" -}}
{{- if .Values.mariadb.auth.existingSecret -}}
{{- .Values.mariadb.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-mariadb-credentials" (include "phpipam.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
MariaDB root-password key inside the secret.
*/}}
{{- define "phpipam.mariadb.secretRootPasswordKey" -}}
{{- if .Values.mariadb.auth.existingSecret -}}
{{- .Values.mariadb.auth.existingSecretRootPasswordKey -}}
{{- else -}}
{{- "mariadb-root-password" -}}
{{- end -}}
{{- end }}

{{/*
MariaDB data PVC name.
*/}}
{{- define "phpipam.mariadb.pvcName" -}}
{{- if .Values.mariadb.persistence.existingClaim -}}
{{- .Values.mariadb.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-mariadb-data" (include "phpipam.fullname" .) -}}
{{- end -}}
{{- end }}
