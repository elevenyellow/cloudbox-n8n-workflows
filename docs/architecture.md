# Architecture: cloudbox-n8n-workflows

## Purpose

Git repository for n8n workflow development, version control, and deployment.

**Goal**: Treat workflows as code — version controlled, reviewed, deployed programmatically.

## Separation of Concerns

| Concern | Location | Purpose | Backed Up By |
|---------|----------|---------|--------------|
| **Platform runtime** | `cloudbox/` | Infrastructure as Code (Tofu, Ansible, n8n container) | Git + Restic |
| **Workflow content** | `cloudbox-n8n-workflows/` | Workflow JSON, deployment scripts, docs | Git |
| **Workflow state** | `services/n8n/data/` | SQLite DB (execution history, credentials) | Restic |

**Why separate repos?**
- Avoids Ansible/workflow file conflicts
- Independent versioning (platform vs content)
- Clearer git history (infrastructure vs workflow changes)
- See [ADR-001](decisions/001-separate-repo.md) for details

## Repository Structure

```
cloudbox-n8n-workflows/
├── Configuration
│   ├── opencode.json       # 5 OpenCode modes (explore, plan, build, deploy, archive)
│   ├── .mcp.json           # n8n-mcp server config (npx, API URL, API key)
│   ├── .env.example        # Secret templates (N8N_API_URL, N8N_API_KEY)
│   └── .gitignore          # Ignore .env, node_modules
│
├── OpenSpec Workflow
│   └── openspec/
│       ├── config.yaml     # OpenSpec settings (modes, conventions)
│       ├── changes/        # Change proposals (new workflows)
│       │   └── archive/    # Completed changes
│       └── specs/          # Canonical specs (conventions, patterns)
│           └── conventions/
│               ├── workflow-structure.md
│               ├── credential-naming.md
│               └── deployment-process.md
│
├── Workflows (Content)
│   └── workflows/
│       ├── _example/       # Bootstrap validation workflow
│       │   ├── workflow.json
│       │   └── README.md
│       └── <workflow-name>/
│           ├── workflow.json   # n8n workflow JSON (source of truth)
│           └── README.md       # Purpose, credentials, deployment
│
├── Documentation
│   └── docs/
│       ├── architecture.md     # This file
│       ├── decisions/          # ADRs (4 decisions)
│       │   ├── 001-separate-repo.md
│       │   ├── 002-json-format.md
│       │   ├── 003-mac-primary.md
│       │   └── 004-npx-mcp.md
│       └── runbooks/           # Operational guides
│           ├── deploying-a-workflow.md
│           ├── exporting-a-workflow.md
│           └── credential-management.md
│
└── Automation
    └── scripts/
        ├── deploy-workflow.sh  # Deploy workflow.json via API
        └── export-workflow.sh  # Export workflow from n8n to JSON
```

## Workflow Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  1. CREATE (build mode)                                     │
│  ────────────────────────                                   │
│  • Create workflow.json in workflows/<name>/                │
│  • Use n8n-mcp to assist with node selection                │
│  • Add README.md (purpose, credentials, deployment)         │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  2. TEST (n8n UI)                                           │
│  ──────────────────                                         │
│  • Import JSON to n8n UI (or deploy via script)             │
│  • Execute manually (verify output)                         │
│  • Fix errors (red nodes = problems)                        │
│  • Delete test workflow (will deploy via API)               │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  3. DEPLOY (deploy mode)                                    │
│  ─────────────────────────                                  │
│  • Run ./scripts/deploy-workflow.sh workflows/<name>/...    │
│  • Verify in n8n UI (workflow appears)                      │
│  • Test execution (manual trigger)                          │
│  • Activate if needed (toggle "Active" switch)              │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  4. VERSION (git)                                           │
│  ──────────────────                                         │
│  • Commit workflow.json + README.md                         │
│  • Push to GitHub                                           │
│  • Git history = source of truth for workflow logic         │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  5. UPDATE (if modified in UI)                              │
│  ───────────────────────────────                            │
│  • Export via ./scripts/export-workflow.sh <id> <file>      │
│  • Review changes (git diff)                                │
│  • Commit to git (if changes intentional)                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## OpenCode Modes

| Mode | Purpose | Agent | Writes Code | Tools Used |
|------|---------|-------|-------------|------------|
| `explore` | Investigate n8n nodes, templates, workflows | general | No | n8n-mcp (search, list) |
| `plan` | Create change proposal for new workflow | spec-writer | No (only openspec/) | OpenSpec templates |
| `build` | Implement workflow JSON, test locally | general | Yes (workflows/) | n8n-mcp, editor |
| `deploy` | Deploy to n8n via API, validate | general | No (runs scripts) | deploy-workflow.sh |
| `archive` | Archive change, update specs | general | Yes (openspec/) | Git, editor |

**Workflow**:
1. `explore` — "What nodes does n8n have for Telegram?"
2. `plan` — "Create proposal for Telegram bot workflow"
3. `build` — "Implement workflow JSON with Telegram trigger + OpenAI node"
4. `deploy` — "Deploy workflow to n8n, verify it works"
5. `archive` — "Archive change, update conventions spec"

## n8n-mcp Integration

**Purpose**: AI-assisted workflow creation via Model Context Protocol.

**Configuration** (`.mcp.json`):
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

