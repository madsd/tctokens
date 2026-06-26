targetScope = 'subscription'

@description('Environment name used in resource naming.')
@minLength(2)
param environmentName string

@description('Primary Azure region.')
param location string

@description('Resource group name to create.')
param resourceGroupName string = 'rg-${environmentName}'

@description('Tags applied to resources.')
param tags object = {}

@description('APIM publisher display name.')
param publisherName string = 'Token Cost Insights'

@description('APIM publisher email.')
param publisherEmail string = 'admin@example.com'

@description('Microsoft Foundry account name.')
param aiAccountName string = take('ais-${toLower(environmentName)}-${substring(uniqueString(subscription().subscriptionId, environmentName), 0, 6)}', 64)

@description('Custom subdomain for Foundry/OpenAI endpoint.')
param aiCustomSubdomain string = take('ais-${toLower(environmentName)}-${substring(uniqueString(subscription().subscriptionId, environmentName), 0, 6)}', 63)

@description('Foundry project name.')
param aiProjectName string = take('proj-${toLower(environmentName)}', 64)

@description('API Management service name.')
param apimName string = take('apim-${toLower(environmentName)}-${substring(uniqueString(subscription().subscriptionId, environmentName), 0, 6)}', 50)

@description('Log Analytics workspace name.')
param logAnalyticsName string = take('log-${toLower(environmentName)}-${substring(uniqueString(subscription().subscriptionId, environmentName), 0, 6)}', 63)

@description('Application Insights component name.')
param appInsightsName string = take('appi-${toLower(environmentName)}-${substring(uniqueString(subscription().subscriptionId, environmentName), 0, 6)}', 260)

@description('Azure Managed Grafana instance name.')
param grafanaName string = take('graf-${toLower(environmentName)}-${substring(uniqueString(subscription().subscriptionId, environmentName), 0, 6)}', 63)

@description('Foundry deployment names and model metadata.')
param gpt54DeploymentName string = 'gpt-5.4'
param gpt54ModelName string = 'gpt-5.4'
param gpt54ModelVersion string
param gpt54ModelSku string = 'GlobalStandard'
param gpt54Capacity int = 50

param gpt54MiniDeploymentName string = 'gpt-5.4-mini'
param gpt54MiniModelName string = 'gpt-5.4-mini'
param gpt54MiniModelVersion string
param gpt54MiniModelSku string = 'GlobalStandard'
param gpt54MiniCapacity int = 50

param gpt54NanoDeploymentName string = 'gpt-5.4-nano'
param gpt54NanoModelName string = 'gpt-5.4-nano'
param gpt54NanoModelVersion string
param gpt54NanoModelSku string = 'GlobalStandard'
param gpt54NanoCapacity int = 50

param routerDeploymentName string = 'router'
param routerModelName string
param routerModelVersion string
param routerModelSku string = 'GlobalStandard'
param routerCapacity int = 20

@description('Initial APIM users and dedicated subscription keys.')
param initialUsers array = [
  {
    id: 'user01'
    firstName: 'User'
    lastName: 'One'
    email: 'user01@example.com'
  }
  {
    id: 'user02'
    firstName: 'User'
    lastName: 'Two'
    email: 'user02@example.com'
  }
  {
    id: 'user03'
    firstName: 'User'
    lastName: 'Three'
    email: 'user03@example.com'
  }
  {
    id: 'user04'
    firstName: 'User'
    lastName: 'Four'
    email: 'user04@example.com'
  }
  {
    id: 'user05'
    firstName: 'User'
    lastName: 'Five'
    email: 'user05@example.com'
  }
]

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module workload './workload.bicep' = {
  name: 'workload'
  scope: rg
  params: {
    location: location
    tags: tags
    publisherName: publisherName
    publisherEmail: publisherEmail
    aiAccountName: aiAccountName
    aiCustomSubdomain: aiCustomSubdomain
    aiProjectName: aiProjectName
    apimName: apimName
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
    grafanaName: grafanaName
    gpt54DeploymentName: gpt54DeploymentName
    gpt54ModelName: gpt54ModelName
    gpt54ModelVersion: gpt54ModelVersion
    gpt54ModelSku: gpt54ModelSku
    gpt54Capacity: gpt54Capacity
    gpt54MiniDeploymentName: gpt54MiniDeploymentName
    gpt54MiniModelName: gpt54MiniModelName
    gpt54MiniModelVersion: gpt54MiniModelVersion
    gpt54MiniModelSku: gpt54MiniModelSku
    gpt54MiniCapacity: gpt54MiniCapacity
    gpt54NanoDeploymentName: gpt54NanoDeploymentName
    gpt54NanoModelName: gpt54NanoModelName
    gpt54NanoModelVersion: gpt54NanoModelVersion
    gpt54NanoModelSku: gpt54NanoModelSku
    gpt54NanoCapacity: gpt54NanoCapacity
    routerDeploymentName: routerDeploymentName
    routerModelName: routerModelName
    routerModelVersion: routerModelVersion
    routerModelSku: routerModelSku
    routerCapacity: routerCapacity
    initialUsers: initialUsers
  }
}

output resourceGroup string = rg.name
output foundryAccountName string = workload.outputs.foundryAccountName
output foundryProjectName string = workload.outputs.foundryProjectName
output foundryEndpoint string = workload.outputs.foundryEndpoint
output apimServiceName string = workload.outputs.apimServiceName
output apimGatewayUrl string = workload.outputs.apimGatewayUrl
output appInsightsName string = workload.outputs.appInsightsName
output logAnalyticsWorkspaceName string = workload.outputs.logAnalyticsWorkspaceName
output grafanaName string = workload.outputs.grafanaName
output grafanaEndpoint string = workload.outputs.grafanaEndpoint
output userSubscriptionNames array = workload.outputs.userSubscriptionNames
output foundryProjectId string = workload.outputs.foundryProjectId
