targetScope = 'resourceGroup'

@description('API Management service name.')
param apimName string

@description('Foundry/OpenAI endpoint, for example https://<account>.openai.azure.com/.')
param aiEndpoint string

@description('APIM API name (without revision).')
param apiName string = 'openai'

@description('APIM API display name.')
param apiDisplayName string = 'Foundry OpenAI Gateway'

@description('APIM API path.')
param apiPath string = 'openai'

@description('Deployment name in Foundry for GPT 5.4.')
param gpt54DeploymentName string = 'gpt-5.4'

@description('Deployment name in Foundry for GPT 5.4 Mini.')
param gpt54MiniDeploymentName string = 'gpt-5.4-mini'

@description('Deployment name in Foundry for GPT 5.4 Nano.')
param gpt54NanoDeploymentName string = 'gpt-5.4-nano'

@description('Logical deployment name clients call when using router mode.')
param routerDeploymentName string = 'router'

@description('Token limit per minute per subscription key.')
param tokensPerMinute int = 200000

@description('Application Insights instrumentation key used by APIM logger.')
@secure()
param appInsightsInstrumentationKey string

@description('Initial APIM users that receive dedicated subscription keys.')
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

var aiOpenAiBase = '${aiEndpoint}openai'
var aiOpenAiV1Base = '${aiEndpoint}openai/v1'
var gpt54BackendId = 'gpt54-backend'
var gpt54MiniBackendId = 'gpt54mini-backend'
var gpt54NanoBackendId = 'gpt54nano-backend'
var apiResourceName = '${apiName};rev=1'
var policyXmlTemplate = '''
<policies>
    <inbound>
        <base />
        <set-variable name="requestBody" value="@(context.Request.Body.As&lt;JObject&gt;(preserveContent: true))" />
        <set-variable name="requestedDeployment" value="@{
            var body = (JObject)context.Variables[&quot;requestBody&quot;];
            return (string)(body[&quot;model&quot;] ?? &quot;&quot;);
        }" />
        <set-variable name="reasoningEffort" value="@{
            var body = (JObject)context.Variables[&quot;requestBody&quot;];
            var reasoningToken = body[&quot;reasoning&quot;];
            if (reasoningToken != null &amp;&amp; reasoningToken.Type == JTokenType.Object)
            {
                var reasoningObject = (JObject)reasoningToken;
                var effort = (string)(reasoningObject[&quot;effort&quot;] ?? &quot;&quot;);
                if (!string.IsNullOrEmpty(effort))
                {
                    return effort;
                }
            }

            var fallback = (string)(body[&quot;reasoning_effort&quot;] ?? body[&quot;reasoningEffort&quot;] ?? &quot;&quot;);
            return string.IsNullOrEmpty(fallback) ? &quot;unspecified&quot; : fallback;
        }" />
        <set-variable name="resolvedDeployment" value="@{
            var requested = (string)context.Variables[&quot;requestedDeployment&quot;];
            if (string.Equals(requested, &quot;__ROUTER_DEPLOYMENT__&quot;, StringComparison.OrdinalIgnoreCase))
            {
                var targets = new [] { &quot;__GPT54_DEPLOYMENT__&quot;, &quot;__GPT54_MINI_DEPLOYMENT__&quot;, &quot;__GPT54_NANO_DEPLOYMENT__&quot; };
                var index = Math.Abs(context.RequestId.GetHashCode()) % targets.Length;
                return targets[index];
            }

            return requested;
        }" />
        <azure-openai-token-limit tokens-per-minute="__TOKENS_PER_MINUTE__" counter-key="@(context.Subscription.Id)" estimate-prompt-tokens="true" tokens-consumed-header-name="x-tokens-consumed" remaining-tokens-header-name="x-tokens-remaining" />
        <choose>
            <when condition="@(!context.Variables.ContainsKey(&quot;requestedDeployment&quot;) || string.IsNullOrEmpty((string)context.Variables[&quot;requestedDeployment&quot;]))">
                <return-response>
                    <set-status code="400" reason="Missing model" />
                    <set-body>{&quot;error&quot;:&quot;Request body must include the 'model' property. Allowed values: __GPT54_DEPLOYMENT__, __GPT54_MINI_DEPLOYMENT__, __GPT54_NANO_DEPLOYMENT__, __ROUTER_DEPLOYMENT__.&quot;}</set-body>
                </return-response>
            </when>
            <when condition="@((string)context.Variables[&quot;resolvedDeployment&quot;] == &quot;__GPT54_DEPLOYMENT__&quot;)">
                <set-backend-service backend-id="__GPT54_BACKEND_ID__" />
            </when>
            <when condition="@((string)context.Variables[&quot;resolvedDeployment&quot;] == &quot;__GPT54_MINI_DEPLOYMENT__&quot;)">
                <set-backend-service backend-id="__GPT54_MINI_BACKEND_ID__" />
            </when>
            <when condition="@((string)context.Variables[&quot;resolvedDeployment&quot;] == &quot;__GPT54_NANO_DEPLOYMENT__&quot;)">
                <set-backend-service backend-id="__GPT54_NANO_BACKEND_ID__" />
            </when>
            <when condition="@((string)context.Variables[&quot;resolvedDeployment&quot;] == &quot;__ROUTER_DEPLOYMENT__&quot;)">
                <set-backend-service backend-id="__GPT54_BACKEND_ID__" />
            </when>
            <otherwise>
                <return-response>
                    <set-status code="400" reason="Unsupported model" />
                    <set-body>{&quot;error&quot;:&quot;Unsupported model in request body 'model'. Allowed values: __GPT54_DEPLOYMENT__, __GPT54_MINI_DEPLOYMENT__, __GPT54_NANO_DEPLOYMENT__, __ROUTER_DEPLOYMENT__.&quot;}</set-body>
                </return-response>
            </otherwise>
        </choose>
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
        <rewrite-uri template="/responses" copy-unmatched-params="true" />
        <set-body>@{
            var requestBody = (JObject)context.Variables[&quot;requestBody&quot;];
            requestBody[&quot;model&quot;] = (string)context.Variables[&quot;resolvedDeployment&quot;];
            return requestBody.ToString();
        }</set-body>
        <llm-emit-token-metric namespace="ai-gateway">
            <dimension name="Subscription ID" />
            <dimension name="User ID" />
            <dimension name="Model" value="@((string)context.Variables[&quot;resolvedDeployment&quot;])" />
            <dimension name="RequestedModel" value="@((string)context.Variables[&quot;requestedDeployment&quot;])" />
            <dimension name="SelectedModel" value="@((string)context.Variables[&quot;resolvedDeployment&quot;])" />
            <dimension name="ReasoningEffort" value="@((string)context.Variables[&quot;reasoningEffort&quot;])" />
        </llm-emit-token-metric>
    </inbound>
    <backend>
        <forward-request timeout="120" />
    </backend>
    <outbound>
        <base />
        <set-variable name="selectedModelFromResponse" value="@{
            var contentType = context.Response.Headers.GetValueOrDefault(&quot;Content-Type&quot;, string.Empty);
            if (contentType.IndexOf(&quot;application/json&quot;, StringComparison.OrdinalIgnoreCase) &lt; 0)
            {
                return (string)context.Variables[&quot;resolvedDeployment&quot;];
            }

            var responseBody = context.Response.Body.As&lt;JObject&gt;(preserveContent: true);
            return (string)(responseBody[&quot;model&quot;] ?? (string)context.Variables[&quot;resolvedDeployment&quot;]);
        }" />
        <set-header name="x-selected-model" exists-action="override">
            <value>@((string)context.Variables[&quot;selectedModelFromResponse&quot;])</value>
        </set-header>
    </outbound>
    <on-error>
        <base />
        <choose>
            <when condition="@(context.LastError.Source == &quot;azure-openai-token-limit&quot;)">
                <return-response>
                    <set-status code="429" reason="Token limit exceeded" />
                    <set-body>{&quot;error&quot;:&quot;Token rate limit exceeded for this subscription key.&quot;}</set-body>
                </return-response>
            </when>
        </choose>
    </on-error>
</policies>
'''
var policyXmlStep1 = replace(policyXmlTemplate, '__ROUTER_DEPLOYMENT__', routerDeploymentName)
var policyXmlStep2 = replace(policyXmlStep1, '__GPT54_DEPLOYMENT__', gpt54DeploymentName)
var policyXmlStep3 = replace(policyXmlStep2, '__GPT54_MINI_DEPLOYMENT__', gpt54MiniDeploymentName)
var policyXmlStep4 = replace(policyXmlStep3, '__GPT54_NANO_DEPLOYMENT__', gpt54NanoDeploymentName)
var policyXmlStep5 = replace(policyXmlStep4, '__GPT54_BACKEND_ID__', gpt54BackendId)
var policyXmlStep6 = replace(policyXmlStep5, '__GPT54_MINI_BACKEND_ID__', gpt54MiniBackendId)
var policyXmlStep7 = replace(policyXmlStep6, '__GPT54_NANO_BACKEND_ID__', gpt54NanoBackendId)
var policyXmlStep8 = replace(policyXmlStep7, '__TOKENS_PER_MINUTE__', string(tokensPerMinute))
var policyXml = policyXmlStep8

