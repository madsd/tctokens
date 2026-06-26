param(
    [Parameter(Mandatory = $true)]
    [string]$ApimName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName
)

$ErrorActionPreference = 'Stop'

$subscriptionNames = az apim subscription list `
    --service-name $ApimName `
    --resource-group $ResourceGroupName `
    --query "[?ends_with(name, '-subscription')].name" `
    -o tsv

if (-not $subscriptionNames) {
    throw "No APIM subscriptions ending with '-subscription' were found in '$ApimName'."
}

$rows = @()
foreach ($subscriptionName in ($subscriptionNames -split "`r?`n" | Where-Object { $_ })) {
    $keysJson = az apim subscription keys list `
        --service-name $ApimName `
        --resource-group $ResourceGroupName `
        --sid $subscriptionName

    $keys = $keysJson | ConvertFrom-Json
    $rows += [PSCustomObject]@{
        SubscriptionName = $subscriptionName
        PrimaryKey = $keys.primaryKey
        SecondaryKey = $keys.secondaryKey
    }
}

$rows | Sort-Object SubscriptionName | Format-Table -AutoSize

