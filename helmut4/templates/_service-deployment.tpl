{{- define "service.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "service.name" . }}
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "helmut4.labels" . | nindent 4 }}
    app: {{ include "service.name" . }}
spec:
  replicas: {{ .replicas | default .Values.serviceReplicas }}
  selector:
    matchLabels:
      app: {{ include "service.name" . }}
  template:
    metadata:
      labels:
        app: {{ include "service.name" . }}
        {{- include "helmut4.labels" . | nindent 8 }}
    spec:
      {{- if .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml .Values.global.imagePullSecrets | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "helmut4.serviceAccountName" . }}
      
      containers:
        - name: {{ include "service.name" . }}
          image: "{{ include "helmut4.image" .image }}:{{ .imageTag }}"
          imagePullPolicy: {{ .Values.global.imagePullPolicy }}
          {{- if .port }}
          ports:
            - containerPort: {{ .port }}
              name: http
              protocol: TCP
          {{- end }}
          
          env:
            - name: parameters
              value: |
                --spring.data.mongodb.host=mongodb-0.mongodb-headless
                --spring.data.mongodb.port=27017
                --spring.rabbitmq.host=rabbitmq-0.rabbitmq-headless
                --spring.rabbitmq.port=5672
                --spring.elasticsearch.rest.uris=http://elasticsearch:9200
                --spring.elasticsearch.rest.timeout=2000
                --mcc.fx.url=http://fx:{{ .Values.services.fx.port }}/v1/fx
                --mcc.co.url=http://co:{{ .Values.services.co.port }}/v1/co
                --mcc.io.url=http://io:{{ .Values.services.io.port }}/v1/io
                --mcc.hk.url=http://hk:{{ .Values.services.hk.port }}/v1/hk
                --mcc.users.url=http://users:{{ .Values.services.users.port }}/v1/members
                --mcc.stream.url=http://streams:{{ .Values.services.streams.port }}/v1/streams
                --mcc.preference.url=http://preferences:{{ .Values.services.preferences.port }}/v1/preferences
                --mcc.metadata.url=http://metadata:{{ .Values.services.metadata.port }}/v1/metadata
                --mcc.logging.url=http://logging:{{ .Values.services.logging.port }}/v1/logging/helmut
                --mcc.amqp.url=http://amqp:{{ .Values.services.amqp.port }}/v1/amqp/send
                --mcc.license.url=http://license:{{ .Values.services.license.port }}/v1/license
                --mcc.language.url=http://language:{{ .Values.services.language.port }}/v1/language
          
          resources:
            {{- toYaml .resources | nindent 12 }}
          
          {{- if .port }}
          livenessProbe:
            httpGet:
              path: /health
              port: {{ .port }}
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          
          readinessProbe:
            httpGet:
              path: /health
              port: {{ .port }}
            initialDelaySeconds: 30
            periodSeconds: 5
            timeoutSeconds: 5
            failureThreshold: 3
          {{- end }}
          
          {{- if .volumeMounts }}
          volumeMounts:
            - name: helmut-storage
              mountPath: /Users/Shared/Helmut24
          {{- end }}
      
      {{- if .volumeMounts }}
      volumes:
        - name: helmut-storage
          persistentVolumeClaim:
            claimName: helmut-storage-pvc
      {{- end }}
{{- end }}
