# ADR-002: JSON Format for Workflows

**Status**: Accepted  
**Date**: 2026-05-07  
**Deciders**: orlando

## Context

n8n workflows can be represented in multiple formats:
- **JSON** (n8n's native export format)
- **TypeScript** (using n8n-workflow-builder or similar)
- **YAML** (custom abstraction)

We need a format that:
- Works with n8n API (for deployment)
- Works with n8n-mcp (for AI assistance)
- Is human-readable (for code review)
- Requires minimal tooling (no complex build steps)

## Decision

Use JSON as the native format for workflows.

## Rationale

**n8n native format**:
- JSON is n8n's export format (UI → Export → JSON)
- n8n API accepts JSON directly (no conversion needed)
- No impedance mismatch between storage and deployment

**n8n-mcp compatibility**:
- n8n-mcp works with JSON workflows
- Can create/update workflows via MCP tools
- AI can read and modify JSON directly

**Simpler tooling**:
- No build step (JSON → JSON)
- No transpilation (TypeScript → JSON)
- No custom parser (YAML → JSON)
- Just `curl` or `deploy-workflow.sh` to deploy

**Human-readable**:
- JSON is widely understood
- Syntax highlighting in all editors
- Diff-friendly (git shows node changes clearly)

## Alternatives Considered

### Option A: TypeScript (n8n-workflow-builder)

**Example**:
```typescript
import { Workflow, ManualTrigger, Set } from 'n8n-workflow-builder';

const workflow = new Workflow('Hello World')
  .addNode(new ManualTrigger())
  .addNode(new Set({ message: 'Hello!' }));

export default workflow.build();
```

**Rejected because**:
- Requires build step (TypeScript → JSON)
- Requires Node.js tooling (tsc, bundler)
- n8n-mcp doesn't work with TypeScript (expects JSON)
- More complex for simple workflows
- Adds dependency on third-party library

**When it's better**: Large, complex workflows with lots of reusable logic.

### Option B: YAML (custom abstraction)

**Example**:
```yaml
name: Hello World
nodes:
  - type: manualTrigger
    name: Start
  - type: set
    name: Set Message
    parameters:
      message: Hello!
connections:
  - from: Start
    to: Set Message
```

**Rejected because**:
- Requires custom parser (YAML → n8n JSON)
- n8n-mcp doesn't work with YAML
- Adds abstraction layer (harder to debug)
- Not n8n's native format (impedance mismatch)

**When it's better**: If we had many workflows with similar structure (templates).

## Consequences

**Positive**:
- ✅ No build step (JSON is deployment-ready)
- ✅ Works with n8n-mcp out of the box
- ✅ Works with n8n API directly
- ✅ Easy to export from UI (Export → JSON → commit)
- ✅ Diff-friendly (git shows node changes)

**Negative**:
- ❌ Hand-editing JSON is tedious (verbose, easy to break)
- ❌ No type safety (typos in node names, parameters)
- ❌ No code reuse (can't extract common patterns easily)

**Mitigation**:
- Use n8n UI for initial creation (visual editor)
- Export to JSON, commit to git
- Use n8n-mcp for AI-assisted modifications
- For complex workflows, create in UI first, then version in git

**Neutral**:
- JSON is verbose, but workflows are typically small (< 20 nodes)
- Can add JSON schema validation later (lint workflow.json)

## Related Decisions

- ADR-001: Separate repo (JSON files easier to manage in dedicated repo)
- ADR-004: npx MCP (n8n-mcp expects JSON workflows)

## Future Considerations

If workflows become very complex (> 50 nodes, lots of reuse):
- Consider TypeScript builder for those specific workflows
- Keep simple workflows in JSON
- Hybrid approach: JSON for simple, TypeScript for complex
