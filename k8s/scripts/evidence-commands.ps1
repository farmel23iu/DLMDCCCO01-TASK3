param(
    [string]$AppNamespace = "martianbank-app",
    [string]$DataNamespace = "martianbank-data"
)

$ErrorActionPreference = "Continue"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$EvidenceDir = Join-Path $RepoRoot ("evidence\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

function Save-Command {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    $Path = Join-Path $EvidenceDir $Name
    "### $Name" | Tee-Object -FilePath $Path
    & $Command 2>&1 | Tee-Object -FilePath $Path -Append
}

Save-Command "kubectl-get-nodes.txt" { kubectl get nodes -o wide }
Save-Command "kubectl-get-storageclass.txt" { kubectl get storageclass }
Save-Command "kubectl-get-namespaces.txt" { kubectl get namespaces }
Save-Command "kubectl-get-pods-caddy.txt" { kubectl get pods -n caddy-system -o wide }
Save-Command "kubectl-get-svc-caddy.txt" { kubectl get svc -n caddy-system }
Save-Command "kubectl-get-pods-app.txt" { kubectl get pods -n $AppNamespace -o wide }
Save-Command "kubectl-get-svc-app.txt" { kubectl get svc -n $AppNamespace }
Save-Command "kubectl-get-ingress-app.txt" { kubectl get ingress -n $AppNamespace }
Save-Command "kubectl-describe-ingress-app.txt" { kubectl describe ingress -n $AppNamespace martianbank }
Save-Command "kubectl-get-hpa-app.txt" { kubectl get hpa -n $AppNamespace }
Save-Command "kubectl-get-pods-data.txt" { kubectl get pods -n $DataNamespace -o wide }
Save-Command "kubectl-get-svc-data.txt" { kubectl get svc -n $DataNamespace }
Save-Command "kubectl-get-statefulset-data.txt" { kubectl get statefulset -n $DataNamespace }
Save-Command "kubectl-get-pvc-data.txt" { kubectl get pvc -n $DataNamespace }
Save-Command "kubectl-get-cronjob-data.txt" { kubectl get cronjob -n $DataNamespace }
Save-Command "kubectl-get-networkpolicy-app.txt" { kubectl get networkpolicy -n $AppNamespace -o wide }
Save-Command "kubectl-get-networkpolicy-data.txt" { kubectl get networkpolicy -n $DataNamespace -o wide }
Save-Command "kubectl-get-rbac-app.txt" { kubectl get serviceaccount,role,rolebinding -n $AppNamespace }
Save-Command "kubectl-get-rbac-data.txt" { kubectl get serviceaccount,role,rolebinding -n $DataNamespace }
Save-Command "kubectl-top-nodes.txt" { kubectl top nodes }
Save-Command "kubectl-top-pods-app.txt" { kubectl top pods -n $AppNamespace }
Save-Command "kubectl-top-pods-data.txt" { kubectl top pods -n $DataNamespace }
Save-Command "caddy-logs.txt" { kubectl logs -n caddy-system deploy/caddy-ingress-controller --tail=200 }
Save-Command "nginx-logs.txt" { kubectl logs -n $AppNamespace deploy/nginx --tail=200 }
Save-Command "customer-auth-logs.txt" { kubectl logs -n $AppNamespace deploy/customer-auth --tail=200 }
Save-Command "dashboard-logs.txt" { kubectl logs -n $AppNamespace deploy/dashboard --tail=200 }
Save-Command "mongodb-logs.txt" { kubectl logs -n $DataNamespace statefulset/mongodb --tail=200 }
Save-Command "dns-nslookup.txt" { nslookup martianbank.iu-labs.de }
Save-Command "http-head.txt" { curl.exe -I http://martianbank.iu-labs.de }
Save-Command "https-head.txt" { curl.exe -Ik https://martianbank.iu-labs.de }

Write-Host "Evidence written to $EvidenceDir"
