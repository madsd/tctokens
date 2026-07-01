---
name: ard-catalog
description: >-
  Discover installable MCP servers, tools, skills, and agents for a task by
  searching the approved Contoso ARD catalog. Use whenever the user wants to find
  or install a tool, MCP server, skill, agent, or integration for something they
  are trying to do — email, calendars, databases, payments, cloud platforms,
  CI/CD, messaging, monitoring, file storage, and similar services.
argument-hint: <what you want to find>
---

# Find approved agentic resources (Contoso ARD catalog)

Use this skill when the user asks you to **find** an MCP server, tool, skill, or
agent for a task. It searches the approved Contoso ARD catalog (a discovery
service) and presents matches for the user to choose from.

Invoke it as `/ard-catalog <query>`, where `<query>` is the task to find tools
for. Also use it whenever the user otherwise asks you to find a tool, MCP server,
or integration for a task. Search the catalog when the task needs a third-party
service (email, calendars, payments, databases, cloud, CI/CD, monitoring,
messaging, file storage); skip it for purely local work (writing code, editing
files, git, shell, math).

## 1. Use the Contoso Private ARD Catalog (built in)

This skill already knows where to search — **the Contoso Private ARD Catalog**:

```
https://ard-catalog.salmonisland-bb7131ca.swedencentral.azurecontainerapps.io/api/v1/search
```

Query it directly. **Never ask the user for a URL** — the endpoint is built in,
so `/ard-catalog <task>` works with zero configuration. No authentication is
required.

Use a different service **only if the user explicitly names one** (e.g. GitHub's
Agent Finder, Hugging Face Discover, or one from their `agent-finders.json`). If
they give an ARD service *base* URL (a version root like `https://host/api/v1`),
derive the endpoints from it: append `/search` to search, `/mcp` for its MCP
endpoint.

## 2. Query it

Send the user's task as an ARD `query` object. Use whatever HTTP capability you
have (in a terminal, `curl`):

```bash
curl -s https://ard-catalog.salmonisland-bb7131ca.swedencentral.azurecontainerapps.io/api/v1/search \
  -H 'Content-Type: application/json' \
  -d '{"query":{"text":"<the user's task, in plain language>"}}'
```

- The body is the ARD spec shape: a `query` object with a `text` field. Add an
  optional `query.filter` (e.g. `{"type":["application/mcp-server-card+json"]}`)
  to narrow by resource type, and `"pageSize": <n>` to cap results.

## 3. Present the results

The response is `{ "results": [ ... ] }`. Each result has `displayName`,
`type` (the resource media type, e.g. `application/mcp-server-card+json`), `url`,
`identifier`, and a relevance `score`. Show a numbered list — for each:
**displayName**, the type, the `url`, and the `score`. State that the score is
relevance only — not a trust or safety rating.

## 4. Never auto-install

Do not add, enable, connect, or install any returned resource yourself.
Installation is always the user's explicit choice.

## 5. Install only on request

Once the user picks a result, show them how to add **that** resource using its
`url`:

- `application/mcp-server-card+json` — add it as an MCP server (a `.vscode/mcp.json`
  or `.copilot/mcp-config.json` entry, or your client's "add MCP server" flow),
  pointed at the resource's `url`.
- `text/markdown; profile="urn:air:agent-skills"` — install the skill from its `url`.
- otherwise — connect to it at its `url` over its own protocol.

Then stop and let the user act.

## Installation

**GitHub Copilot** — this `ard-catalog/` folder lives under a directory Copilot
scans: `.github/skills/` (project, committed here) or `~/.copilot/skills/`
(personal). Copilot also reads `~/.claude/skills/`, so a copy there is picked up
too.

```
cp -r .github/skills/ard-catalog ~/.copilot/skills/
```

Then invoke `/ard-catalog <query>`.

> This skill is vendored from the official
> [`ards-project/ard-connectors`](https://github.com/ards-project/ard-connectors)
> `skills/github-copilot/SKILL.md`. Deviations from upstream: the skill is renamed
> to `ard-catalog` (to avoid colliding with any public `agentfinder` skill), and
> the built-in Agent Finder endpoint points at the private Contoso ARD catalog
> instead of GitHub's public Agent Finder.
