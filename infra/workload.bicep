targetScope = 'resourceGroup'

@description('Primary Azure region.')
param location string

@description('Tags applied to resources.')
param tags object = {}

@description('APIM publisher display name.')
param publisherName string

@description('APIM publisher email.')
param publisherEmail string

@description('Microsoft Foundry account name.')
param aiAccountName string

@description('Custom subdomain for Foundry/OpenAI endpoint.')
param aiCustomSubdomain string

@description('Foundry project name.')
param aiProjectName string

@description('API Management service name.')
param apimName string

@description('Log Analytics workspace name.')
param logAnalyticsName string

@description('Application Insights component name.')
param appInsightsName string

@description('Foundry deployment names and model metadata.')
param gpt54DeploymentName string
param gpt54ModelName string
param gpt54ModelVersion string
param gpt54ModelSku string
param gpt54Capacity int

param gpt54MiniDeploymentName string
param gpt54MiniModelName string
param gpt54MiniModelVersion string
param gpt54MiniModelSku string
param gpt54MiniCapacity int

param gpt54NanoDeploymentName string
param gpt54NanoModelName string
param gpt54NanoModelVersion string
param gpt54NanoModelSku string
param gpt54NanoCapacity int

param routerDeploymentName string
param routerModelName string
param routerModelVersion string
param routerModelSku string
param routerCapacity int

@description('Initial APIM users and dedicated subscription keys.')
param initialUsers array

module aiAccount 'br/public:avm/res/cognitive-services/account:0.11.0' = {
  name: 'ai-account'
  params: {
    name: aiAccountName
    kind: 'AIServices'
    location: location
    customSubDomainName: aiCustomSubdomain
    allowProjectManagement: true
    publicNetworkAccess: 'Enabled'
    managedIdentities: {
      systemAssigned: true
    }
    disableLocalAuth: false
    deployments: [
      {
        name: gpt54DeploymentName
        model: {
          format: 'OpenAI'
          name: gpt54ModelName
          version: gpt54ModelVersion
        }
        sku: {
          name: gpt54ModelSku
          capacity: gpt54Capacity
        }
      }
      {
        name: gpt54MiniDeploymentName
        model: {
          format: 'OpenAI'
          name: gpt54MiniModelName
          version: gpt54MiniModelVersion
        }
        sku: {
          name: gpt54MiniModelSku
          capacity: gpt54MiniCapacity
        }
      }
      {
        name: gpt54NanoDeploymentName
        model: {
          format: 'OpenAI'
          name: gpt54NanoModelName
          version: gpt54NanoModelVersion
        }
        sku: {
          name: gpt54NanoModelSku
          capacity: gpt54NanoCapacity
        }
      }
    ]
  }
}

module aiProject './project.bicep' = {
  name: 'ai-project'
  params: {
    accountName: aiAccountName
    projectName: aiProjectName
    location: location
  }
  dependsOn: [
    aiAccount
  ]
}

resource aiAccountResource 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiAccountName
}

resource modelRouterDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-10-01-preview' = {
  name: '${aiAccountName}/${routerDeploymentName}'
  sku: {
    name: routerModelSku
    capacity: routerCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: routerModelName
      version: routerModelVersion
    }
    routing: {
      mode: 'balanced'
      models: [
        {
          format: 'OpenAI'
          name: gpt54ModelName
          version: gpt54ModelVersion
        }
        {
          format: 'OpenAI'
          name: gpt54MiniModelName
          version: gpt54MiniModelVersion
        }
        {
          format: 'OpenAI'
          name: gpt54NanoModelName
          version: gpt54NanoModelVersion
        }
      ]
    }
  }
  dependsOn: [
    aiAccount
  ]
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
  tags: tags
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: tags
}

resource apim 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: 'StandardV2'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherName: publisherName
    publisherEmail: publisherEmail
    publicNetworkAccess: 'Enabled'
  }
  tags: tags
}

resource apimToAiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(apim.id, aiAccountResource.id, 'cognitive-services-user')
  scope: aiAccountResource
  dependsOn: [
    aiAccount
  ]
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
    principalId: apim.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

module apimGateway './apim-openai-api.bicep' = {
  name: 'apim-openai-gateway'
  params: {
    apimName: apimName
    aiEndpoint: aiAccountResource.properties.endpoint
    gpt54DeploymentName: gpt54DeploymentName
    gpt54MiniDeploymentName: gpt54MiniDeploymentName
    gpt54NanoDeploymentName: gpt54NanoDeploymentName
    routerDeploymentName: routerDeploymentName
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    initialUsers: initialUsers
  }
  dependsOn: [
    apim
    apimToAiRoleAssignment
    aiAccount
  ]
}

resource apimDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'apim-to-loganalytics'
  scope: apim
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'GatewayLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output foundryAccountName string = aiAccountName
output foundryProjectName string = aiProjectName
output foundryEndpoint string = aiAccountResource.properties.endpoint
output apimServiceName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output appInsightsName string = appInsights.name
output logAnalyticsWorkspaceName string = logAnalytics.name
output userSubscriptionNames array = apimGateway.outputs.userSubscriptionNames
output foundryProjectId string = aiProject.outputs.projectId
