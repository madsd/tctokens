using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'tctokens')
param location = readEnvironmentVariable('AZURE_LOCATION')

param publisherName = readEnvironmentVariable('APIM_PUBLISHER_NAME', 'Token Cost Insights')
param publisherEmail = readEnvironmentVariable('APIM_PUBLISHER_EMAIL', 'admin@example.com')

// Model versions are intentionally environment-driven. Set them with scripts/discover-model-versions.ps1.
param gpt54ModelVersion = readEnvironmentVariable('GPT54_MODEL_VERSION')
param gpt54MiniModelVersion = readEnvironmentVariable('GPT54_MINI_MODEL_VERSION')
param gpt54NanoModelVersion = readEnvironmentVariable('GPT54_NANO_MODEL_VERSION')

param routerModelName = readEnvironmentVariable('ROUTER_MODEL_NAME', 'model-router')
param routerModelVersion = readEnvironmentVariable('ROUTER_MODEL_VERSION')

