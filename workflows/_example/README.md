# Workflow: Example Hello World

**Purpose**: Validate deployment flow from JSON to n8n. Bootstrap test workflow.

**Trigger**: Manual (click "Execute Workflow" in n8n UI)

**Nodes**:
- **Manual Trigger**: Starts workflow on demand (no configuration)
- **Set Message**: Adds three fields to output:
  - `message`: Static string "Hello from cloudbox-n8n-workflows!"
  - `timestamp`: Current ISO timestamp
  - `environment`: Static string "cloudbox"

**Credentials Required**: None

**Deployment**:

```bash
cd ~/sdk/projects/cloudbox-n8n-workflows
source .env
./scripts/deploy-workflow.sh workflows/_example/workflow.json
```

**Expected output**:
```
Deploying workflow: workflows/_example/workflow.json
API endpoint: https://n8n.rola.dev/api/v1/workflows
✅ Deployed successfully!
   ID: 1
   Name: Example: Hello World
   URL: https://n8n.rola.dev/workflow/1
```

**Testing**:

1. Open n8n UI: `https://n8n.rola.dev`
2. Find workflow "Example: Hello World"
3. Click "Execute Workflow"
4. Verify output contains:
   ```json
   {
     "message": "Hello from cloudbox-n8n-workflows!",
     "timestamp": "2026-05-07T...",
     "environment": "cloudbox"
   }
   ```
5. All nodes should have green checkmarks (success)

**Notes**:

- This workflow has no external dependencies (no API calls, no credentials)
- Safe to run repeatedly (idempotent)
- Used to validate:
  - Deployment script works
  - n8n API accepts JSON
  - Workflow appears in UI
  - Workflow executes successfully
- Can be deleted after bootstrap validation complete