**Capabilities** (20 MCP tools):
- `search_nodes` — find nodes by keyword (1,650 nodes indexed)
- `get_node_details` — node parameters, examples
- `list_workflows` — fetch all workflows from n8n
- `get_workflow` — fetch workflow JSON by ID
- `create_workflow` — deploy new workflow via API
- `update_workflow` — modify existing workflow
- `delete_workflow` — remove workflow
- `search_templates` — browse n8n.io templates (2,352 available)
- `get_template` — fetch template JSON
- And more...

**Access**:
- Runs on Mac (primary development environment)
- Connects to n8n via Tailscale (`https://n8n.rola.dev/api/v1`)
- Latency: ~20-50ms (acceptable for non-realtime use)

**See**: [ADR-004](decisions/004-npx-mcp.md) for rationale.

## Workflow Conventions

### Directory Structure

One directory per workflow:
```
workflows/<workflow-name>/
├── workflow.json    # n8n workflow JSON (required)
└── README.md        # Documentation (required)
```

### workflow.json

- **Format**: n8n native JSON (not TypeScript)
- **Source of truth**: Git (not n8n database)
- **Credentials**: Referenced by name (not inline)
- **Tags**: Include descriptive tags (e.g., `["telegram", "ai", "production"]`)
- **Active**: Set to `false` initially (activate in UI after testing)

**See**: [ADR-002](decisions/002-json-format.md) for rationale.

### README.md

Required sections:
- **Purpose**: 1-2 sentence description
- **Trigger**: Manual, Webhook, Schedule, etc.
- **Nodes**: List of nodes and their purpose
- **Credentials Required**: List of credentials (by name, not value)
- **Deployment**: Command to deploy
- **Testing**: Steps to verify workflow works

## Credential Management

**Storage**:
- Credentials stored in n8n's database (encrypted with `N8N_ENCRYPTION_KEY`)
- Workflows reference credentials by **name** (not inline)
- Credentials **never** committed to git

**Naming convention**:
- `<Service>: <Purpose>` (e.g., "Telegram Bot: Personal", "OpenAI API: GPT-4")

**Rotation**:
- Update credential in n8n UI
- Workflows auto-use new credential (referenced by name)
- No workflow JSON changes needed

**See**: [Credential Management Runbook](runbooks/credential-management.md) for details.

## Deployment

### Via Script (Recommended)

```bash
./scripts/deploy-workflow.sh workflows/<name>/workflow.json
```

**Script behavior**:
- Validates workflow.json exists
- Loads `N8N_API_KEY` from `.env`
- POSTs to n8n API (`https://n8n.rola.dev/api/v1/workflows`)
- Reports workflow ID and URL
- Exits 0 on success, 1 on failure

### Manual (Not Recommended)

```bash
curl -X POST \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @workflows/<name>/workflow.json \
  https://n8n.rola.dev/api/v1/workflows
```

**Why script is better**: Consistent error handling, validates input, reports URL.

## Backup Strategy

### Git (Workflow Logic)

- **Source of truth**: workflow.json in git
- **History**: All workflow changes versioned
- **Recovery**: `git checkout <commit>` to restore old version

### Restic (Runtime State)

- **Backs up**: `services/n8n/data/` (includes all workflows + credentials)
- **Frequency**: Daily at 2:00 AM
- **Retention**: 7 daily, 4 weekly, 12 monthly

### Relationship

- **Git** = source of truth for workflow **logic** (nodes, connections, parameters)
- **Restic** = backup of workflow **state** (execution history, credentials, active status)

**Recovery scenario**:
1. Server dies, n8n data lost
2. Restore platform via `cloudbox/` (Tofu + Ansible)
3. Restore n8n data via Restic (includes credentials)
4. Re-deploy workflows from git (if needed): `./scripts/deploy-workflow.sh workflows/*/workflow.json`

## Secrets Management

**Never commit**:
- `.env` (contains `N8N_API_KEY`)
- Credential values (API tokens, passwords)
- SSH private keys

**Always commit**:
- `.env.example` (template with placeholders)
- workflow.json (credentials referenced by name, not inline)
- README.md (documents required credentials, not values)

**`.gitignore` includes**:
```
.env
node_modules/
.DS_Store
```

## Development Environment

**Primary**: Mac (local development)
- Clone repo: `~/sdk/projects/cloudbox-n8n-workflows/`
- Edit files in VS Code/Cursor
- n8n-mcp runs locally, connects via Tailscale
- Deploy via script (API calls via Tailscale)

**Secondary**: Server (cloudbox VM)
- Fallback if Mac offline
- Less comfortable (vim vs VS Code)
- Localhost API (no Tailscale latency)

**See**: [ADR-003](decisions/003-mac-primary.md) for rationale.

## Future Enhancements

- **CI/CD**: GitHub Actions to validate workflow JSON on PR
- **Linting**: JSON schema validation for workflow.json
- **Testing**: Automated workflow execution tests
- **Templates**: Starter templates for common patterns (webhook, schedule, AI)
- **Monitoring**: n8n workflow to monitor other workflows, alert via Telegram

## Related Documentation

- **cloudbox repo**: `cloudbox/openspec/specs/n8n/spec.md` (n8n platform runtime)
- **ADRs**: `docs/decisions/` (4 architecture decisions)
- **Runbooks**: `docs/runbooks/` (3 operational guides)
- **OpenSpec**: `openspec/config.yaml` (workflow conventions)
