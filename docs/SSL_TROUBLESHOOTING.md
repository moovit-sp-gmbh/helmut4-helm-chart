# SSL / Cert-Manager Troubleshooting

## Problem: Certificate Issuance Stuck (Self-Check Failed)

Wenn Zertifikate im Status `Pending` hängen bleiben und die Challenge folgenden Fehler zeigt:

```
Reason: Waiting for HTTP-01 challenge propagation: failed to perform self check GET request ... context deadline exceeded
```

### Ursache
Der `cert-manager` versucht vor der eigentlichen Validierung durch Let's Encrypt einen "Self-Check". Er ruft die Domain (z.B. `hc-uploader-test.moovit24.de`, `helmut-k8s.moovit24.de`) von innerhalb des Clusters auf.
In vielen On-Premise oder lokalen Setups (wie Rancher auf VMs) funktioniert **NAT Loopback** nicht korrekt. Das heißt, der Pod kann die öffentliche IP der Domain nicht erreichen.

### Lösung: HostAlias Patch

Anstatt den Self-Check zu deaktivieren (was oft zu Abstürzen führt, da Flags veraltet sind), zwingen wir den `cert-manager`, die Domain lokal aufzulösen.

Wir fügen einen `hostAlias` zum `cert-manager` Deployment hinzu, der die Domain auf die interne IP des Ingress-Controllers (oder die Node-IP) mappt.

#### 1. Ingress IP / Node IP finden
Finde heraus, auf welcher IP der Ingress-Controller lauscht:
```bash
kubectl get svc -n kube-system | grep ingress
# oder
kubectl get nodes -o wide
```
(In diesem Fall war es die Node-IP `10.10.10.46`).

#### 2. Cert-Manager patchen
Führe folgenden Befehl aus, um das Mapping hinzuzufügen (ersetze IP und Domain):

```bash
kubectl patch deployment cert-manager -n cert-manager --type='json' -p='[{"op": "add", "path": "/spec/template/spec/hostAliases", "value": [{"ip": "10.10.10.46", "hostnames": ["hc-uploader-test.moovit24.de", "helmut-k8s.moovit24.de"]}]}]'
```

#### 3. Zertifikat neu anfordern
Lösche das hängende Zertifikat, damit der Prozess neu startet:

```bash
kubectl delete certificate hc-video-server-tls -n moovit
```

### Überprüfung
```bash
kubectl get certificate -n moovit
```
Der Status sollte nach kurzer Zeit auf `True` wechseln.
