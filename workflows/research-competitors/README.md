# Workflow: Research Competitors (v1.0)

**Purpose**: Execute competitor research via Telegram `/competitors <tema>` command, using Tavily search for real-time web data and OpenAI GPT-4o for analysis.

**Trigger**: Telegram message event from the configured bot. The workflow responds only to messages starting with `/competitors` and ignores all other messages.

**Status**: ✅ **Production-ready v1.0** - Deployed and tested with environment variable configuration for API keys.

**Nodes** (12 total):

1. **Telegram Trigger**: Receives Telegram bot message updates.
2. **Parse Message**: Extracts `input`, `chatId`, `messageId`, and `topic` (text after `/competitors` command).
3. **Filter /competitors**: IF node that only processes messages starting with `/competitors`.
4. **Check Topic**: IF node that validates topic is non-empty.
5. **Send Help**: Sends usage instructions if topic is empty (`Usage: /competitors <topic>`).
6. **Load Playbook**: HTTP Request to fetch playbook from GitHub raw URL (currently unused in system prompt).
7. **Build System Prompt**: Assembles concise system prompt with research instructions.
8. **AI Agent**: Executes research with tool-use (Tavily search).
   - **OpenRouter Chat Model** (sub-node): Calls OpenRouter using model `openai/gpt-4o`.
   - **Tavily Search Tool** (sub-node): Code tool that calls Tavily API for web search.
9. **Split Response Into Chunks**: Code node that paginates long reports (~3500 chars per chunk, prefix `[i/N]`).
10. **Send Telegram Reply**: Sends report chunks to user.

**Credentials Required**:

- `Telegram account`: Telegram Bot API credential (shared with `telegram-openrouter-chat`).
- `OpenRouter account`: OpenRouter credential.
- **Environment variable**: `TAVILY_API_KEY` must be set in n8n environment (see Deployment section below).
- ~~`GitHub PAT: Fragua read`~~: Not needed in current build (playbook copied locally).

**Deployment**:

**Prerequisites**: Set `TAVILY_API_KEY` environment variable in n8n.

Option 1 - Use setup script (recommended):
```bash
# On n8n server (rola.dev)
sudo bash /path/to/scripts/setup-n8n-env.sh
# Follow the instructions to add TAVILY_API_KEY to your n8n environment
```

Option 2 - Manual setup:
- **Docker**: Add to `docker-compose.yml` environment section:
  ```yaml
  environment:
    - TAVILY_API_KEY=${TAVILY_API_KEY}
  ```
  Then add to `.env`: `TAVILY_API_KEY=your_key_here` and run `docker-compose up -d`

- **Systemd**: Add to service file `[Service]` section:
  ```
  Environment="TAVILY_API_KEY=your_key_here"
  ```
  Then run `systemctl daemon-reload && systemctl restart n8n`

**Deploy workflow**:
```bash
cd ~/projects/cloudbox-n8n-workflows
source .env
./scripts/deploy-workflow.sh workflows/research-competitors/workflow.json
```

**Testing**:

1. **Activate workflow**: https://n8n.rola.dev/workflow/8xdglWouEBTLBvIw
2. **Test cases**:
   - `/competitors` (no topic) → help message "Usage: /competitors <topic>"
   - `/competitors n8n alternatives` → report with ≥3 competitors, URLs, positioning, pricing, features
   - Plain text message (e.g., "hola") → workflow ignores (no response)
   - Long report → paginated with `[1/N]`, `[2/N]`, etc.

**Notes**:

- **Version**: v1.0 - Production ready
- **Model**: Using `openai/gpt-4o` via OpenRouter (switched from `anthropic/claude-sonnet-4.5` due to tool-calling issues).
- **Tavily API key**: Loaded from `$env('TAVILY_API_KEY')` in n8n Code tool. Dev key configured in `/home/orlando/services/n8n/.env`.
- **Search depth**: `advanced` (2 API credits per search) - Returns multiple semantically relevant snippets per URL for higher quality, more detailed results. Also fetches 10 results (vs 5 in basic) with 3 chunks per source.
- **System prompt**: v1.0 uses concise inline instructions (~400 chars) instead of full playbook. Future versions may restore dynamic playbook loading.
- **Double-reply risk**: `telegram-openrouter-chat` also responds to all text messages. Consider adding a follow-up change to filter slash commands in that workflow, or deactivate it.
- **No memory**: Each `/competitors` invocation is independent (no conversation history).
- **Chunking**: Reports >3500 chars are split into multiple Telegram messages with `[i/N]` prefix.
- **Error handling**: Failures surface as failed n8n executions (visible in Executions tab). Tavily errors are caught and returned to the AI Agent as tool output.

**Future improvements** (v2.0):
- Restore full playbook as system prompt (loaded dynamically from Fragua repo)
- Add more search tools (Perplexity, Exa, etc.)
- Add conversation memory for follow-up questions
- Filter slash commands in `telegram-openrouter-chat` to avoid double-reply

**Playbook version**: Copied from Fragua on 2026-05-20 (v0 baseline). See `playbook.md` in this directory.
