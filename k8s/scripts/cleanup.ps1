param(
    [switch]$RemoveData,
    [switch]$RemoveObservability,
    [switch]$RemoveCaddy
)

$ErrorActionPreference = "Continue"

kubectl delete job -n martianbank-app martianbank-locust --ignore-not-found=true
kubectl delete namespace martianbank-app --ignore-not-found=true

if ($RemoveData) {
    kubectl delete namespace martianbank-data --ignore-not-found=true
} else {
    Write-Warning "Data namespace not removed. Use -RemoveData only when you intentionally want to delete MongoDB pods and PVCs."
}

if ($RemoveObservability) {
    kubectl delete namespace martianbank-observability --ignore-not-found=true
}

if ($RemoveCaddy) {
    helm uninstall caddy-ingress-controller -n caddy-system
    kubectl delete namespace caddy-system --ignore-not-found=true
}

Write-Host "Cleanup requested. Check the Scaleway console for remaining Load Balancers, public IPs, registry images, PVC-backed volumes, snapshots, and cluster resources."
