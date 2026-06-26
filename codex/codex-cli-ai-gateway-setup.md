# Connect Codex CLI to Microsoft Foundry via AI Gateway (APIM)

This guide uses the captured artifacts in this folder:

- `codex\config.toml`
- `codex\foundry-models.json`

## 1. Copy artifacts to your Codex home

```powershell
# Adjust <repo-path> to where you cloned this repo
Copy-Item <repo-path>\codex\foundry-models.json "$env:USERPROFILE\.codex\foundry-models.json" -Force
```

Then **merge** the provider block below into your existing `~/.codex/config.toml`
(do not wholesale replace — your marketplace, plugin, mcp_servers sections must stay intact):

## 2. Set APIM subscription key in environment

`config.toml` maps the header `Ocp-Apim-Subscription-Key` to env var `APIM_SUB_KEY`.

```powershell
[Environment]::SetEnvironmentVariable("APIM_SUB_KEY", "<your-apim-subscription-key>", "User")
$env:APIM_SUB_KEY = "<your-apim-subscription-key>"
```

## 3. Key provider settings (already in `config.toml`)

```toml
model_provider = "foundry-gateway"
model = "gpt-5.4"
model_reasoning_effort = "xhigh"
model_catalog_json = "~/.codex/foundry-models.json"

[model_providers.foundry-gateway]
name = "Microsoft Foundry via AI Gateway"
base_url = "https://<your-apim-name>.azure-api.net/openai"
wire_api = "responses"
env_http_headers = { "Ocp-Apim-Subscription-Key" = "APIM_SUB_KEY" }
```

> **Note:** `model` and `model_reasoning_effort` serve as startup defaults only. Codex CLI overwrites them in `config.toml` whenever you switch model or reasoning effort at runtime, so their values here will drift over time.

## 4. Restart Codex CLI

Close and reopen Codex CLI so it reloads the config and model catalog.

## 5. Validate model routing

Use model slugs from `foundry-models.json`:

- `router`
- `gpt-5.4`
- `gpt-5.4-mini`
- `gpt-5.4-nano`

When using `router`, APIM/Foundry routing should select an underlying model and gateway telemetry will attribute tokens by selected model.

## Notes

- This `config.toml` contains only the portable provider/model settings. Your machine-specific runtime sections (notify, mcp_servers, plugins, marketplaces, projects, tui, desktop, windows) are managed by Codex itself and should remain in your local `~/.codex/config.toml`.
- The gateway endpoint is Responses API based (`/openai/responses`).
