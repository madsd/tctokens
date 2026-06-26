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
- Azure Managed Grafana dashboard for per-key and per-model cost reporting

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
- `scripts/deploy-grafana-dashboard.ps1` - configures Azure Managed Grafana data source and imports dashboard
- `scripts/seed-fake-token-metrics.ps1` - sends synthetic token metrics to App Insights for dashboard demos
- `dashboard/token-cost-queries.kql` - dashboard/reporting queries
- `grafana/token-cost-dashboard.json` - Azure Managed Grafana dashboard template

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

The dashboard is **Azure Managed Grafana**, backed by the Azure Monitor data source.

Cost is computed from the per-request token metrics emitted by the APIM policy, multiplied by per-model prices (USD per 1M tokens) for input, cached input, and output. Prices are defined inline in the Grafana panel queries and in `dashboard/token-cost-queries.kql` — update them if your contracted or regional rates differ, and keep the two in sync.

> **Schema note:** Grafana queries the **Log Analytics workspace**, where Application Insights custom metrics surface as the **`AppMetrics`** table (`Name`, `Sum`, `Properties`, `TimeGenerated`). The standalone reference queries in `dashboard/token-cost-queries.kql` target the **Application Insights** resource directly and use the classic `customMetrics` schema (`name`, `value`, `customDimensions`, `timestamp`). Both compute identical costs; only the table and column names differ.

### Deploy the Grafana dashboard

```powershell
.\scripts\deploy-grafana-dashboard.ps1 -ResourceGroupName rg-tctokens -GrafanaName graf-tctokens-lpycq6 -LogAnalyticsWorkspaceName log-tctokens-lpycq6
```

This script will:
- ensure the Azure Monitor data source exists and uses managed identity
- create a Grafana folder named **Token Cost Dashboards**
- import/update `grafana/token-cost-dashboard.json` with working data source and Log Analytics workspace bindings

The dashboard provides a Developer/Key and Model filter plus: daily token trend, daily spend trend (USD), per key/user/model cost table, cost by model, router selected-model distribution, and total tokens by model and reasoning effort.

If the script returns `No Grafana Role Assigned`, assign yourself at least **Grafana Admin** on the Managed Grafana resource and rerun. Role propagation can take a few minutes.

### Reference queries

`dashboard/token-cost-queries.kql` contains standalone KQL (Application Insights `customMetrics` scope) for ad-hoc analysis in Azure Monitor Logs:
- Query 1: daily token trend
- Query 2: daily spend trend (USD)
- Query 3: per key + model breakdown
- Query 4: per model total across users
- Query 5: model-router selected model breakdown
- Query 6: total tokens by model and reasoning effort

These queries compute total dollar spend per user key and per model.

### Seed synthetic demo data

Use this to populate metrics for `user01-subscription` through `user05-subscription` so the dashboard shows realistic activity quickly:

```powershell
.\scripts\seed-fake-token-metrics.ps1 -ResourceGroupName rg-tctokens -AppInsightsName appi-tctokens-lpycq6 -Days 2 -SamplesPerDay 12 -SyntheticSpreadDays 14
```

Notes:
- Synthetic points are marked with `SyntheticData=true` in metric properties.
- Synthetic spread is encoded via `SyntheticDay=yyyy-MM-dd` to distribute demo charts across the last N days.
- Application Insights metric ingestion accepts recent timestamps only (about last 48 hours).
