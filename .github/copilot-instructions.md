# Copilot instructions

## Discovering tools, MCP servers, and skills — check the approved catalog first

When a task needs a capability you do **not** already have available — a
third-party integration or tool such as GitHub, a database, a cloud platform,
CI/CD, payments, monitoring, messaging, file storage, or a similar service — do
**not** hardcode a tool, guess at an MCP server, or give up. **First** use the
**`ard-catalog`** skill (`.github/skills/ard-catalog/`) to search the approved
Contoso ARD catalog for an approved match.

Rules:

- Prefer an **approved** result from the catalog over any un-vetted tool you
  might otherwise reach for.
- The catalog is **discovery only**. Present the ranked results and let the user
  pick. **Never** add, enable, connect, install, or invoke a returned resource on
  your own — installation is always the user's explicit choice.
- The relevance `score` is **not** a trust or safety rating; don't present it as
  one.
- Skip the catalog for purely local work (writing/editing code, git, shell,
  math) — it's only for finding external capabilities.

If the catalog returns nothing useful, say so plainly (that's a signal the
capability may not yet be approved) before considering alternatives.
