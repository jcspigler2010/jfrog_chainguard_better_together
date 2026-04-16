{{/* Full image ref for a tier, honoring the flavor toggle. */}}
{{- define "demoapp.image" -}}
{{- $root := index . 0 -}}
{{- $tier := index . 1 -}}
{{- $repo := $tier.image.repository -}}
{{- $tag  := $tier.image.tag | default $root.Values.flavor -}}
{{- printf "%s/%s/%s:%s" $root.Values.registry.host $root.Values.registry.repo $repo $tag -}}
{{- end -}}

{{- define "demoapp.postgresImage" -}}
{{- if eq .Values.flavor "chainguard" -}}
{{ .Values.postgres.chainguardImage }}
{{- else -}}
{{ .Values.postgres.image }}
{{- end -}}
{{- end -}}

{{- define "demoapp.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: secure-image-catalog
image.flavor: {{ .Values.flavor }}
{{- end -}}
