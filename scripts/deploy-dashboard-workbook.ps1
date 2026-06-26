param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AppInsightsName,

    [Parameter(Mandatory = $false)]
    [string]$DisplayName = 'Total Cost of Tokens Dashboard'
)

$ErrorActionPreference = 'Stop'

$appInsights = az monitor app-insights component show `
    --resource-group $ResourceGroupName `
    --app $AppInsightsName | ConvertFrom-Json

if (-not $appInsights.id) {
    throw "Application Insights '$AppInsightsName' was not found in '$ResourceGroupName'."
}

$monthlySpendQuery = @'
let ModelPricing = datatable(Model:string, InputPricePer1MUsd:real, CachedInputPricePer1MUsd:real, OutputPricePer1MUsd:real)
[
    "gpt-5.4", 2.50, 0.25, 15.00,
    "gpt-5.4-mini", 0.75, 0.075, 4.50,
    "gpt-5.4-nano", 0.20, 0.025, 1.25
];
let TokenMetrics = customMetrics
| where timestamp > ago(180d)
| where name in ("Prompt Tokens", "Completion Tokens", "Prompt Cached Tokens", "Cached Prompt Tokens", "Cached Tokens")
| extend Model = coalesce(tostring(customDimensions["SelectedModel"]), tostring(customDimensions["Model"]))
| where isnotempty(Model)
| summarize
    PromptTokens = sumif(value, name == "Prompt Tokens"),
    CompletionTokens = sumif(value, name == "Completion Tokens"),
    CachedInputTokens = sumif(value, name in ("Prompt Cached Tokens", "Cached Prompt Tokens", "Cached Tokens"))
  by Month = startofmonth(timestamp), Model;
TokenMetrics
| join kind=leftouter ModelPricing on Model
| extend UncachedInputTokens = max_of(PromptTokens - CachedInputTokens, 0.0)
| extend InputCostUsd = (UncachedInputTokens / 1000000.0) * coalesce(InputPricePer1MUsd, 0.0)
| extend CachedInputCostUsd = (CachedInputTokens / 1000000.0) * coalesce(CachedInputPricePer1MUsd, 0.0)
| extend OutputCostUsd = (CompletionTokens / 1000000.0) * coalesce(OutputPricePer1MUsd, 0.0)
| extend InputCostUsd = round(InputCostUsd, 2)
| extend CachedInputCostUsd = round(CachedInputCostUsd, 2)
| extend OutputCostUsd = round(OutputCostUsd, 2)
| summarize
    CachedInputTokens = sum(CachedInputTokens),
    UncachedInputTokens = sum(UncachedInputTokens),
    OutputTokens = sum(CompletionTokens),
    TotalCostUsd = round(sum(InputCostUsd + CachedInputCostUsd + OutputCostUsd), 2)
  by Month
| order by Month asc
'@

$userSpendQuery = @'
let ModelPricing = datatable(Model:string, InputPricePer1MUsd:real, CachedInputPricePer1MUsd:real, OutputPricePer1MUsd:real)
[
    "gpt-5.4", 2.50, 0.25, 15.00,
    "gpt-5.4-mini", 0.75, 0.075, 4.50,
    "gpt-5.4-nano", 0.20, 0.025, 1.25
];
let TokenMetrics = customMetrics
| where timestamp > ago(30d)
| where name in ("Prompt Tokens", "Completion Tokens", "Prompt Cached Tokens", "Cached Prompt Tokens", "Cached Tokens")
| extend SubscriptionId = tostring(customDimensions["Subscription ID"])
| extend UserId = tostring(customDimensions["User ID"])
| extend Model = coalesce(tostring(customDimensions["SelectedModel"]), tostring(customDimensions["Model"]))
| extend ReasoningEffort = tostring(customDimensions["ReasoningEffort"])
| extend ReasoningEffort = iif(isempty(ReasoningEffort), "unspecified", tolower(ReasoningEffort))
| where isnotempty(SubscriptionId) and isnotempty(Model)
| summarize
    PromptTokens = sumif(value, name == "Prompt Tokens"),
    CompletionTokens = sumif(value, name == "Completion Tokens"),
    CachedInputTokens = sumif(value, name in ("Prompt Cached Tokens", "Cached Prompt Tokens", "Cached Tokens"))
  by SubscriptionId, UserId, Model, ReasoningEffort;
