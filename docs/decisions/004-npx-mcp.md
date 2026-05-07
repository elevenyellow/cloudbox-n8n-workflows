# ADR-004: npx for n8n-mcp

**Status**: Accepted  
**Date**: 2026-05-07  
**Deciders**: orlando

## Context

n8n-mcp (Model Context Protocol server for n8n) can be run in multiple ways:
- **npx** (on-demand execution, pinned version)
- **Docker** (containerized, isolated)
- **Global npm install** (persistent, system-wide)
- **SaaS n8n** (cloud-hosted, not self-hosted)

We need a way to run n8n-mcp that:
- Works with self-hosted n8n (cloudbox)
- Is easy to set up (minimal dependencies)
- Has reproducible versions (pinned)
- Works on Mac (primary development environment)

## Decision

Use `npx n8n-mcp@1.0.0` (on-demand execution with pinned version).

## Rationale

**Pinned version**:
- `npx -y n8n-mcp@1.0.0` ensures consistent behavior
- No "works on my machine" issues (version locked)
- Easy to upgrade: change version in `.mcp.json`

**No Docker complexity**:
- No Dockerfile to maintain
- No container networking (n8n-mcp connects to n8n via Tailscale)
- Simpler setup (just Node.js, no Docker Desktop)

**On-demand execution**:
- npx downloads and caches on first run
- Subsequent runs use cached version
- No global install pollution (`npm install -g`)

**Works with self-hosted n8n**:
- n8n-mcp connects to `https://n8n.rola.dev/api/v1` (via Tailscale)
- Not tied to SaaS n8n (cloud.n8n.io)
- Full control over n8n instance

## Alternatives Considered

### Option A: Docker

**Configuration**:
```yaml
# docker-compose.yml
services:
  n8n-mcp:
    image: n8n-mcp:1.0.0
    environment:
      N8N_API_URL: https://n8n.rola.dev/api/v1
      N8N_API_KEY: ${N8N_API_KEY}
```

**Rejected because**:
- Requires Docker Desktop on Mac
- Requires Dockerfile (more maintenance)
- Container networking complexity (Tailscale inside container?)
- Overkill for a simple Node.js CLI tool

**When it's better**: If running on a server without Node.js.

### Option B: Global npm install

**Command**: `npm install -g n8n-mcp@1.0.0`

**Rejected because**:
- Pollutes global npm namespace
- Harder to pin version (must remember to specify `@1.0.0`)
- Conflicts if multiple projects need different versions
- npx is more idiomatic for CLI tools

**When it's better**: If running n8n-mcp frequently (avoids npx startup delay).

### Option C: SaaS n8n (cloud.n8n.io)

**Rejected because**:
- We're self-hosting n8n (cloudbox)
- SaaS costs money (self-hosted is free)
- Less control over data and backups
- Not the architecture we chose (see cloudbox ADRs)

**When it's better**: If not self-hosting infrastructure.

## Consequences

**Positive**:
- ✅ Pinned version (reproducible)
- ✅ No Docker complexity
- ✅ No global install pollution
- ✅ Works with self-hosted n8n
- ✅ Easy to upgrade (change version in `.mcp.json`)

**Negative**:
- ❌ Requires Node.js on Mac (but already installed)
- ❌ First run downloads package (slight delay)
- ❌ npx startup overhead (~100ms, acceptable)

**Mitigation**:
- Node.js already installed on Mac (via mise or nvm)
- npx caches package after first run (subsequent runs fast)
- Startup overhead acceptable for non-realtime use

**Neutral**:
- n8n-mcp is a CLI tool (not a long-running service)
- Spawned on-demand by Claude/OpenCode (not persistent)

## Configuration

**File**: `.mcp.json`

```json
{
  "mcpServers": {
    "n8n": {
      "command": "npx",
      "args": ["-y", "n8n-mcp@1.0.0"],
      "env": {
        "N8N_API_URL": "https://n8n.rola.dev/api/v1",
        "N8N_API_KEY": "${N8N_API_KEY}"
      }
    }
  }
}
```

**Upgrading**:
1. Check n8n-mcp releases: https://github.com/czlonkowski/n8n-mcp/releases
2. Update version in `.mcp.json`: `"n8n-mcp@1.1.0"`
3. Test: restart Claude/OpenCode, verify MCP tools work
4. Commit: `chore(mcp): upgrade n8n-mcp to 1.1.0`

## Related Decisions

- ADR-001: Separate repo (n8n-mcp config in dedicated repo)
- ADR-002: JSON format (n8n-mcp works with JSON workflows)
- ADR-003: Mac primary (npx runs on Mac, connects via Tailscale)

## Validation

Test n8n-mcp works:

```bash
# Set API key
export N8N_API_URL=https://n8n.rola.dev/api/v1
export N8N_API_KEY=<your-key>

# Run n8n-mcp (should start MCP server)
npx -y n8n-mcp@1.0.0
```

Expected: MCP server starts, no errors.

In Claude/OpenCode: "List all n8n workflows" should return JSON array.
