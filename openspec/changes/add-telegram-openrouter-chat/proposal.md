# Proposal: Telegram OpenRouter Chat

## Status

**Proposed** - awaiting review

## Problem

n8n 2.19.4 includes a default LLM chat in the UI, but that chat is not exposed as a reusable workflow trigger for Telegram. We need a Telegram bot interface that can talk to an OpenRouter-backed LLM and persist conversation history per Telegram chat.

## Proposed Solution

Add an n8n workflow at `workflows/telegram-openrouter-chat/` that:

- **Trigger**: Telegram app event for incoming bot messages.
- **Action**: Normalize each text message, pass it to an AI Agent using OpenRouter model `anthropic/claude-3.5-sonnet`, and persist chat history with Postgres Chat Memory keyed by Telegram chat ID.
- **Output**: Telegram reply sent back to the originating chat.

## Scope

### In Scope

- `workflows/telegram-openrouter-chat/workflow.json` (n8n native JSON; activation remains manual after testing).
- `workflows/telegram-openrouter-chat/README.md` (purpose, trigger, nodes, credentials, deployment, testing).
- Credentials referenced by name from workflow JSON, never inline.
- Persistent memory using Postgres Chat Memory with session key `telegram:<chat_id>`.
- Deployment via `scripts/deploy-workflow.sh` after UI testing.

### Out of Scope

- Modifying or integrating with n8n's internal default chat UI.
- Infrastructure changes to provision Postgres if it does not already exist; those belong in the `cloudbox/` repo.
- Handling non-text Telegram payloads such as images, voice notes, files, stickers, or callbacks.
- Multi-bot routing or per-user authorization beyond the Telegram bot token.

## Success Criteria

- [ ] `workflow.json` validates as importable n8n JSON and loads in UI without errors.
- [ ] Incoming Telegram text messages produce AI responses in the same chat.
- [ ] Conversation history persists across executions using Postgres Chat Memory.
- [ ] Separate Telegram chats maintain separate memory using `telegram:<chat_id>`.
- [ ] Deployed via `./scripts/deploy-workflow.sh workflows/telegram-openrouter-chat/workflow.json`.
- [ ] Workflow visible in n8n UI with tags `telegram`, `ai`, `openrouter`, and `production`.
- [ ] README documents every credential the workflow consumes by name.
- [ ] No secrets or tokens committed to git.
- [ ] Workflow remains inactive until activated in UI after end-to-end Telegram test passes.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| OpenRouter API errors, rate limits, or model unavailability | High | Send a generic Telegram error message, monitor failed executions, document the selected model. |
| Postgres memory credential/table unavailable | High | Verify Postgres credential before build and test memory persistence before activation. |
| Telegram sends non-text events | Medium | Filter to text messages and ignore unsupported payloads. |
| Conversation history stores sensitive user content | Medium | Document persistence behavior and keep access limited to n8n/Postgres operators. |
| The bot responds in unintended chats | Medium | Use a dedicated bot token initially; add allowlisting later if needed. |

## Rollback Plan

1. Deactivate workflow in n8n UI by toggling Active off.
2. Delete workflow via UI or API if immediate removal is required.
3. `git revert` the commit that added `workflows/telegram-openrouter-chat/`.
4. Remove credentials created exclusively for this workflow only if not used elsewhere.
5. Optionally remove the workflow-specific Postgres memory table/rows after confirming no retention requirement.

**Time to rollback**: < 5 minutes for workflow deactivation.

## Alternatives Considered

- **Reuse n8n's default chat UI directly**: Rejected because it is not exposed as a reusable Telegram-facing workflow and would couple the bot to internal UI behavior.
- **Webhook-based Telegram integration**: Rejected initially because the Telegram Trigger node handles update registration and payload parsing directly in n8n.
- **Simple/Window Buffer Memory**: Rejected because the requirement is persistent history across executions and restarts.
- **Redis Chat Memory**: Deferred because Postgres Chat Memory was selected as the target persistence layer.

## Dependencies

### Pre-requisites (manual, before implementation)

1. Telegram credential exists in n8n UI as `Telegram account` and tests OK.
2. OpenRouter credential exists in n8n UI as `OpenRouter account`.
3. Postgres credential exists in n8n UI as `Postgres account` and can create/read chat memory records.
4. `.env` has a valid `N8N_API_KEY` for the deploy script.

### Implementation dependencies

- n8n platform running and reachable.
- n8n-mcp available for node selection and workflow validation assistance.
- OpenRouter model `anthropic/claude-3.5-sonnet` available to the configured OpenRouter account.

## Estimated Effort

- **Design**: 0.5h
- **Build (workflow.json + README)**: 1-2h
- **Test (Telegram + memory persistence)**: 0.5-1h
- **Deploy + verify**: 0.5h
- **Total**: 2.5-4h

## Related Documentation

- [Architecture](../../../docs/architecture.md) - workflow lifecycle
- [Runbook: Deploying a Workflow](../../../docs/runbooks/deploying-a-workflow.md)
- [Runbook: Credential Management](../../../docs/runbooks/credential-management.md)
