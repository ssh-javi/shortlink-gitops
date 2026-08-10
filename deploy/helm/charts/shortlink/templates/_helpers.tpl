{{/*
ShortLink - helper templates.
*/}}

{{/*
Full name: <release>-<chart>, capped at 63 chars (k8s label limit).
*/}}
{{- define "shortlink.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels used by every resource.
*/}}
{{- define "shortlink.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "shortlink.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: shortlink
{{- with .Values.extraLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels (must be stable across template renders).
*/}}
{{- define "shortlink.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for the API workload.
*/}}
{{- define "shortlink.apiSelectorLabels" -}}
{{ include "shortlink.selectorLabels" . }}
app.kubernetes.io/component: api
{{- end }}

{{/*
Selector labels for the Web workload.
*/}}
{{- define "shortlink.webSelectorLabels" -}}
{{ include "shortlink.selectorLabels" . }}
app.kubernetes.io/component: web
{{- end }}

{{/*
Common annotations (Prometheus scraping for non-ServiceMonitor setups).
*/}}
{{- define "shortlink.podAnnotations" -}}
prometheus.io/scrape: "false"
{{- end }}
