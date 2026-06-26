param(
    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $false)]
    [string]$AzdEnvironment = 'tctokens',

    [Parameter(Mandatory = $false)]
    [string]$RouterModelName = 'model-router'
)

$ErrorActionPreference = 'Stop'

function Get-LatestModelVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModelName
    )

    $query = "[?model.name=='$ModelName'].model.version"
    $versionsRaw = az cognitiveservices model list --location $Location --query $query -o tsv
    if (-not $versionsRaw) {
        throw "No versions found for model '$ModelName' in location '$Location'."
    }

    $versions = $versionsRaw -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object
    return $versions[-1]
}

Write-Host "Selecting azd environment '$AzdEnvironment'..."
azd env select $AzdEnvironment | Out-Null

Write-Host "Resolving latest available model versions in '$Location'..."
$gpt54Version = Get-LatestModelVersion -ModelName 'gpt-5.4'
$gpt54MiniVersion = Get-LatestModelVersion -ModelName 'gpt-5.4-mini'
$gpt54NanoVersion = Get-LatestModelVersion -ModelName 'gpt-5.4-nano'
$routerVersion = Get-LatestModelVersion -ModelName $RouterModelName

Write-Host 'Setting azd environment variables...'
azd env set AZURE_LOCATION $Location | Out-Null
azd env set GPT54_MODEL_VERSION $gpt54Version | Out-Null
azd env set GPT54_MINI_MODEL_VERSION $gpt54MiniVersion | Out-Null
azd env set GPT54_NANO_MODEL_VERSION $gpt54NanoVersion | Out-Null
azd env set ROUTER_MODEL_NAME $RouterModelName | Out-Null
azd env set ROUTER_MODEL_VERSION $routerVersion | Out-Null

Write-Host ''
Write-Host 'Configured model versions:'
Write-Host "  GPT54_MODEL_VERSION      = $gpt54Version"
Write-Host "  GPT54_MINI_MODEL_VERSION = $gpt54MiniVersion"
Write-Host "  GPT54_NANO_MODEL_VERSION = $gpt54NanoVersion"
Write-Host "  ROUTER_MODEL_NAME        = $RouterModelName"
Write-Host "  ROUTER_MODEL_VERSION     = $routerVersion"
Write-Host ''
Write-Host 'Next: run `azd up`.'

