# SSL / cert-manager troubleshooting

## Problem: certificate issuance stuck (self-check failed)

If certificates stay in `Pending` and the challenge reports something like:

```
Reason: Waiting for HTTP-01 challenge propagation: failed to perform self
check GET request ... context deadline exceeded
```

### Cause

Before delegating validation to Let's Encrypt, `cert-manager` runs a
"self-check" — it tries to reach the public hostname (e.g.
`helmut-k8s.example.com`) **from inside the cluster**.

On many on-premise or homelab setups (e.g. Rancher running on a few VMs),
**NAT loopback** doesn't work: a pod resolving the public IP of the
cluster's own hostname can't actually route to it. The self-check times
out and the issuance never starts.

### Fix: `hostAliases` patch

Instead of disabling the self-check (the flag for that has moved several
times across cert-manager versions and tends to break on upgrades), force
cert-manager to resolve the hostname **locally** to the ingress
controller / node IP. A `hostAliases` entry on the cert-manager Deployment
does exactly that.

#### 1. Find the ingress / node IP

```bash
# Whichever address the ingress controller listens on:
kubectl get svc -n kube-system | grep ingress
# …or, if the controller binds the node IP directly:
kubectl get nodes -o wide
```

#### 2. Patch cert-manager

Replace `<NODE_IP>` with the IP from step 1 and list every hostname you
issue certificates for. The patch **replaces** any existing `hostAliases`
entry, so include all of them in a single patch:

```bash
kubectl patch deployment cert-manager -n cert-manager \
  --type='json' \
  -p='[{
    "op": "replace",
    "path": "/spec/template/spec/hostAliases",
    "value": [
      {
        "ip": "<NODE_IP>",
        "hostnames": [
          "helmut-k8s.example.com",
          "<other-host>.example.com"
        ]
      }
    ]
  }]'
```

#### 3. Re-issue the certificate

Delete the stuck Certificate object so cert-manager starts a fresh
issuance:

```bash
kubectl delete certificate helmut4-tls -n helmut4
```

### Verify

```bash
kubectl get certificate -n helmut4
```

The `READY` column should flip to `True` within a minute or two.
