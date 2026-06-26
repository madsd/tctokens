param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AppInsightsName,

    [Parameter(Mandatory = $false)]
    [int]$Days = 14
)

$ErrorActionPreference = 'Stop'

if ($Days -lt 1) {
    throw "Days must be at least 1."
}

# Application Insights Metric ingestion accepts only recent timestamps (roughly last 48 hours).
if ($Days -gt 2) {
    Write-Warning "Days=$Days exceeds Application Insights metric backfill window; capping to 2 days."
    $Days = 2
}

$appInsights = az monitor app-insights component show `
    --resource-group $ResourceGroupName `
    --app $AppInsightsName | ConvertFrom-Json

if (-not $appInsights.connectionString) {
    throw "Application Insights connection string not found for '$AppInsightsName'."
}

$connParts = @{}
foreach ($part in ($appInsights.connectionString -split ';')) {
    if ($part -match '=') {
        $pair = $part -split '=', 2
        $connParts[$pair[0]] = $pair[1]
    }
}

$instrumentationKey = $connParts['InstrumentationKey']
$ingestionEndpoint = $connParts['IngestionEndpoint']

if ([string]::IsNullOrWhiteSpace($instrumentationKey) -or [string]::IsNullOrWhiteSpace($ingestionEndpoint)) {
    throw "Could not parse InstrumentationKey/IngestionEndpoint from connection string."
}

$trackUrl = "$($ingestionEndpoint.TrimEnd('/'))/v2/track"

# Keep fake traffic scoped to two existing APIM subscriptions.
$subscriptionUsers = @(
    @{ SubscriptionId = 'user01-subscription'; UserId = 'user01' },
    @{ SubscriptionId = 'user02-subscription'; UserId = 'user02' }
)

$modelProfiles = @(
    @{
        Name = 'gpt-5.4'
        ReasoningEffort = 'high'
        PromptBase = 1600000.0
        CachedBase = 550000.0
        CompletionBase = 280000.0
    },
    @{
        Name = 'gpt-5.4-mini'
        ReasoningEffort = 'medium'
        PromptBase = 1200000.0
        CachedBase = 420000.0
        CompletionBase = 220000.0
    },
    @{
        Name = 'gpt-5.4-nano'
        ReasoningEffort = 'low'
        PromptBase = 900000.0
        CachedBase = 350000.0
        CompletionBase = 180000.0
    }
)

$routerTargets = @('gpt-5.4', 'gpt-5.4-mini', 'gpt-5.4-nano')

function New-MetricEnvelope {
    param(
        [string]$MetricName,
        [double]$MetricValue,
        [datetime]$TimeUtc,
        [hashtable]$Properties,
        [string]$IKey
    )

    return @{
        name = 'Microsoft.ApplicationInsights.Metric'
        time = $TimeUtc.ToString('o')
        iKey = $IKey
        tags = @{
            'ai.cloud.role' = 'apim-gateway-synthetic'
            'ai.operation.id' = [guid]::NewGuid().Guid
        }
        data = @{
            baseType = 'MetricData'
            baseData = @{
                ver = 2
                metrics = @(
                    @{
                        name = $MetricName
                        value = $MetricValue
                    }
                )
                properties = $Properties
            }
        }
    }
}

$events = New-Object System.Collections.Generic.List[object]

for ($dayOffset = $Days - 1; $dayOffset -ge 0; $dayOffset--) {
    $sampleTimeUtc = (Get-Date).ToUniversalTime().Date.AddDays(-$dayOffset).AddHours(9)
    $routerSelected = $routerTargets[$dayOffset % $routerTargets.Count]

    foreach ($sub in $subscriptionUsers) {
        foreach ($profile in $modelProfiles) {
            $jitter = 1.0 + ((Get-Random -Minimum -12 -Maximum 13) / 100.0)
            $promptTokens = [math]::Round($profile.PromptBase * $jitter, 0)
            $cachedTokens = [math]::Round($profile.CachedBase * $jitter, 0)
            $completionTokens = [math]::Round($profile.CompletionBase * $jitter, 0)
            $totalTokens = $promptTokens + $completionTokens

            $requestedModel = $profile.Name
            $selectedModel = $profile.Name

            # Simulate router requests for gpt-5.4 profile so router charts are populated.
            if ($profile.Name -eq 'gpt-5.4') {
                $requestedModel = 'router'
                $selectedModel = $routerSelected
            }

            $dims = @{
                'Subscription ID' = $sub.SubscriptionId
                'User ID' = $sub.UserId
                'Model' = $selectedModel
                'RequestedModel' = $requestedModel
                'SelectedModel' = $selectedModel
                'ReasoningEffort' = $profile.ReasoningEffort
                'SyntheticData' = 'true'
            }

            $events.Add((New-MetricEnvelope -MetricName 'Prompt Tokens' -MetricValue $promptTokens -TimeUtc $sampleTimeUtc -Properties $dims -IKey $instrumentationKey))
            $events.Add((New-MetricEnvelope -MetricName 'Prompt Cached Tokens' -MetricValue $cachedTokens -TimeUtc $sampleTimeUtc -Properties $dims -IKey $instrumentationKey))
            $events.Add((New-MetricEnvelope -MetricName 'Completion Tokens' -MetricValue $completionTokens -TimeUtc $sampleTimeUtc -Properties $dims -IKey $instrumentationKey))
            $events.Add((New-MetricEnvelope -MetricName 'Total Tokens' -MetricValue $totalTokens -TimeUtc $sampleTimeUtc -Properties $dims -IKey $instrumentationKey))
        }
    }
}

$chunkSize = 100
$acceptedTotal = 0
for ($start = 0; $start -lt $events.Count; $start += $chunkSize) {
    $end = [Math]::Min($start + $chunkSize - 1, $events.Count - 1)
    $batch = @($events[$start..$end])
    $payload = $batch | ConvertTo-Json -Depth 15
    $response = Invoke-RestMethod -Method Post -Uri $trackUrl -ContentType 'application/json' -Body $payload
    $acceptedTotal += [int]$response.itemsAccepted
    if ([int]$response.itemsAccepted -lt $batch.Count) {
        $errorMessage = ($response.errors | Select-Object -First 3 | ConvertTo-Json -Compress)
        throw "Ingestion partial failure: accepted $($response.itemsAccepted)/$($batch.Count). Errors: $errorMessage"
    }
}

Write-Host "Sent $($events.Count) synthetic metric envelopes to $AppInsightsName (accepted: $acceptedTotal)."
Write-Host "Dimensions used Subscription ID values: user01-subscription, user02-subscription."
Write-Host "Synthetic data marker: customDimensions['SyntheticData'] = true"
