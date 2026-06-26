# Connect Codex CLI to Azure AI Gateway (APIM)

This guide uses the captured artifacts in this folder:

- `codex\config.toml`
- `codex\foundry-models.json`

## 1. Copy artifacts to your Codex home

```powershell
Copy-Item C:\code\github\madsd\tctokens\codex\foundry-models.json C:\Users\madsd\.codex\foundry-models.json -Force
Copy-Item C:\code\github\madsd\tctokens\codex\config.toml C:\Users\madsd\.codex\config.toml -Force
```

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
name = "Foundry via AI Gateway"
base_url = "https://apim-tctokens-lpycq6.azure-api.net/openai"
wire_api = "responses"
env_http_headers = { "Ocp-Apim-Subscription-Key" = "APIM_SUB_KEY" }
```

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

- This captured `config.toml` includes machine-specific runtime/plugin blocks. Keep them if they work for your machine, or keep only the provider/model sections if you want a minimal portable config.
- The gateway endpoint is Responses API based (`/openai/responses`).
