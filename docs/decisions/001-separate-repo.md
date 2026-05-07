# ADR-001: Separate Repository for Workflows

**Status**: Accepted  
**Date**: 2026-05-07  
**Deciders**: orlando

## Context

n8n workflows need version control, but we must decide where to store them:
- Inside `cloudbox/` repository (monorepo approach)
- Separate `cloudbox-n8n-workflows/` repository

The `cloudbox/` repo contains infrastructure code (Tofu, Ansible) that manages the n8n platform. Workflows are content that runs on that platform.

## Decision

Create a separate repository `cloudbox-n8n-workflows` for workflow development.

## Rationale

**Separation of concerns**:
- `cloudbox/` = platform (infrastructure as code)
- `cloudbox-n8n-workflows/` = content (workflows)
- `services/n8n/data/` = state (runtime database)

**Avoids conflicts**:
- Ansible manages `services/n8n/` directory
- Workflows in `services/n8n/workflows/` would conflict with Ansible
- Separate repo avoids file ownership issues

**Independent versioning**:
- Infrastructure changes (Ansible roles, Tofu resources) have different cadence than workflow changes
- Separate repos allow independent release cycles
- Easier to track "what changed" (platform vs content)

**Clearer boundaries**:
- Infrastructure team (if expanded) works in `cloudbox/`
- Workflow developers work in `cloudbox-n8n-workflows/`
- No accidental infrastructure changes when modifying workflows

## Alternatives Considered

### Option A: Monorepo (workflows inside `cloudbox/`)

**Structure**:
```
cloudbox/
├── infra/
├── services/
│   └── n8n/
│       └── workflows/  # Workflows here
```

**Rejected because**:
- Ansible manages `services/n8n/` (file ownership conflicts)
- Infrastructure changes pollute workflow git history
- Harder to grant workflow-only access (if collaborating)

### Option B: Workflows in `services/n8n/data/` (database only)

**Structure**: No git versioning, workflows only in n8n's SQLite database.

**Rejected because**:
- No version control for workflow logic
- No code review for workflow changes
- Harder to restore specific workflow versions
- Can't use n8n-mcp for AI-assisted development (needs JSON files)

## Consequences

**Positive**:
- ✅ Clean separation of platform and content
- ✅ Independent versioning and release cycles
- ✅ No Ansible/workflow file conflicts
- ✅ Easier to collaborate (workflow-only access possible)
- ✅ Clearer git history (infrastructure vs workflow changes)

**Negative**:
- ❌ Two repositories to manage (more overhead)
- ❌ Secrets duplicated (`.env` in both repos)
- ❌ Must coordinate platform upgrades with workflow compatibility

**Neutral**:
- Both repos backed up (git + Restic)
- Both repos follow OpenSpec workflow
- Both repos use conventional commits

## Related Decisions

- ADR-002: JSON format (native n8n format, works with separate repo)
- ADR-003: Mac primary development (separate repo easier to clone locally)