TokenMetrics
| join kind=leftouter ModelPricing on Model
| extend UncachedInputTokens = max_of(PromptTokens - CachedInputTokens, 0.0)
| extend TotalCostUsd =
    (UncachedInputTokens / 1000000.0) * coalesce(InputPricePer1MUsd, 0.0) +
    (CachedInputTokens / 1000000.0) * coalesce(CachedInputPricePer1MUsd, 0.0) +
    (CompletionTokens / 1000000.0) * coalesce(OutputPricePer1MUsd, 0.0)
| extend TotalCostUsd = round(TotalCostUsd, 2)
| project SubscriptionId, UserId, Model, ReasoningEffort, PromptTokens, CachedInputTokens, CompletionTokens, TotalCostUsd
| order by TotalCostUsd desc
'@

$modelSpendQuery = @'
let ModelPricing = datatable(Model:string, InputPricePer1MUsd:real, CachedInputPricePer1MUsd:real, OutputPricePer1MUsd:real)
[
    "gpt-5.4", 2.50, 0.25, 15.00,
    "gpt-5.4-mini", 0.75, 0.075, 4.50,
    "gpt-5.4-nano", 0.20, 0.025, 1.25
];
let TokenMetrics = customMetrics
| where timestamp > ago(30d)
| where name in ("Prompt Tokens", "Completion Tokens", "Prompt Cached Tokens", "Cached Prompt Tokens", "Cached Tokens")
| extend Model = coalesce(tostring(customDimensions["SelectedModel"]), tostring(customDimensions["Model"]))
| where isnotempty(Model)
| summarize
    PromptTokens = sumif(value, name == "Prompt Tokens"),
    CompletionTokens = sumif(value, name == "Completion Tokens"),
    CachedInputTokens = sumif(value, name in ("Prompt Cached Tokens", "Cached Prompt Tokens", "Cached Tokens"))
  by Model;
TokenMetrics
| join kind=leftouter ModelPricing on Model
| extend UncachedInputTokens = max_of(PromptTokens - CachedInputTokens, 0.0)
| extend TotalCostUsd =
    (UncachedInputTokens / 1000000.0) * coalesce(InputPricePer1MUsd, 0.0) +
    (CachedInputTokens / 1000000.0) * coalesce(CachedInputPricePer1MUsd, 0.0) +
    (CompletionTokens / 1000000.0) * coalesce(OutputPricePer1MUsd, 0.0)
| extend TotalCostUsd = round(TotalCostUsd, 2)
| project Model, TotalCostUsd
| order by TotalCostUsd desc
'@

$reasoningByModelQuery = @'
customMetrics
| where timestamp > ago(30d)
| where name == "Total Tokens"
| extend Model = coalesce(tostring(customDimensions["SelectedModel"]), tostring(customDimensions["Model"]))
| extend ReasoningEffort = tostring(customDimensions["ReasoningEffort"])
| extend ReasoningEffort = iif(isempty(ReasoningEffort), "unspecified", tolower(ReasoningEffort))
| where isnotempty(Model)
| summarize TotalTokens = sum(value) by Model, ReasoningEffort
| extend ModelReasoning = strcat(Model, " | ", ReasoningEffort)
| project ModelReasoning, TotalTokens
| order by TotalTokens desc
'@

$routerSelectionQuery = @'
customMetrics
| where timestamp > ago(30d)
| where name == "Total Tokens"
| extend RequestedModel = tostring(customDimensions["RequestedModel"])
| extend SelectedModel = coalesce(tostring(customDimensions["SelectedModel"]), tostring(customDimensions["Model"]))
| where tolower(RequestedModel) == "router"
| where isnotempty(SelectedModel)
| summarize TotalTokens = sum(value), Requests = count() by SelectedModel
| order by TotalTokens desc
'@

