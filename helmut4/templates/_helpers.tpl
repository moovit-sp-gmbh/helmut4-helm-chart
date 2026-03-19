{{/*
Expand the name of the chart.
*/}}
{{- define "helmut4.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "helmut4.fullname" -}}
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
{{- define "helmut4.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "helmut4.labels" -}}
helm.sh/chart: {{ include "helmut4.chart" . }}
{{ include "helmut4.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "helmut4.selectorLabels" -}}
app.kubernetes.io/name: {{ include "helmut4.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "helmut4.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "helmut4.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
MongoDB headless host (FQDN)
*/}}
{{- define "helmut4.mongodb.host" -}}
{{- if .Values.mongodb.replicaSet.enabled }}
{{- printf "%s-headless.%s.svc.cluster.local" (.Values.mongodb.fullnameOverride | default "mongodb") .Values.namespace }}
{{- else }}
{{- printf "%s.%s.svc.cluster.local" (.Values.mongodb.fullnameOverride | default "mongodb") .Values.namespace }}
{{- end }}
{{- end }}

{{/*
RabbitMQ host (pod-0 of headless service, FQDN)
*/}}
{{- define "helmut4.rabbitmq.host" -}}
{{- $name := .Values.rabbitmq.fullnameOverride | default "rabbitmq" }}
{{- printf "%s-0.%s-headless.%s.svc.cluster.local" $name $name .Values.namespace }}
{{- end }}

{{/*
MongoDB credentials secret name
*/}}
{{- define "helmut4.mongodb.secretName" -}}
{{- if .Values.mongodb.auth.existingSecret -}}
{{- .Values.mongodb.auth.existingSecret }}
{{- else -}}
mongodb-credentials
{{- end }}
{{- end }}

{{/*
MongoDB credentials username key
*/}}
{{- define "helmut4.mongodb.usernameKey" -}}
{{- if .Values.mongodb.auth.existingSecret -}}
{{- .Values.mongodb.auth.existingUsernameKey | default "username" }}
{{- else -}}
username
{{- end }}
{{- end }}

{{/*
MongoDB credentials password key
*/}}
{{- define "helmut4.mongodb.passwordKey" -}}
{{- if .Values.mongodb.auth.existingSecret -}}
{{- .Values.mongodb.auth.existingPasswordKey | default "mongodb-root-password" }}
{{- else -}}
password
{{- end }}
{{- end }}
