# Runbook: Deploying a Workflow

How to deploy a workflow from JSON to n8n.

## Prerequisites

- [ ] n8n API enabled (`enable-n8n-api` change complete)
- [ ] API key generated and stored in `.env`
- [ ] Tailscale connected
- [ ] Workflow JSON created in `workflows/<name>/workflow.json`
- [ ] Workflow tested in n8n UI (import JSON, execute manually)

## Steps

### 1. Create Workflow JSON

**Option A: Create in n8n UI, export to JSON**

1. Open n8n UI: `https://n8n.rola.dev`
2. Create workflow visually (drag nodes, connect)
3. Test execution (click "Execute Workflow")
4. Export: Workflow menu → Download → JSON
5. Save to `workflows/<name>/workflow.json`

**Option B: Write JSON manually (advanced)**

1. Create `workflows/<name>/workflow.json`
2. Use n8n-mcp to assist: "Create a workflow with HTTP Request node"
3. Validate JSON structure (see example below)

**Example workflow.json**:
```json
{
  "name": "Example Workflow",
  "nodes": [
    {
      "parameters": {},
      "name": "Manual Trigger",
      "type": "n8n-nodes-base.manualTrigger",
      "typeVersion": 1,
      "position": [250, 300]
    }
  ],
  "connections": {},
  "active": false,
  "settings": {},
  "tags": ["example"]
}
```

### 2. Create README.md

Document the workflow:

```markdown
# Workflow: <Name>

**Purpose**: <1-2 sentence description>

**Trigger**: <Manual | Webhook | Schedule | etc.>

**Nodes**:
- <Node 1>: <purpose>
- <Node 2>: <purpose>

**Credentials Required**:
- <Credential name>: <type>

**Deployment**:
\`\`\`bash
./scripts/deploy-workflow.sh workflows/<name>/workflow.json
\`\`\`

**Testing**:
1. <Step 1>
2. <Step 2>
```

### 3. Test in n8n UI (Critical)

**Never deploy untested workflows.**

1. Import JSON to n8n UI:
   - Workflows → Import from File → Select `workflow.json`
2. Execute manually:
   - Click "Execute Workflow"
   - Verify output matches expected
3. Check for errors:
   - Red nodes = errors (fix before deploying)
   - Missing credentials = add in n8n UI first
4. Delete test workflow:
   - Workflow menu → Delete (we'll deploy via API)

### 4. Deploy via Script

```bash
cd ~/sdk/projects/cloudbox-n8n-workflows
source .env
./scripts/deploy-workflow.sh workflows/<name>/workflow.json
```

**Expected output**:
```
Deploying workflow: workflows/<name>/workflow.json
API endpoint: https://n8n.rola.dev/api/v1/workflows
✅ Deployed successfully!
   ID: 42
   Name: Example Workflow
   URL: https://n8n.rola.dev/workflow/42
```

### 5. Verify in n8n UI

1. Open n8n UI: `https://n8n.rola.dev`
2. Find workflow by name
3. Verify nodes match JSON
4. Execute workflow (test again)
5. Activate if needed: Toggle "Active" switch

### 6. Commit to Git

```bash
git add workflows/<name>/
git commit -m "feat(workflows): add <name>

Purpose: <1-sentence description>

Nodes: <list key nodes>
Trigger: <trigger type>
Credentials: <list required credentials>

Deployed to: https://n8n.rola.dev/workflow/<id>"

git push origin main
```

## Troubleshooting

### Deployment fails with 401 Unauthorized

**Cause**: API key invalid or missing.

**Fix**:
1. Check `.env` has `N8N_API_KEY`
2. Verify key format: `n8n_api_<32-chars>`
3. Test key: `curl -H "X-N8N-API-KEY: $N8N_API_KEY" https://n8n.rola.dev/api/v1/workflows`
4. If still fails, regenerate key in n8n UI

### Deployment fails with 403 Forbidden

**Cause**: Request not from Tailscale IP.

**Fix**:
1. Check Tailscale connected: `tailscale status`
2. Verify n8n accessible: `curl https://n8n.rola.dev` (should return 200)
3. If not connected, start Tailscale

### Deployment fails with 400 Bad Request

**Cause**: Invalid workflow JSON.

**Fix**:
1. Validate JSON syntax: `jq . workflows/<name>/workflow.json`
2. Check required fields: `name`, `nodes`, `connections`
3. Test import in n8n UI (will show specific error)

### Workflow deploys but doesn't execute

**Cause**: Missing credentials or incorrect node configuration.

**Fix**:
1. Open workflow in n8n UI
2. Check for red nodes (errors)
3. Add missing credentials in n8n UI: Settings → Credentials
4. Update workflow if needed, re-export to JSON

### Workflow executes but produces wrong output

**Cause**: Logic error in workflow.

**Fix**:
1. Debug in n8n UI (execute step-by-step)
2. Check node parameters (typos, wrong values)
3. Fix in UI, re-export to JSON
4. Commit updated JSON to git

## Best Practices

- ✅ **Always test in UI before deploying** (import JSON, execute manually)
- ✅ **Document credentials in README.md** (don't commit credential values)
- ✅ **Use descriptive workflow names** (e.g., "Telegram Bot: Daily Summary")
- ✅ **Tag workflows** (e.g., `["telegram", "ai", "production"]`)
- ✅ **Set `active: false` initially** (activate in UI after testing)
- ✅ **Commit workflow + README together** (atomic change)
- ❌ **Never deploy untested workflows** (can break production)
- ❌ **Never commit credentials inline** (reference by name)
- ❌ **Never skip README.md** (future you will thank you)

## Related Runbooks

- [Exporting a Workflow](exporting-a-workflow.md) — export from n8n UI to JSON
- [Credential Management](credential-management.md) — managing credentials in n8n
