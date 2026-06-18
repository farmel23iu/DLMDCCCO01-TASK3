param(
    [string]$RegistryEndpoint = "rg.fr-par.scw.cloud/registry-dlmdccco01-dev",
    [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command trivy -ErrorAction SilentlyContinue)) {
    throw "Trivy is not installed or not on PATH. Install Trivy or run the GitHub Actions scan."
}

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Images = @(
    "martian-bank-demo-ui",
    "martian-bank-demo-nginx",
    "martian-bank-demo-customer-auth",
    "martian-bank-demo-atm-locator",
    "martian-bank-demo-dashboard",
    "martian-bank-demo-accounts",
    "martian-bank-demo-transactions",
    "martian-bank-demo-loan",
    "martian-bank-demo-locust"
)

foreach ($Image in $Images) {
    $FullImage = "$RegistryEndpoint/$Image`:$ImageTag"
    trivy image --severity HIGH,CRITICAL --ignore-unfixed $FullImage
}

trivy config (Join-Path $RepoRoot "k8s")
