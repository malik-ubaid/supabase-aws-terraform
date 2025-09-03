{{/*
Expand the name of the chart.
*/}}
{{- define "supabase.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "supabase.fullname" -}}
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
{{- define "supabase.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "supabase.labels" -}}
helm.sh/chart: {{ include "supabase.chart" . }}
{{ include "supabase.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "supabase.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "supabase.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "supabase.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database URL helper
*/}}
{{- define "supabase.databaseUrl" -}}
{{- if .Values.database.external }}
postgresql://{{ .Values.database.user }}:$(DB_PASSWORD)@{{ .Values.database.host }}:{{ .Values.database.port }}/{{ .Values.database.name }}
{{- else }}
postgresql://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)
{{- end }}
{{- end }}

{{/*
Kong service name
*/}}
{{- define "supabase.kong.fullname" -}}
{{- printf "%s-kong" (include "supabase.fullname" .) }}
{{- end }}

{{/*
PostgREST service name
*/}}
{{- define "supabase.postgrest.fullname" -}}
{{- printf "%s-postgrest" (include "supabase.fullname" .) }}
{{- end }}

{{/*
Realtime service name
*/}}
{{- define "supabase.realtime.fullname" -}}
{{- printf "%s-realtime" (include "supabase.fullname" .) }}
{{- end }}

{{/*
Auth service name
*/}}
{{- define "supabase.auth.fullname" -}}
{{- printf "%s-auth" (include "supabase.fullname" .) }}
{{- end }}

{{/*
Storage service name
*/}}
{{- define "supabase.storage.fullname" -}}
{{- printf "%s-storage" (include "supabase.fullname" .) }}
{{- end }}

{{/*
Dashboard service name
*/}}
{{- define "supabase.dashboard.fullname" -}}
{{- printf "%s-dashboard" (include "supabase.fullname" .) }}
{{- end }}