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
- **Tavily API key**: Must be configured directly in the "Tavily Search Tool" Code node (line 14). Replace `YOUR_TAVILY_API_KEY` with your actual key. n8n Code tools don't support environment variables directly.
- ~~`GitHub PAT: Fragua read`~~: Not needed in current build (playbook copied locally).

**Deployment**:

**Prerequisites**: 
1. Get a Tavily API key from https://tavily.com
2. Open the workflow JSON and find the "Tavily Search Tool" node
3. Replace `YOUR_TAVILY_API_KEY` with your actual key (line 14 in the jsCode)

**Deploy workflow**:
```bash
cd ~/projects/cloudbox-n8n-workflows
source .env
./scripts/deploy-workflow.sh workflows/research-competitors/workflow.json
```

**Note**: The workflow JSON in git has a placeholder `YOUR_TAVILY_API_KEY`. You must replace it before deploying. The deployed version at n8n.rola.dev has the actual dev key configured.

**Testing**:

1. **Activate workflow**: https://n8n.rola.dev/workflow/lAoSqTNPWcYh2ncE
2. **Test cases**:
   - `/competitors` (no topic) → help message "Usage: /competitors <topic>"
   - `/competitors n8n alternatives` → report with ≥3 competitors, URLs, positioning, pricing, features
   - Plain text message (e.g., "hola") → workflow ignores (no response)
   - Long report → paginated with `[1/N]`, `[2/N]`, etc.

**Notes**:

- **Version**: v1.0 - Production ready
- **Model**: Using `openai/gpt-4o` via OpenRouter (switched from `anthropic/claude-sonnet-4.5` due to tool-calling issues).
- **Tavily API key**: Hardcoded in the Code tool (line 14). n8n Code tools don't support `process.env` or `$env()` for accessing environment variables. The key must be replaced directly in the workflow JSON before deployment.
- **Search depth**: `advanced` (2 API credits per search) - Returns multiple semantically relevant snippets per URL for higher quality, more detailed results. Also fetches 10 results (vs 5 in basic) with 3 chunks per source.
- **System prompt**: v1.0 uses concise inline instructions (~400 chars) instead of full playbook. Future versions may restore dynamic playbook loading.
- **Double-reply risk**: `telegram-openrouter-chat` also responds to all text messages. Consider adding a follow-up change to filter slash commands in that workflow, or deactivate it.
- **No memory**: Each `/competitors` invocation is independent (no conversation history).
- **Chunking**: Reports >3500 chars are split into multiple Telegram messages with `[i/N]` prefix.
- **Error handling**: Failures surface as failed n8n executions (visible in Executions tab). Tavily errors are caught and returned to the AI Agent as tool output.

**Future improvements** (v2.0):
- Use n8n credentials system instead of hardcoded API key (requires switching from Code tool to HTTP Request tool or using a Set node to inject credentials)
- Restore full playbook as system prompt (loaded dynamically from Fragua repo)
- Add more search tools (Perplexity, Exa, etc.)
- Add conversation memory for follow-up questions
- Filter slash commands in `telegram-openrouter-chat` to avoid double-reply

**Playbook version**: Copied from Fragua on 2026-05-20 (v0 baseline). See `playbook.md` in this directory.
