# Workflow: Research Competitors

**Purpose**: Execute competitor research via Telegram `/competitors <tema>` command, using the `find-competitors.md` playbook from Fragua as system prompt, with Tavily search for real-time web data.

**Trigger**: Telegram message event from the configured bot. The workflow responds only to messages starting with `/competitors` and ignores all other messages.

**Pattern**: Playbook-as-prompt — the playbook is loaded dynamically (currently from this repo, can be switched to Fragua GitHub raw URL) and used as the AI Agent's system prompt, ensuring the workflow benefits from playbook improvements without redeployment.

**Nodes**:

- **Telegram Trigger**: Receives Telegram bot message updates.
- **Normalize Telegram Message**: Extracts `input`, `chatId`, `userId`, `messageId`, `rawText`.
- **Parse /competitors Command**: Extracts `command` and `topic` via regex.
- **Is /competitors?**: Filters to `/competitors` commands only.
- **Ignore Non-Command**: Ends non-`/competitors` executions cleanly.
- **Has Topic?**: Checks if topic is non-empty.
- **Send Help Message**: Sends usage instructions if topic is empty.
- **Fetch Playbook**: Loads playbook from `playbook.md` in this repo (or GitHub raw URL if configured).
- **Build System Prompt**: Assembles system prompt from operative header + playbook body.
- **AI Agent**: Executes playbook with tool-use (Tavily search).
- **OpenRouter Chat Model**: Calls OpenRouter using model `anthropic/claude-sonnet-4.5`.
- **Tavily Search**: HTTP Request tool for web search (requires `Tavily API: Research` credential).
- **Split Response Into Chunks**: Paginates long reports (~3500 chars per chunk, prefix `[i/N]`).
- **Send Telegram Reply**: Sends report chunks to user.

**Credentials Required**:

- `Telegram account`: Telegram Bot API credential (shared with `telegram-openrouter-chat`).
- `OpenRouter account`: OpenRouter credential.
- `Tavily API: Research`: HTTP Header Auth credential for Tavily search API.
- ~~`GitHub PAT: Fragua read`~~: Not needed in current build (playbook copied locally). Add if switching to GitHub raw URL fetch.

**Deployment**:

Test in n8n UI before deploying from git.

```bash
cd ~/projects/cloudbox-n8n-workflows
source .env
./scripts/deploy-workflow.sh workflows/research-competitors/workflow.json
```

**Testing**:

1. **Pre-requisites**:
   - Confirm `Telegram account`, `OpenRouter account` credentials exist in n8n UI.
   - Create `Tavily API: Research` credential (HTTP Header Auth, `Authorization: Bearer <tavily_key>`).
   - Optionally deactivate `telegram-openrouter-chat` to avoid double-reply during testing.

2. **Import and build**:
   - Open n8n UI → New Workflow.
   - Build nodes per `openspec/changes/add-research-competitors/tasks.md` § 3.
   - Attach credentials by name.
   - Set workflow name: `Research Competitors`.
   - Add tags: `telegram`, `ai`, `openrouter`, `research`, `tavily`, `production`.

3. **Test cases**:
   - `/competitors` (no topic) → help message in <5s.
   - `/competitors n8n alternatives` → report with ≥3 competitors, URLs, positioning, pricing, features, within 3 min.
   - Plain text message → workflow ignores (no LLM call).
   - Long report → paginated with `[1/N]`, `[2/N]`, etc.

4. **Export and commit**:
   - Download JSON from n8n UI.
   - Replace `workflows/research-competitors/workflow.json`.
   - Verify no secrets: `grep -i -E '(token|secret|api[_-]?key|password)' workflow.json`.
   - Commit: `feat(research-competitors): add workflow JSON`.

5. **Deploy**:
   - Delete UI-built copy.
   - Deploy via script (see above).
   - Activate in UI.
   - Send `/competitors test` to verify end-to-end.

**Notes**:

- **Playbook source**: Currently loaded from `workflows/research-competitors/playbook.md` (copied from Fragua). To switch to dynamic GitHub fetch, replace the "Fetch Playbook" node with HTTP Request to `https://raw.githubusercontent.com/elevenyellow/fragua/main/.agents/playbooks/find-competitors.md` and add `GitHub PAT: Fragua read` credential.
- **Double-reply risk**: `telegram-openrouter-chat` also responds to all text messages. Consider adding a follow-up change to filter slash commands in that workflow, or test with it deactivated.
- **No memory**: Each `/competitors` invocation is independent (no conversation history).
- **Chunking**: Reports >3500 chars are split into multiple Telegram messages with `[i/N]` prefix.
- **Error handling**: Failures surface as failed n8n executions (visible in Executions tab). Future enhancement: add error workflow for Telegram error messages.

**Playbook version**: Copied from Fragua on 2026-05-20 (v0 baseline). See `playbook.md` in this directory.
