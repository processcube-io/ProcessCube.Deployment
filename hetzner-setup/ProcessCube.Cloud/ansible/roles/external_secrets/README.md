# External Secrets Operator Role

Diese Ansible-Rolle installiert den External Secrets Operator (Version 1.1.0) und konfiguriert die Integration mit 1Password Connect.

## Voraussetzungen

- Funktionierender K3s Cluster
- Helm installiert auf dem Master Node
- 1Password Connect Credentials JSON Datei

## Konfiguration

Die Konfiguration erfolgt über Terraform-Variablen, die automatisch an Ansible übergeben werden.

### 1. 1Password Connect Credentials vorbereiten

Lade die `1password-credentials.json` Datei von 1Password herunter und speichere sie lokal.

### 2. Terraform-Variablen setzen

Setze folgende Variablen in `terraform.tfvars`:

```hcl
# 1Password Connect Configuration
onepassword_credentials_json = "/path/to/1password-credentials.json"
```

Diese Variable wird automatisch von Terraform an das Ansible-Inventory übergeben.

**Wichtig:** Das `onepassword-connect-token` Secret wird NICHT global installiert, sondern muss pro Applikations-Namespace erstellt werden (siehe "Nach der Installation").

### 3. Optional: Versionen überschreiben

Falls notwendig, kannst du die Versionen in `roles/external_secrets/defaults/main.yml` anpassen:

```yaml
external_secrets_version: "1.1.0"
onepassword_connect_version: "2.0.5"
```

## Verwendung

Die Rolle wird automatisch beim Ausführen von `site.yml` installiert:

```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

Um nur die External Secrets Operator Installation auszuführen:

```bash
ansible-playbook -i inventory/hosts.yml site.yml --tags external_secrets
```

## Was wird installiert?

1. **External Secrets Operator** (v1.1.0)
   - Installiert via Helm Chart
   - Namespace: `external-secrets`

2. **1Password Connect**
   - Installiert via Helm Chart (v2.0.5, App v1.8.1)
   - Konfiguriert mit den bereitgestellten Credentials
   - Verbindet sich mit dem External Secrets Operator

## Nach der Installation

### 1. onepassword-connect-token Secret pro Namespace erstellen

Für jede Applikation/Namespace muss ein eigenes Token-Secret erstellt werden:

```bash
kubectl create secret generic onepassword-connect-token \
  -n <your-namespace> \
  --from-literal=token='<your-1password-connect-token>'
```

### 2. SecretStore erstellen

Nach dem Erstellen des Token-Secrets kannst du einen SecretStore erstellen:

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: processcube-ug
spec:
  provider:
    onepassword:
      connectHost: http://onepassword-connect.external-secrets.svc.cluster.local:8080
      vaults:
        "ProcessCube.UG": 1
      auth:
        secretRef:
          connectTokenSecretRef:
            name: onepassword-connect-token
            key: token
```

## Fehlerbehebung

### Pods prüfen
```bash
kubectl get pods -n external-secrets
```

### Logs prüfen
```bash
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
kubectl logs -n external-secrets -l app.kubernetes.io/name=connect
```

### SecretStore Status prüfen
```bash
kubectl get secretstore -A
kubectl describe secretstore processcube-ug -n <namespace>
```