resource apim 'Microsoft.ApiManagement/service@2023-09-01-preview' existing = {
  name: apimName
}

resource openAiApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apim
  name: apiResourceName
  properties: {
    displayName: apiDisplayName
    path: apiPath
    protocols: [
      'https'
    ]
    apiType: 'http'
    serviceUrl: aiOpenAiBase
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    type: 'http'
  }
}

resource responsesOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: openAiApi
  name: 'responses'
  properties: {
    displayName: 'Responses'
    method: 'POST'
    urlTemplate: '/responses'
    templateParameters: []
    responses: []
  }
}

resource gpt54Backend 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  parent: apim
  name: gpt54BackendId
  properties: {
    protocol: 'http'
    url: aiOpenAiV1Base
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource gpt54MiniBackend 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  parent: apim
  name: gpt54MiniBackendId
  properties: {
    protocol: 'http'
    url: aiOpenAiV1Base
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource gpt54NanoBackend 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  parent: apim
  name: gpt54NanoBackendId
  properties: {
    protocol: 'http'
    url: aiOpenAiV1Base
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2023-09-01-preview' = {
  parent: apim
  name: 'appinsights-logger'
  properties: {
    loggerType: 'applicationInsights'
    isBuffered: true
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
  }
}

resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2023-09-01-preview' = {
  parent: openAiApi
  name: 'applicationinsights'
  properties: {
    loggerId: appInsightsLogger.id
    metrics: true
    alwaysLog: 'allErrors'
    operationNameFormat: 'Name'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

resource openAiApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
  parent: openAiApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: policyXml
  }
}

resource apimUsers 'Microsoft.ApiManagement/service/users@2023-09-01-preview' = [
  for user in initialUsers: {
    parent: apim
    name: user.id
    properties: {
      email: user.email
      firstName: user.firstName
      lastName: user.lastName
      state: 'active'
      confirmation: 'invite'
      appType: 'developerPortal'
    }
  }
]

resource userSubscriptions 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = [
  for user in initialUsers: {
    parent: apim
    name: '${user.id}-subscription'
    dependsOn: [
      openAiApi
      apimUsers
    ]
    properties: {
      displayName: '${user.firstName} ${user.lastName} AI Gateway Subscription'
      ownerId: '/users/${user.id}'
      scope: '/apis/${apiName}'
      state: 'active'
      allowTracing: false
    }
  }
]

output apiId string = openAiApi.id
output userSubscriptionNames array = [
  for user in initialUsers: '${user.id}-subscription'
]
