# Tasks: Telegram OpenRouter Chat

## Pre-requisites (Manual - DO BEFORE IMPLEMENTATION)

- [ ] **Confirm Telegram credential exists in n8n UI**
- Open `https://n8n.rola.dev/` -> Credentials.
- Verify `Telegram account` exists and tests OK.

- [ ] **Confirm OpenRouter credential exists in n8n UI**
- Verify `OpenRouter account` exists.
- Confirm model `anthropic/claude-3.5-sonnet` is available to the account.

- [ ] **Confirm Postgres memory credential exists in n8n UI**
- Verify `Postgres account` exists and tests OK.
- Confirm the target database/schema can store chat memory records.

- [ ] **Confirm `.env` is loaded locally**

```bash
grep N8N_API_KEY .env  # must return a non-empty value
```

## Implementation Tasks

### 1. Verify node availability

- [ ] Use n8n-mcp or n8n UI to confirm node names/type versions for Telegram Trigger, Telegram Send Message, AI Agent, OpenAI-compatible Chat Model, and Postgres Chat Memory.
- [ ] Record any node type/version deviations in `design.md` before building.

### 2. Scaffold workflow directory

- [ ] Create `workflows/telegram-openrouter-chat/`.
- [ ] Create `workflows/telegram-openrouter-chat/workflow.json` from the UI-exported workflow JSON.
- [ ] Create `workflows/telegram-openrouter-chat/README.md` documenting purpose, trigger, nodes, credentials, deployment, and testing.

**Commit**: `feat(telegram-openrouter-chat): scaffold telegram ai workflow`

### 3. Build workflow in n8n UI

- [ ] Open n8n UI -> New Workflow.
- [ ] Add `Telegram Trigger` using `Telegram account`.
- [ ] Add `Normalize Telegram Message` node with `input`, `chatId`, `userId`, `messageId`, and `sessionId`.
- [ ] Add `Is Text Message?` IF node to filter unsupported Telegram updates.
- [ ] Add `AI Agent` node with input `={{ $json.input }}`.
- [ ] Attach OpenRouter chat model with model `anthropic/claude-3.5-sonnet`.
- [ ] Attach Postgres Chat Memory with session key `={{ $json.sessionId }}`.
- [ ] Add Telegram send message node with chat ID `={{ $json.chatId }}` and text from the agent output.
- [ ] Set workflow name to `Telegram OpenRouter Chat`.
- [ ] Add tags `telegram`, `ai`, `openrouter`, and `production`.

### 4. Test in n8n UI

- [ ] Execute/listen with the Telegram Trigger.
- [ ] Send a representative text message to the Telegram bot.
- [ ] Confirm all nodes on the text path execute successfully.
- [ ] Confirm the bot replies in the same Telegram chat.
- [ ] Send a follow-up question and confirm Postgres memory keeps context.
- [ ] Send a non-text message and confirm the workflow does not call OpenRouter.
- [ ] Inspect failed executions, if any, and fix red nodes.

### 5. Export and commit JSON

- [ ] In n8n UI: workflow menu -> Download (JSON).
- [ ] Replace `workflows/telegram-openrouter-chat/workflow.json` with the downloaded file.
- [ ] Verify workflow is inactive in n8n after API creation and before activation.
- [ ] Verify credentials are referenced by name/id only and no secrets are inline.

```bash
grep -i -E '(token|secret|api[_-]?key|password)' workflows/telegram-openrouter-chat/workflow.json
```

- [ ] Update README with the actual node list and any deviations from `design.md`.

**Commit**: `feat(telegram-openrouter-chat): add workflow JSON and README`

### 6. Delete the UI-built copy and deploy from git

- [ ] In n8n UI: delete the workflow built in step 3 after exporting JSON.
- [ ] Deploy from git source of truth:

```bash
./scripts/deploy-workflow.sh workflows/telegram-openrouter-chat/workflow.json
```

- [ ] Note the returned workflow ID and URL.
- [ ] Open the workflow URL and verify nodes, tags, and credentials.

### 7. Final verification

- [ ] Activate the deployed workflow in n8n UI.
- [ ] Send a Telegram text message and confirm a response.
- [ ] Send a contextual follow-up and confirm memory works.
- [ ] Confirm at least one successful execution is recorded in n8n Executions.
- [ ] Confirm no secrets are present in git diff.

## Verification Checklist

- [ ] `workflow.json` is in git and matches the deployed workflow export.
- [ ] README lists every credential by canonical name.
- [ ] No secrets in `workflow.json`.
- [ ] Workflow is active in n8n UI.
- [ ] Telegram text message path succeeds end-to-end.
- [ ] Postgres Chat Memory persists conversation context by `telegram:<chat_id>`.
