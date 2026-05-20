# Proposal: Research Competitors Workflow

## Status

**Proposed** — awaiting review

## Problem

Competitor research capability currently lives exclusively in the Fragua repo (`research` mode + `find-competitors.md` playbook + Tavily integration). This forces context-switching whenever the need arises to investigate the competitive landscape of an idea while working in another project or from mobile. The playbook is versioned and continuously improved in Fragua, but there's no way to invoke it remotely without opening that repo.

The strategic goal is to **expose the playbook as an executable prompt**: load it dynamically from Fragua and use it as the system prompt for an AI agent, so that when the playbook improves in Fragua, the workflow improves automatically. No duplication, no drift.

## Proposed Solution

Add an n8n workflow at `workflows/research-competitors/` that:

- **Trigger**: Telegram message event on the existing bot (same credential as `telegram-openrouter-chat`), filtered to messages starting with `/competitors`.
- **Action**: On receiving `/competitors <tema>`, fetch the `find-competitors.md` playbook from the private Fragua repo via GitHub raw URL + PAT, inject the tema into a system prompt header, execute the playbook using an AI Agent with Tavily search tool, and return a structured markdown report.
- **Output**: Telegram reply (paginated if >3500 characters per chunk) with competitor analysis including URLs, positioning, audience, pricing, and key features.

## Scope

### In Scope

- `workflows/research-competitors/workflow.json` (n8n native JSON, `active: false` initially).
- `workflows/research-competitors/README.md` (purpose, trigger, nodes, credentials, deployment, testing).
- Two new credentials in n8n UI (referenced by name from JSON, never inline):
  - `Tavily API: Research` — HTTP Header Auth credential for Tavily search.
  - `GitHub PAT: Fragua read` — HTTP Header Auth credential for fetching playbook from private Fragua repo.
- Deployment via `scripts/deploy-workflow.sh`.
- Command format: `/competitors <tema>` where tema is free-form text.
- Empty tema handling: send help message.
- Dynamic playbook loading via HTTP Request to GitHub raw URL.
- AI Agent with tool-use (Tavily search via HTTP Request tool sub-node).
- Response chunking and pagination for long reports.

### Out of Scope

- **Brand-naming workflow** — separate change, not part of this one.
- **Webhook or CLI triggers** — Telegram-only in v1.
- **Persistence to disk, DB, or S3** — report delivered 100% via Telegram; user copies manually if needed.
- **Automatic retries** — failures surface as Telegram error messages; user retries manually.
- **Modifying `telegram-openrouter-chat`** — that workflow currently responds to all text messages, so it will also reply to `/competitors` commands. Adding a filter to ignore slash commands is recommended as a follow-up change (`update-telegram-openrouter-chat-ignore-slash-commands`) but is out of scope for this proposal. Mitigation: test with chat workflow deactivated, or ship the follow-up first.
- **Writing results back to Fragua** — no commits, no file writes.
- **Memory/conversation state** — each `/competitors` invocation is independent.

## Success Criteria

- [ ] Sending `/competitors <tema>` via Telegram produces a report within 3 minutes containing at least 3 competitors.
- [ ] Each competitor entry includes: URL, positioning (1 line), target audience, pricing model, 2-3 key features.
- [ ] Report cites real sources (URLs obtained via Tavily, not invented).
- [ ] `/competitors` without tema responds with help message in <5 seconds.
- [ ] Workflow versioned in git at `workflows/research-competitors/{workflow.json, README.md}`.
- [ ] README documents: purpose, trigger, node list, 4 required credentials, deploy command, test steps.
- [ ] Workflow deploys without errors via `./scripts/deploy-workflow.sh`.
- [ ] Latency is acceptable up to 3 minutes; if consistently exceeding, open issue for investigation.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Double-reply: both `telegram-openrouter-chat` and `research-competitors` respond to `/competitors` | Medium | Test with chat workflow deactivated, or ship follow-up change adding slash-command filter to chat workflow before activating this one in production. Document in design.md as open question. |
| Playbook fetch from GitHub fails (network, auth, rate limit) | Medium | Send clear Telegram error message: "No pude cargar el playbook de investigación: <error>. Intenta de nuevo." No retry in v1; user retries manually. |
| Tavily API timeout, quota exceeded, or service unavailable | High | Send Telegram error message: "La búsqueda falló: <causa>. Inténtalo de nuevo en unos minutos." Monitor Tavily quota in Tavily dashboard. |
| Report exceeds Telegram message limit (4096 chars) | Medium | Implement chunking via Code node: split on paragraph boundaries, ~3500-char budget per chunk, prefix `[i/N]`. Test with broad topics. |
| Playbook changes in Fragua break workflow expectations | Low | Playbook is stable and versioned; if breaking changes occur, pin to a specific commit SHA in the GitHub raw URL instead of `main` branch. |
| Latency >3 min consistently | Low | Accept in v1; if it becomes a pattern, investigate Tavily call count, model speed, or add timeout + partial-result fallback in v2. |

