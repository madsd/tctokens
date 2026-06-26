targetScope = 'resourceGroup'

@description('Existing Azure AI Foundry (AIServices) account name.')
param accountName string

@description('Foundry project name.')
param projectName string

@description('Azure region.')
param location string

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: account
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

output projectId string = project.id

