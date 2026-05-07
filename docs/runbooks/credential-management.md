# Runbook: Credential Management

How to manage credentials for n8n workflows.

## Overview

**Credentials** are sensitive data used by workflows:
- API tokens (OpenAI, Telegram, etc.)
- Passwords (databases, services)
- SSH keys
- OAuth tokens

**Storage**:
- Credentials stored in n8n's database (encrypted with `N8N_ENCRYPTION_KEY`)
- Workflows reference credentials by **name** (not inline)
- Credentials **never** committed to git

## Creating a Credential

### 1. In n8n UI

1. Open n8n UI: `https://n8n.rola.dev`
2. Navigate to: Profile icon → Settings → Credentials
3. Click "Add Credential"
4. Select credential type (e.g., "Telegram Bot", "HTTP Header Auth", "OpenAI API")
5. Fill in required fields:
   - **Name**: Descriptive name (e.g., "Telegram Bot: Personal", "OpenAI: GPT-4")
   - **Token/Password**: Actual secret value
6. Click "Save"

### 2. Use in Workflow

1. Open workflow in n8n UI
2. Add node that requires credential (e.g., "Telegram" node)
3. In node settings → Credentials → Select existing credential
4. Credential referenced by name (not inline)

**Example** (workflow.json):
```json
{
  "name": "Telegram Bot",
  "type": "n8n-nodes-base.telegram",
  "credentials": {
    "telegramApi": {
      "id": "1",
      "name": "Telegram Bot: Personal"
    }
  }
}
```

**Note**: Credential ID and name are references, not the actual token.

## Listing Credentials

### Via n8n UI

1. Profile icon → Settings → Credentials
2. View all credentials (name, type, last updated)

### Via API

```bash
source .env
curl -H "X-N8N-API-KEY: $N8N_API_KEY" https://n8n.rola.dev/api/v1/credentials | jq '.[] | {id, name, type}'
```

Output:
```json
{
  "id": "1",
  "name": "Telegram Bot: Personal",
  "type": "telegramApi"
}
```

**Note**: API returns metadata only (not actual credential values).

## Updating a Credential

### Rotate Token/Password

1. In n8n UI → Settings → Credentials
2. Find credential by name
3. Click "Edit"
4. Update token/password
5. Click "Save"

**Workflows auto-use new credential** (referenced by name, not value).

### Rename Credential

1. Edit credential in n8n UI
2. Change "Name" field
3. Save

**⚠️ Warning**: If workflows reference old name, they'll break. Update workflows:
1. Open workflow in UI
2. Node settings → Credentials → Select renamed credential
3. Save workflow
4. Export to JSON, commit to git

## Deleting a Credential

1. In n8n UI → Settings → Credentials
2. Find credential by name
3. Click "Delete"
4. Confirm deletion

**⚠️ Warning**: Workflows using this credential will fail. Check usage first:
1. In n8n UI, try to delete credential
2. n8n shows which workflows use it
3. Update workflows to use different credential (or remove nodes)

## Credential Naming Conventions

Use descriptive names that indicate:
- **Service**: What service (Telegram, OpenAI, etc.)
- **Purpose**: What it's for (Bot, API, etc.)
- **Scope**: Personal, Production, Test, etc.

**Good examples**:
- `Telegram Bot: Personal`
- `OpenAI API: GPT-4`
- `HTTP Auth: Example API`
- `PostgreSQL: Production DB`

**Bad examples**:
- `Telegram` (too vague, which bot?)
- `API Key` (which API?)
- `Token 1` (meaningless)

## Documenting Credentials in Workflows

In `workflows/<name>/README.md`, list required credentials:

```markdown
## Credentials Required

- **Telegram Bot: Personal** (type: Telegram Bot)
  - How to obtain: BotFather → /newbot → copy token
  - Scope: Personal Telegram account
  - Rotation: Yearly or on compromise

- **OpenAI API: GPT-4** (type: OpenAI API)
  - How to obtain: platform.openai.com → API Keys → Create
  - Scope: Personal OpenAI account
  - Rotation: Every 90 days
```