$workbookModel = @{
    version = 'Notebook/1.0'
    fallbackResourceIds = @($appInsights.id)
    isLocked = $false
    items = @(
        @{
            type = 1
            name = 'intro'
            content = @{
                version = 'TextBlock/1.0'
                text = "## Total Cost of Tokens`nThis dashboard shows token consumption and spend by month, user key, model, and reasoning effort, including model-router selected model tracking."
            }
        },
        @{
            type = 3
            name = 'monthly-spend'
            content = @{
                version = 'KqlItem/1.0'
                query = $monthlySpendQuery
                queryType = 0
                resourceType = 'microsoft.insights/components'
                visualization = 'columnchart'
                title = 'Monthly Token and Spend Trend'
                size = 0
            }
        },
        @{
            type = 3
            name = 'user-spend'
            content = @{
                version = 'KqlItem/1.0'
                query = $userSpendQuery
                queryType = 0
                resourceType = 'microsoft.insights/components'
                visualization = 'table'
                title = 'Cost by Subscription Key, User, and Model'
                size = 0
            }
        },
        @{
            type = 3
            name = 'model-spend'
            content = @{
                version = 'KqlItem/1.0'
                query = $modelSpendQuery
                queryType = 0
                resourceType = 'microsoft.insights/components'
                visualization = 'barchart'
                title = 'Cost by Model'
                size = 0
            }
        },
        @{
            type = 3
            name = 'reasoning-by-model'
            content = @{
                version = 'KqlItem/1.0'
                query = $reasoningByModelQuery
                queryType = 0
                resourceType = 'microsoft.insights/components'
                visualization = 'piechart'
                title = 'Total Tokens by Model and Reasoning Effort'
                size = 0
            }
        },
        @{
            type = 3
            name = 'router-selection'
            content = @{
                version = 'KqlItem/1.0'
                query = $routerSelectionQuery
                queryType = 0
                resourceType = 'microsoft.insights/components'
                visualization = 'piechart'
                title = 'Router Selected Model Distribution (by Total Tokens)'
                size = 0
            }
        }
    )
}

$serializedData = $workbookModel | ConvertTo-Json -Depth 40 -Compress

$existing = az monitor app-insights workbook list `
    --resource-group $ResourceGroupName `
    --category workbook | ConvertFrom-Json

$existingWorkbook = $null
if ($existing) {
    $existingWorkbook = $existing | Where-Object {
        ($_.displayName -eq $DisplayName) -or ($_.properties.displayName -eq $DisplayName)
    } | Select-Object -First 1
}

if ($existingWorkbook) {
    $workbookName = $existingWorkbook.name
}
else {
    $workbookName = ([guid]::NewGuid()).Guid
}

$subscriptionId = ($appInsights.id -split '/')[2]
$workbookResourceId = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/workbooks/$workbookName"
$workbookUrl = "https://management.azure.com${workbookResourceId}?api-version=2023-06-01"

$workbookPayload = @{
    location = $appInsights.location
    kind = 'shared'
    properties = @{
        category = 'workbook'
        displayName = $DisplayName
        sourceId = $appInsights.id
        version = 'Notebook/1.0'
        serializedData = $serializedData
    }
}

$tempPayloadFile = Join-Path $env:TEMP "workbook-payload-$workbookName.json"
$workbookPayload | ConvertTo-Json -Depth 60 | Set-Content -Path $tempPayloadFile -Encoding utf8

try {
    $resultRaw = az rest --method put --url $workbookUrl --body "@$tempPayloadFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create or update workbook via ARM REST API."
    }

    $result = $resultRaw | ConvertFrom-Json
}
finally {
    if (Test-Path $tempPayloadFile) {
        Remove-Item $tempPayloadFile -Force
    }
}

Write-Host "Workbook display name: $DisplayName"
Write-Host "Workbook resource ID: $($result.id)"
Write-Host "Workbook name: $($result.name)"
Write-Host "Portal URL: https://portal.azure.com/#@/resource$($result.id)/overview"
