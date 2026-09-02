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
MongoDB connection URI. In replica-set mode a full mongodb:// URI with all three
member seeds is returned so the Java driver discovers the primary automatically.
In standalone mode only the single host URI is returned.
*/}}
{{- define "helmut4.mongodb.host" -}}
{{- $name := .Values.mongodb.fullnameOverride | default "mongodb" }}
{{- $ns   := .Values.namespace }}
{{- if .Values.mongodb.replicaSet.enabled }}
{{- printf "%s-0.%s-headless.%s.svc.cluster.local" $name $name $ns }}
{{- else }}
{{- printf "%s.%s.svc.cluster.local" $name $ns }}
{{- end }}
{{- end }}

{{/*
Full MongoDB connection URI used for SPRING_DATA_MONGODB_URI.
In replica-set mode all three seeds plus replicaSet= and authSource= are included
so the Java driver enters REPLICA_SET topology mode and finds the primary.
*/}}
{{- define "helmut4.mongodb.uri" -}}
{{- $name := .Values.mongodb.fullnameOverride | default "mongodb" }}
{{- $ns   := .Values.namespace }}
{{- $db   := .Values.mongodb.database | default "helmut4" }}
{{- if .Values.mongodb.replicaSet.enabled }}
{{- printf "mongodb://%s-0.%s-headless.%s.svc.cluster.local:27017,%s-1.%s-headless.%s.svc.cluster.local:27017,%s-2.%s-headless.%s.svc.cluster.local:27017/%s?replicaSet=%s&authSource=admin" $name $name $ns $name $name $ns $name $name $ns $db .Values.mongodb.replicaSet.name }}
{{- else }}
{{- printf "mongodb://%s.%s.svc.cluster.local:27017/%s?authSource=admin" $name $ns $db }}
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
Secret holding the Helmut admin credentials the Linux client initContainer uses
*/}}
{{- define "helmut4.linuxClient.adminSecretName" -}}
{{- .Values.linuxClients.adminCredentials.existingSecret | default "helmut4-client-admin" }}
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

{{/*
Fail the render when a credential that deliberately has no default is empty.
Keeps blank passwords out of the cluster instead of silently deploying them.
*/}}
{{- define "helmut4.validateCredentials" -}}
{{- $hint := "set it in your gitignored secrets values file (see install-values.yaml)" -}}
{{- if .Values.mongodb.enabled -}}
{{- if not .Values.mongodb.auth.existingSecret -}}
{{- $_ := required (printf "mongodb.auth.rootPassword is required; %s" $hint) .Values.mongodb.auth.rootPassword -}}
{{- end -}}
{{- if .Values.mongodb.replicaSet.enabled -}}
{{- $_ := required (printf "mongodb.replicaSet.key is required; %s" $hint) .Values.mongodb.replicaSet.key -}}
{{- end -}}
{{- end -}}
{{- $_ := required (printf "rabbitmq.auth.password is required; %s" $hint) .Values.rabbitmq.auth.password -}}
{{- $_ := required (printf "rabbitmq.auth.erlangCookie is required; %s" $hint) .Values.rabbitmq.auth.erlangCookie -}}
{{- end }}