**Do NOT include**:
- ❌ Actual token/password values
- ❌ Credential IDs (internal to n8n)

**Do include**:
- ✅ Credential name (as referenced in workflow)
- ✅ Credential type (for recreation)
- ✅ How to obtain (for future reference)
- ✅ Rotation policy

## Backup and Recovery

### Backup

Credentials are backed up by Restic:
- **Path**: `/home/orlando/services/n8n/data/` (includes SQLite DB)
- **Frequency**: Daily at 2:00 AM
- **Encryption**: Restic encrypts backups, n8n encrypts credentials

**Critical**: `N8N_ENCRYPTION_KEY` must be backed up separately (in password manager).

### Recovery

If credentials lost (e.g., server dies):

1. Restore n8n data from Restic:
   ```bash
   restic restore latest --include /home/orlando/services/n8n --target /
   ```

2. Ensure `N8N_ENCRYPTION_KEY` in `.env` matches backed-up key

3. Restart n8n:
   ```bash
   cd /home/orlando/services/n8n
   docker compose restart
   ```

4. Verify credentials in n8n UI: Settings → Credentials

**If encryption key lost**: Credentials are irrecoverable. Must regenerate all manually.

## Credential Rotation

### When to Rotate

| Credential Type | Rotation Frequency | Trigger |
|---|---|---|
| API tokens | Every 90 days | Calendar reminder |
| Passwords | Every 180 days | Calendar reminder |
| OAuth tokens | On expiry | n8n shows error |
| SSH keys | Every 2 years | Calendar reminder |
| **On compromise** | Immediately | Security incident |

### Rotation Process

1. Generate new token/password in service (Telegram, OpenAI, etc.)
2. Update credential in n8n UI: Settings → Credentials → Edit
3. Test workflows: Execute manually, verify no errors
4. Delete old token in service (if applicable)
5. Document rotation in password manager

**Workflows auto-use new credential** (no code changes needed).

## Troubleshooting

### Workflow fails with "Credentials not found"

**Cause**: Credential deleted or renamed.

**Fix**:
1. Check credential exists: n8n UI → Settings → Credentials
2. If missing, recreate with same name
3. If renamed, update workflow to reference new name

### Workflow fails with "Invalid credentials"

**Cause**: Token/password expired or revoked.

**Fix**:
1. Test credential manually (e.g., `curl` with token)
2. If invalid, rotate credential (see above)
3. Re-test workflow

### Can't decrypt credentials after restore

**Cause**: `N8N_ENCRYPTION_KEY` doesn't match backed-up key.

**Fix**:
1. Check `.env` has correct `N8N_ENCRYPTION_KEY`
2. If lost, credentials are irrecoverable (must regenerate)
3. **Prevention**: Store key in password manager outside repo and server

### Credential appears in git diff

**Cause**: Credential accidentally committed inline (not referenced).

**Fix**:
1. **Immediately** remove from git:
   ```bash
   git reset HEAD workflows/<name>/workflow.json
   git checkout workflows/<name>/workflow.json
   ```
2. In n8n UI, replace inline credential with credential reference
3. Re-export workflow to JSON
4. Verify: `grep -i "password\|token\|key" workflows/<name>/workflow.json` (should be empty)
5. Rotate credential (assume compromised)

## Best Practices

- ✅ **Use credential references** (not inline in workflow JSON)
- ✅ **Descriptive names** (service + purpose + scope)
- ✅ **Document in README.md** (how to obtain, rotation policy)
- ✅ **Rotate regularly** (90 days for API tokens)
- ✅ **Backup encryption key** (in password manager)
- ✅ **Test after rotation** (execute workflows manually)
- ❌ **Never commit credentials** (inline or in .env)
- ❌ **Never share credentials** (use separate credentials per person)
- ❌ **Never reuse credentials** (one credential per service)

## Related Runbooks

- [Deploying a Workflow](deploying-a-workflow.md) — workflows reference credentials
- [Exporting a Workflow](exporting-a-workflow.md) — check for inline credentials before committing
