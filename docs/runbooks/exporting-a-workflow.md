# Runbook: Exporting a Workflow

How to export a workflow from n8n to JSON (for version control).

## When to Export

- **After creating in UI**: Workflow created visually, need to version in git
- **After modifying in UI**: Workflow updated in n8n, need to sync to git
- **Before major changes**: Backup current version before experimenting

## Prerequisites

- [ ] Workflow exists in n8n UI
- [ ] Workflow ID known (from URL: `/workflow/<id>`)
- [ ] API key in `.env`
- [ ] Tailscale connected

## Steps

### 1. Find Workflow ID

**Option A: From n8n UI URL**

1. Open workflow in n8n UI
2. Check URL: `https://n8n.rola.dev/workflow/42`
3. Workflow ID = `42`

**Option B: List all workflows**

```bash
source .env
curl -H "X-N8N-API-KEY: $N8N_API_KEY" https://n8n.rola.dev/api/v1/workflows | jq '.[] | {id, name}'
```

Output:
```json
{
  "id": "42",
  "name": "Example Workflow"
}
```

### 2. Export via Script

```bash
cd ~/sdk/projects/cloudbox-n8n-workflows
source .env
./scripts/export-workflow.sh 42 workflows/example/workflow.json
```

**Expected output**:
```
Exporting workflow ID: 42
Output file: workflows/example/workflow.json
✅ Exported successfully!
   Name: Example Workflow
   File: workflows/example/workflow.json
```

### 3. Review Changes

If workflow already exists in git:

```bash
git diff workflows/example/workflow.json
```

**Review**:
- Are changes intentional?
- Any credentials accidentally inline? (should be referenced by name)
- Any sensitive data? (remove before committing)

### 4. Update README.md

If workflow logic changed, update README.md:

```markdown
# Workflow: Example

**Purpose**: <updated description>

**Nodes**:
- <updated node list>

**Credentials Required**:
- <updated credential list>
```

### 5. Commit to Git

```bash
git add workflows/example/
git commit -m "feat(workflows): update example workflow

Changes:
- <describe what changed>
- <why it changed>

Exported from: https://n8n.rola.dev/workflow/42"

git push origin main
```

## Manual Export (Alternative)

If script unavailable, export manually via API:

```bash
source .env
curl -H "X-N8N-API-KEY: $N8N_API_KEY" \
  https://n8n.rola.dev/api/v1/workflows/42 \
  | jq '.' > workflows/example/workflow.json
```

Or via n8n UI:

1. Open workflow in n8n UI
2. Workflow menu → Download → JSON
3. Save to `workflows/example/workflow.json`
4. Commit to git

## Troubleshooting

### Export fails with 401 Unauthorized

**Cause**: API key invalid or missing.

**Fix**:
1. Check `.env` has `N8N_API_KEY`
2. Test key: `curl -H "X-N8N-API-KEY: $N8N_API_KEY" https://n8n.rola.dev/api/v1/workflows`
3. If fails, regenerate key in n8n UI

### Export fails with 404 Not Found

**Cause**: Workflow ID doesn't exist.

**Fix**:
1. List all workflows: `curl -H "X-N8N-API-KEY: $N8N_API_KEY" https://n8n.rola.dev/api/v1/workflows`
2. Verify workflow ID
3. Check workflow not deleted in UI

### Exported JSON has credentials inline

**Cause**: Workflow has credentials embedded (bad practice).

**Fix**:
1. In n8n UI, edit workflow
2. Replace inline credentials with credential references:
   - Node settings → Credentials → Select existing credential
3. Re-export to JSON
4. Verify: `grep -i "password\|token\|key" workflows/example/workflow.json` (should be empty)

### Git diff shows massive changes

**Cause**: n8n added metadata (timestamps, IDs, etc.).

**Fix**:
- Review carefully (are functional changes intentional?)
- If only metadata changed, consider not committing
- If functional changes, commit with clear message

## Best Practices

- ✅ **Export after every UI modification** (keep git in sync)
- ✅ **Review diff before committing** (catch accidental changes)
- ✅ **Update README.md if logic changed** (document what and why)
- ✅ **Use script over manual export** (consistent, automated)
- ✅ **Check for inline credentials** (should be referenced by name)
- ❌ **Never commit credentials inline** (security risk)
- ❌ **Never skip git review** (git diff before commit)
- ❌ **Never export without testing** (ensure workflow works in UI first)

## Workflow Sync Strategy

**Git = source of truth for logic**:
- Workflow JSON in git represents intended state
- Deploy from git to n8n via `deploy-workflow.sh`

**n8n = runtime state**:
- Execution history, credentials, active status
- Backed up by Restic (not git)

**When to export**:
- After creating workflow in UI (initial version)
- After modifying workflow in UI (sync changes to git)
- Before major refactoring (backup current version)

**When NOT to export**:
- After every execution (execution history not versioned)
- After activating/deactivating (active status not versioned)
- After credential rotation (credentials not in JSON)

## Related Runbooks

- [Deploying a Workflow](deploying-a-workflow.md) — deploy JSON to n8n
- [Credential Management](credential-management.md) — managing credentials
