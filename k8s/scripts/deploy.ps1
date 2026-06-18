param(
    [string]$TargetDomain = "martianbank.iu-labs.de",
    [string]$AppNamespace = "martianbank-app",
    [string]$DataNamespace = "martianbank-data",
    [switch]$InstallCaddy,
    [string]$CaddyEmail = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $RepoRoot

try {
    kubectl apply -f k8s/namespaces/namespaces.yaml

    if ($InstallCaddy) {
        if ([string]::IsNullOrWhiteSpace($CaddyEmail)) {
            throw "Provide -CaddyEmail when using -InstallCaddy."
        }

        helm repo add caddy-ingress https://caddyserver.github.io/ingress/ | Out-Host
        helm repo update | Out-Host
        helm upgrade --install caddy-ingress-controller caddy-ingress/caddy-ingress-controller `
            --namespace caddy-system `
            --values k8s/caddy/caddy-ingress-values.yaml `
            --set "ingressController.config.email=$CaddyEmail"
    }

    kubectl apply -f k8s/security/rbac.yaml

    $AppSecretFile = "k8s/app/secrets.local.yaml"
    if (Test-Path $AppSecretFile) {
        kubectl apply -f $AppSecretFile
    } else {
        Write-Warning "Missing $AppSecretFile. Copy k8s/app/secrets.example.yaml to secrets.local.yaml and replace placeholders."
    }

    $DbSecretFile = "k8s/data/mongodb-secret.local.yaml"
    if (Test-Path $DbSecretFile) {
        kubectl apply -f $DbSecretFile
    } else {
        Write-Warning "Missing $DbSecretFile. Copy k8s/data/mongodb-secret.example.yaml to mongodb-secret.local.yaml and replace placeholders."
    }

    kubectl apply -f k8s/data/mongodb-service.yaml
    kubectl apply -f k8s/data/mongodb-statefulset.yaml
    kubectl apply -f k8s/data/mongodb-backup-cronjob.yaml
    kubectl -n $DataNamespace rollout status statefulset/mongodb --timeout=240s

    kubectl apply -f k8s/app/configmap.yaml
    kubectl apply -f k8s/app/services.yaml
    kubectl apply -f k8s/app/deployments.yaml
    kubectl apply -f k8s/app/ingress.yaml
    kubectl apply -f k8s/app/hpa.yaml
    kubectl apply -f k8s/security/networkpolicy-app.yaml
    kubectl apply -f k8s/security/networkpolicy-app-to-db.yaml

    $Patch = "[{`"op`":`"replace`",`"path`":`"/spec/rules/0/host`",`"value`":`"$TargetDomain`"}]"
    kubectl -n $AppNamespace patch ingress martianbank --type=json -p $Patch

    kubectl -n $AppNamespace rollout status deploy/ui --timeout=180s
    kubectl -n $AppNamespace rollout status deploy/nginx --timeout=180s
    kubectl -n $AppNamespace rollout status deploy/customer-auth --timeout=180s
    kubectl -n $AppNamespace rollout status deploy/atm-locator --timeout=180s
    kubectl -n $AppNamespace rollout status deploy/dashboard --timeout=180s
    kubectl -n $AppNamespace rollout status deploy/accounts --timeout=180s
    kubectl -n $AppNamespace rollout status deploy/transactions --timeout=180s
    kubectl -n $AppNamespace rollout status deploy/loan --timeout=180s

    kubectl get pods -n $AppNamespace -o wide
    kubectl get svc -n $AppNamespace
    kubectl get ingress -n $AppNamespace
    kubectl get pods -n $DataNamespace -o wide
    kubectl get pvc -n $DataNamespace
    kubectl get cronjob -n $DataNamespace
}
finally {
    Pop-Location
}
