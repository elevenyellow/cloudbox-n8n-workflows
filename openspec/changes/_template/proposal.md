# Proposal: <Workflow Name or Change Title>

## Status

**Proposed** — awaiting review

## Problem

<What manual task, gap, or pain point motivates this workflow? One short paragraph. If this replaces or modifies an existing workflow, link to it: `workflows/<existing>/`.>

## Proposed Solution

Add an n8n workflow at `workflows/<workflow-name>/` that:

- **Trigger**: <Manual | Webhook | Schedule (cron) | App event (Telegram/Gmail/etc.)>
- **Action**: <one-sentence description of what it does on each run>
- **Output**: <where the result lands — Slack message, DB row, file, downstream webhook, …>

## Scope

### In Scope

- `workflows/<workflow-name>/workflow.json` (n8n native JSON, `active: false` initially)
- `workflows/<workflow-name>/README.md` (purpose, trigger, nodes, credentials, deployment, testing)
- New credentials in n8n (referenced by name from the JSON, never inline)
- Deployment via `scripts/deploy-workflow.sh`

### Out of Scope

- <e.g. UI changes in n8n beyond credential creation>
- <e.g. modifying unrelated workflows>
- <e.g. infrastructure changes — those go to the `cloudbox/` repo>

## Success Criteria

- [ ] `workflow.json` validates as importable n8n JSON (loads in UI without errors)
- [ ] Manual execution in n8n UI produces the expected output
- [ ] Deployed via `./scripts/deploy-workflow.sh workflows/<workflow-name>/workflow.json`
- [ ] Workflow visible in n8n UI with the right tags
- [ ] README documents every credential the workflow consumes (by name)
- [ ] No secrets or tokens committed to git (grep clean)
- [ ] Workflow activated in UI after end-to-end test passes

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| <Credential rotation breaks workflow> | <Med> | <Reference by name, document in README> |
| <External API rate limit> | <Med> | <Add wait/retry node, document quotas> |
| <Schedule overlap with other workflows> | <Low> | <Stagger cron, document in README> |

## Rollback Plan

1. Deactivate workflow in n8n UI (toggle Active off).
2. Delete workflow via UI or API: `curl -X DELETE -H "X-N8N-API-KEY: $N8N_API_KEY" $N8N_API_URL/workflows/<id>`.
3. `git revert` the commit that added `workflows/<workflow-name>/`.
4. Remove any credentials created exclusively for this workflow from the n8n UI (only if not used elsewhere).

**Time to rollback**: < 5 minutes.

## Alternatives Considered

- **<Manual cron + script>**: Rejected because <reason — no UI, no retry, no execution history>.
- **<Existing workflow X extended>**: Rejected because <reason — different trigger / mixing concerns>.
- **<External SaaS (Zapier/Make)>**: Rejected because <reason — vendor lock-in, cost, secrets in 3rd party>.

## Dependencies

### Pre-requisites (manual, before implementation)

1. Credentials exist in n8n UI under their canonical names: `<Service>: <Purpose>` (e.g. `Telegram Bot: Personal`).
2. Any external resource the workflow targets is reachable from the n8n VM (test via `curl` from the VM if unsure).
3. `.env` has a valid `N8N_API_KEY` for the deploy script.

### Implementation dependencies

- n8n platform running (`cloudbox/` repo, n8n role).
- n8n-mcp available locally for AI-assisted node selection (optional but recommended).

## Estimated Effort

- **Design**: <0.5–1h>
- **Build (workflow.json + README)**: <1–2h>
- **Test (manual run, fix red nodes)**: <0.5–1h>
- **Deploy + verify**: <0.5h>
- **Total**: <2.5–4.5h>

## Related Documentation

- [Architecture](../../../docs/architecture.md) — workflow lifecycle
- [Runbook: Deploying a Workflow](../../../docs/runbooks/deploying-a-workflow.md)
- [Runbook: Credential Management](../../../docs/runbooks/credential-management.md)
- <ADR-### if this change makes a non-obvious architectural decision>
