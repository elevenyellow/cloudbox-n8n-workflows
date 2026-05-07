# ADR-003: Mac as Primary Development Environment

**Status**: Accepted  
**Date**: 2026-05-07  
**Deciders**: orlando

## Context

Workflow development can happen in two environments:
- **Mac** (local development machine)
- **Server** (cloudbox VM via SSH)

Both have access to n8n:
- Mac → Tailscale → `https://n8n.rola.dev`
- Server → localhost → `http://127.0.0.1:5678`

We need to decide where the primary development happens.

## Decision

Use Mac as the primary development environment, with server as secondary.

## Rationale

**Better developer experience**:
- Familiar editor (VS Code, Cursor, etc.)
- Better terminal (iTerm2, tmux locally)
- Faster feedback loop (no SSH latency for file edits)
- Easier to use n8n-mcp (runs locally, connects via Tailscale)

**n8n-mcp via Tailscale is acceptable**:
- Latency: ~20-50ms (Tailscale peer-to-peer)
- n8n API calls are not realtime-critical
- MCP tools (search nodes, list workflows) are fast enough
- Workflow deployment is one-time operation (latency acceptable)

**Easier git workflow**:
- Clone repo locally: `~/sdk/projects/cloudbox-n8n-workflows/`
- Edit files in preferred editor
- Commit and push from Mac
- No need to SSH into server for every edit

**Server still useful for**:
- Production deployment (if Mac offline)
- Debugging server-side issues
- Running workflows that need server context

## Alternatives Considered

### Option A: Server-only development

**Workflow**:
1. SSH into cloudbox
2. Edit files in vim/nano
3. Deploy from server (localhost API)

**Rejected because**:
- Less comfortable editor (vim vs VS Code)
- SSH latency for every keystroke
- Harder to use n8n-mcp (would need to run on server)
- More complex git workflow (SSH keys, git config on server)

**When it's better**: If Mac is offline or Tailscale unavailable.

### Option B: Hybrid (equal weight)

**Workflow**: Develop on Mac sometimes, server sometimes.

**Rejected because**:
- Confusing (which environment is source of truth?)
- Git conflicts (if editing in both places)
- Harder to document ("it depends")

**When it's better**: If collaborating with someone who prefers server.

## Consequences

**Positive**:
- ✅ Better developer experience (familiar tools)
- ✅ Faster feedback loop (no SSH latency for edits)
- ✅ Easier to use n8n-mcp (runs locally)
- ✅ Simpler git workflow (clone locally, push from Mac)

**Negative**:
- ❌ Requires Tailscale connection (can't develop offline)
- ❌ n8n API calls have ~20-50ms latency (vs localhost)
- ❌ If Mac dies, must switch to server (less comfortable)

**Mitigation**:
- Keep Tailscale running (auto-start on Mac)
- Document server workflow in runbook (for fallback)
- Latency is acceptable for non-realtime use

**Neutral**:
- Server still available for production deployment
- Both environments have access to same n8n instance
- Workflows deployed to n8n (not tied to development environment)

## Related Decisions

- ADR-001: Separate repo (easier to clone locally on Mac)
- ADR-004: npx MCP (runs on Mac, connects via Tailscale)

## Validation

Test n8n-mcp latency from Mac:

```bash
# Time a simple API call
time curl -H "X-N8N-API-KEY: $N8N_API_KEY" https://n8n.rola.dev/api/v1/workflows
```

Expected: < 100ms (acceptable for development).

If latency > 500ms consistently, reconsider server-primary approach.