## Rollback Plan

1. Deactivate workflow in n8n UI (toggle Active off).
2. Delete workflow via UI or API: `curl -X DELETE -H "X-N8N-API-KEY: $N8N_API_KEY" https://n8n.rola.dev/api/v1/workflows/<id>`.
3. `git revert` the commit that added `workflows/research-competitors/`.
4. Remove credentials `Tavily API: Research` and `GitHub PAT: Fragua read` from n8n UI only if not used elsewhere.
5. Optionally re-activate `telegram-openrouter-chat` if it was deactivated during testing.

**Time to rollback**: < 5 minutes for workflow deactivation.

## Alternatives Considered

- **Git pull + SSH deploy key for playbook access**: Rejected because it requires cron job in n8n container, filesystem access, and introduces drift between pulls. HTTP fetch is simpler and always fetches the latest version. The added network latency (~50-200ms) is negligible compared to the multi-minute LLM + Tavily execution time.
- **Webhook trigger instead of Telegram**: Rejected for v1 to keep scope tight; Telegram provides built-in auth, user identity, and mobile access. Webhook can be added in v2 if needed.
- **Native Tavily community node**: Deferred unless clearly available and better than HTTP-Request-as-tool in n8n 2.19.4. HTTP Request tool is guaranteed to work and requires no community node dependencies.
- **Embedding playbook in workflow JSON**: Rejected because it defeats the purpose (playbook-as-prompt pattern requires dynamic loading to track Fragua improvements without redeploying the workflow).
- **Storing reports in Postgres/S3**: Rejected for v1; adds complexity and storage management. User can forward/save Telegram messages manually.

## Dependencies

### Pre-requisites (manual, before implementation)

1. **Credentials exist in n8n UI**:
   - `Telegram account` (existing, shared with `telegram-openrouter-chat`).
   - `OpenRouter account` (existing).
   - `Tavily API: Research` (new, HTTP Header Auth, `Authorization: Bearer <tavily_api_key>`).
   - `GitHub PAT: Fragua read` (new, HTTP Header Auth, `Authorization: Bearer <github_pat>`, PAT scoped to read private Fragua repo only).

2. **Fragua repo coordinates confirmed**:
   - Owner/repo: `<fragua-owner>/<fragua-repo>` (to be filled in during build).
   - Branch: `main` (or pinned commit SHA if stability required).
   - Path: `.agents/playbooks/find-competitors.md`.
   - Test raw URL fetch: `curl -H "Authorization: Bearer <PAT>" https://raw.githubusercontent.com/<owner>/<repo>/main/.agents/playbooks/find-competitors.md` returns playbook content.

3. **`.env` has valid `N8N_API_KEY`** for deploy script.

4. **Decision on follow-up change**: whether to ship `update-telegram-openrouter-chat-ignore-slash-commands` before activating this workflow, or accept temporary double-reply during testing.

### Implementation dependencies

- n8n platform running and reachable (`https://n8n.rola.dev/`).
- n8n-mcp available for node selection and workflow validation assistance (optional but recommended).
- OpenRouter model `anthropic/claude-sonnet-4.5` available to the configured OpenRouter account.
- Tavily API account with available quota.

## Estimated Effort

- **Design**: 0.5h
- **Build (workflow.json + README)**: 1.5-2h
- **Test (Telegram + edge cases)**: 1-1.5h
- **Deploy + verify**: 0.5h
- **Total**: 3.5-4.5h

## Related Documentation

- [Architecture](../../../docs/architecture.md) — workflow lifecycle
- [Runbook: Deploying a Workflow](../../../docs/runbooks/deploying-a-workflow.md)
- [Runbook: Credential Management](../../../docs/runbooks/credential-management.md)
- [Reference workflow](../../../workflows/telegram-openrouter-chat/) — pattern base for Telegram + AI Agent
- **Fragua topic** (private): `topics/playbook-as-prompt-workflows/` — conceptual origin and strategy
- **Fragua playbook** (private): `.agents/playbooks/find-competitors.md` — the playbook consumed by this workflow
