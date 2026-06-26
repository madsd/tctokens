param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$GrafanaName,

    [Parameter(Mandatory = $true)]
    [string]$LogAnalyticsWorkspaceName,

    [Parameter(Mandatory = $false)]
    [string]$DashboardFilePath = (Join-Path $PSScriptRoot '..\grafana\token-cost-dashboard.json'),

    [Parameter(Mandatory = $false)]
    [string]$FolderTitle = 'Token Cost Dashboards',

    [Parameter(Mandatory = $false)]
    [string]$DataSourceName = 'Azure Monitor'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $DashboardFilePath)) {
    throw "Dashboard file not found: $DashboardFilePath"
}

az extension add --name amg --upgrade --only-show-errors | Out-Null

$subscriptionId = az account show --query id --output tsv
if (-not $subscriptionId) {
    throw 'Unable to resolve active Azure subscription ID.'
}

$grafana = az grafana show `
    --resource-group $ResourceGroupName `
    --name $GrafanaName | ConvertFrom-Json

if (-not $grafana.id) {
    throw "Managed Grafana '$GrafanaName' was not found in '$ResourceGroupName'."
}

$workspace = az monitor log-analytics workspace show `
    --resource-group $ResourceGroupName `
    --workspace-name $LogAnalyticsWorkspaceName | ConvertFrom-Json

if (-not $workspace.id) {
    throw "Log Analytics workspace '$LogAnalyticsWorkspaceName' was not found in '$ResourceGroupName'."
}

$dataSourceDefinition = @{
    name      = $DataSourceName
    type      = 'grafana-azure-monitor-datasource'
    access    = 'proxy'
    isDefault = $true
    jsonData  = @{
        azureAuthType  = 'msi'
        cloudName      = 'azuremonitor'
        subscriptionId = $subscriptionId
    }
}

$tempDataSourceFile = Join-Path $env:TEMP "grafana-datasource-$($grafana.name).json"
$tempDashboardFile = Join-Path $env:TEMP "grafana-dashboard-$($grafana.name).json"

try {
    $dataSourceDefinition | ConvertTo-Json -Depth 20 | Set-Content -Path $tempDataSourceFile -Encoding utf8

    $existingDataSource = $null
    $existingDataSources = az grafana data-source list `
        --resource-group $ResourceGroupName `
        --name $GrafanaName | ConvertFrom-Json

    if ($existingDataSources) {
        $existingDataSource = $existingDataSources | Where-Object { $_.name -eq $DataSourceName } | Select-Object -First 1
    }

    if ($existingDataSource) {
        az grafana data-source update `
            --resource-group $ResourceGroupName `
            --name $GrafanaName `
            --data-source $existingDataSource.uid `
            --definition $tempDataSourceFile | Out-Null
    }
    else {
        az grafana data-source create `
            --resource-group $ResourceGroupName `
            --name $GrafanaName `
            --definition $tempDataSourceFile | Out-Null
    }

    $azureMonitorDataSource = az grafana data-source show `
        --resource-group $ResourceGroupName `
        --name $GrafanaName `
        --data-source $DataSourceName | ConvertFrom-Json

    if (-not $azureMonitorDataSource.uid) {
        throw 'Azure Monitor data source UID could not be resolved.'
    }

    $dashboardTemplate = Get-Content -Path $DashboardFilePath -Raw
    $dashboardTemplate = $dashboardTemplate.Replace('__AZMON_DS_UID__', $azureMonitorDataSource.uid)
    $dashboardTemplate = $dashboardTemplate.Replace('__LAW_RESOURCE_ID__', $workspace.id)
    Set-Content -Path $tempDashboardFile -Value $dashboardTemplate -Encoding utf8

    $folder = $null
    $folders = az grafana folder list `
        --resource-group $ResourceGroupName `
        --name $GrafanaName | ConvertFrom-Json

    if ($folders) {
        $folder = $folders | Where-Object { $_.title -eq $FolderTitle } | Select-Object -First 1
    }

    if (-not $folder) {
        $folder = az grafana folder create `
            --resource-group $ResourceGroupName `
            --name $GrafanaName `
            --title $FolderTitle | ConvertFrom-Json
    }

    if (-not $folder.uid) {
        throw "Folder '$FolderTitle' could not be resolved or created."
    }

    $importResult = az grafana dashboard import `
        --resource-group $ResourceGroupName `
        --name $GrafanaName `
        --folder $folder.uid `
        --overwrite true `
        --definition $tempDashboardFile | ConvertFrom-Json

    if (-not $importResult.uid) {
        throw 'Grafana dashboard import did not return a dashboard UID.'
    }

    Write-Host "Grafana dashboard imported."
    Write-Host "Dashboard UID: $($importResult.uid)"
    Write-Host "Folder: $($folder.title)"
    Write-Host "Grafana endpoint: $($grafana.properties.endpoint)"
}
finally {
    if (Test-Path $tempDataSourceFile) {
        Remove-Item $tempDataSourceFile -Force
    }

    if (Test-Path $tempDashboardFile) {
        Remove-Item $tempDashboardFile -Force
    }
}
