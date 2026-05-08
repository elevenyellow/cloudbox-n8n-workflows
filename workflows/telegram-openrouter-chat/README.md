# Workflow: Telegram OpenRouter Chat

**Purpose**: Let a Telegram bot talk to an OpenRouter-backed LLM and keep persistent conversation history per Telegram chat.

**Trigger**: Telegram message event from the configured bot. The workflow responds to every incoming text message and ignores unsupported non-text updates.

**Nodes**:

- **Telegram Trigger**: Receives Telegram bot message updates.
- **Normalize Telegram Message**: Extracts `input`, `chatId`, `userId`, `messageId`, and `sessionId`.
- **Is Text Message?**: Allows only non-empty text messages to call the LLM.
- **Ignore Non-Text**: Ends unsupported non-text executions without calling OpenRouter.
- **AI Agent**: Generates the assistant response for the Telegram user.
- **OpenRouter Chat Model**: Calls OpenRouter using model `anthropic/claude-sonnet-4.5`.
- **Postgres Chat Memory**: Persists history with session key `telegram:<chat_id>`.
- **Send Telegram Reply**: Sends the AI response back to the originating Telegram chat.

**Credentials Required**:

- `Telegram account`: Telegram Bot API credential used by the trigger and reply nodes.
- `OpenRouter account`: OpenRouter credential used by the chat model node.
- `Postgres account`: Postgres credential used by the chat memory node.

**Deployment**:

Test in n8n UI before deploying from git.

```bash
cd ~/sdk/projects/cloudbox-n8n-workflows
source .env
./scripts/deploy-workflow.sh workflows/telegram-openrouter-chat/workflow.json
```

**Testing**:

1. Import `workflows/telegram-openrouter-chat/workflow.json` into n8n UI.
2. Attach or confirm all three credentials by name.
3. Execute/listen with the Telegram Trigger.
4. Send a text message to the Telegram bot.
5. Verify the bot replies in the same chat.
6. Send a contextual follow-up and verify the answer uses previous context.
7. Send a non-text message and verify OpenRouter is not called.
8. Re-export the workflow JSON from n8n UI after any node-version fixes.
9. Delete the UI-built test copy, deploy from git, then activate the deployed workflow.

**Notes**:

- The n8n 2.19.4 API treats `active` as read-only on create, so this JSON omits it. Newly created workflows remain inactive until activated in UI.
- The n8n 2.19.4 API also treats `tags` as read-only on create, so add `telegram`, `ai`, `openrouter`, and `production` in UI after deployment if desired.
- The default n8n internal chat is not reused because it is not exposed as a workflow surface.
- Memory is isolated by Telegram chat ID, so private chats and groups get separate histories.
- The exact AI node type versions may need adjustment after import in n8n 2.19.4; if so, fix in UI and export the final JSON back into this directory.
