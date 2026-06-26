# Microsoft Foundry + APIM AI Gateway Token Cost Insights

This project provisions:

- Microsoft Foundry account + Foundry project (both with system-assigned managed identity)
- Model deployments:
  - `gpt-5.4`
  - `gpt-5.4-mini`
  - `gpt-5.4-nano`
  - `router` (model-router deployment)
- API Management Standard v2 as AI Gateway
- APIM policy for:
  - per-subscription token limits
  - per-subscription/model/user token metric emission
  - explicit router telemetry (`RequestedModel`, `SelectedModel`)
  - pass-through model invocation via `model` in request body, with deterministic `router` fan-out across the three GPT 5.4 deployments
- Five initial APIM users and dedicated subscriptions (keys)
- Log Analytics + App Insights plumbing for observability
- KQL dashboard queries for per-key and per-model cost reporting

## Client tool setup

### Codex CLI

See [codex/codex-cli-ai-gateway-setup.md](codex/codex-cli-ai-gateway-setup.md) for connecting Codex CLI to the gateway.

More tools coming.

## Files

- `azure.yaml` - azd configuration
- `infra/main.bicep` - subscription-scope orchestration
- `infra/project.bicep` - Foundry project child resource
- `infra/apim-openai-api.bicep` - APIM API/backends/policy/users/subscriptions
- `infra/main.parameters.bicepparam` - environment-driven inputs
- `scripts/discover-model-versions.ps1` - resolves model versions and writes azd env vars
- `scripts/list-user-subscription-keys.ps1` - exports generated APIM subscription keys
- `scripts/deploy-dashboard-workbook.ps1` - creates/updates an Azure Workbook dashboard
- `scripts/seed-fake-token-metrics.ps1` - sends synthetic token metrics to App Insights for dashboard demos
- `dashboard/token-cost-queries.kql` - dashboard/reporting queries

## Prerequisites

1. Azure CLI + Azure Developer CLI (`azd`)
2. Logged into Azure: `az login`
3. Subscription selected: `az account set --subscription <subscription-id>`

## Configure and deploy

1. Initialize/select azd environment:

   ```powershell
   azd init
   azd env new tctokens
   ```

2. Set APIM publisher metadata (replace with your values):

   ```powershell
   azd env set APIM_PUBLISHER_NAME "Contoso"
   azd env set APIM_PUBLISHER_EMAIL "someone@contoso.com"
   ```

3. Resolve and store model versions for your chosen region:

   ```powershell
   .\scripts\discover-model-versions.ps1 -Location swedencentral -AzdEnvironment tctokens -RouterModelName model-router
   ```

4. Deploy:

   ```powershell
   azd up
   ```

## Get the five user subscription keys

After deployment:

```powershell
.\scripts\list-user-subscription-keys.ps1 -ApimName <apim-name> -ResourceGroupName <resource-group>
```

Those keys map to users `user01` through `user05` and are used for per-user/token attribution.

## Calling through the gateway

Gateway route shape:

```text
POST https://<apim-gateway-host>/openai/responses
```

Request JSON must include `model`:

- `gpt-5.4`
- `gpt-5.4-mini`
- `gpt-5.4-nano`
- `router` (gateway selects one of the three GPT 5.4 deployments and echoes it in `x-selected-model`)

Include key header:

```text
Ocp-Apim-Subscription-Key: <user-key>
```

## Dashboard and cost calculation

Use `dashboard/token-cost-queries.kql` in Azure Monitor Logs or Workbook:

Before using the workbook, in the Application Insights resource open **Usage and estimated costs** and enable **Custom metrics (Preview) -> With dimensions**.

1. `dashboard/token-cost-queries.kql` is prefilled with Global Standard PAYG prices (USD per 1M tokens) for:
   - `gpt-5.4`
   - `gpt-5.4-mini`
   - `gpt-5.4-nano`
   Update these values if your contracted or regional rates differ.
2. Run:
   - Query 1: daily token trend
   - Query 2: daily spend trend (USD)
   - Query 3: per key total across models
   - Query 4: per model total across users
   - Query 5: model-router selected model breakdown
   - Query 6: total tokens by model and reasoning effort

These queries compute total dollar spend per user key and per model.

### Deploy workbook dashboard

```powershell
.\scripts\deploy-dashboard-workbook.ps1 -ResourceGroupName rg-tctokens -AppInsightsName appi-tctokens-lpycq6
```

This creates/updates a workbook named **Total Cost of Tokens Dashboard** with:
- Daily token trend chart
- Daily spend trend chart
- Per-user key/model spend table
- Per-model spend chart
- Total tokens by model and reasoning effort pie chart
- Router selected-model distribution chart

### Seed synthetic demo data

Use this to populate metrics for `user01-subscription` and `user02-subscription` so the workbook shows realistic activity quickly:

```powershell
.\scripts\seed-fake-token-metrics.ps1 -ResourceGroupName rg-tctokens -AppInsightsName appi-tctokens-lpycq6 -Days 2
```

Notes:
- Synthetic points are marked with `SyntheticData=true` in metric properties.
- Application Insights metric ingestion accepts recent timestamps only (about last 48 hours).
