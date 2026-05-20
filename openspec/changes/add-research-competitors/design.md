# Design: Research Competitors Workflow

## Overview

This workflow implements the **playbook-as-prompt** pattern: it receives a `/competitors <tema>` command via Telegram, dynamically fetches the `find-competitors.md` playbook from the private Fragua repo, injects the tema into a system prompt header, executes the playbook using an AI Agent with Tavily search tool, and returns a structured markdown report via Telegram. The playbook is loaded on every execution, ensuring the workflow automatically benefits from playbook improvements in Fragua without redeployment.

## Trigger

- **Type**: App event (Telegram message)
- **Configuration**:
  - Telegram Trigger receives all incoming updates for the configured bot credential (`Telegram account`, shared with `telegram-openrouter-chat`).
  - The workflow processes only messages starting with `/competitors` (case-sensitive).
  - Messages not matching `/competitors` are ignored by this workflow (but may be handled by `telegram-openrouter-chat`).
  - The bot replies only to `/competitors` commands; all other text messages are filtered out early.

## Node Graph

```text
Telegram Trigger
   │
   ▼
Normalize Telegram Message
  (input, chatId, userId, messageId, rawText)
   │
   ▼
Parse /competitors Command
  (extract command + topic via regex)
   │
   ▼
Is /competitors?  ── false ──► Ignore Non-Command  (NoOp/Set)
   │ true
   ▼
Has Topic?  ── false ──► Send Help Message ──► (end)
   │ true
   ▼
Fetch Playbook
  (HTTP Request → GitHub raw URL + Bearer PAT)
   │
   ▼
Build System Prompt
  (Set: operative header with topic + playbook body)
   │
   ▼
AI Agent
   ├── OpenRouter Chat Model (anthropic/claude-sonnet-4.5)
   └── Tavily Search (HTTP Request tool sub-node)
   │
   ▼
Split Response Into Chunks
  (Code: paginate ~3500 chars, prefix [i/N])
   │
   ▼
Send Telegram Reply
  (loop over chunks, reply_to_message_id on first only)
```

## Nodes

| # | Node | Type | Purpose | Notes |
|---|------|------|---------|-------|
| 1 | Telegram Trigger | `n8n-nodes-base.telegramTrigger` | Receive Telegram bot messages. | Uses `Telegram account`. Same credential as `telegram-openrouter-chat`. |
| 2 | Normalize Telegram Message | `n8n-nodes-base.set` | Extract stable fields for downstream nodes. | Creates `input`, `chatId`, `userId`, `messageId`, `rawText`. No `sessionId` (no memory). |
| 3 | Parse /competitors Command | `n8n-nodes-base.set` | Extract command and topic from message text. | Regex: `^(/competitors(?:@\w+)?)\s*(.*)$` to support `/competitors@botname <tema>`. Produces `command` and `topic` fields. |
| 4 | Is /competitors? | `n8n-nodes-base.if` | Filter to `/competitors` commands only. | Condition: `{{ $json.command }}` starts with `/competitors`. False branch → Ignore Non-Command. |
| 5 | Ignore Non-Command | `n8n-nodes-base.set` | End non-`/competitors` executions cleanly. | Sets `ignored: true`, `reason: "not a /competitors command"`. |
| 6 | Has Topic? | `n8n-nodes-base.if` | Check if topic is non-empty. | Condition: `{{ $json.topic }}` is not empty. False branch → Send Help Message. |
| 7 | Send Help Message | `n8n-nodes-base.telegram` | Reply with usage instructions. | Text: `"Uso: /competitors <tema>\n\nEjemplo: /competitors herramientas de automatización no-code"`. Chat ID: `{{ $json.chatId }}`. |
| 8 | Fetch Playbook | `n8n-nodes-base.httpRequest` | Load playbook from Fragua repo. | GET `https://raw.githubusercontent.com/<fragua-owner>/<fragua-repo>/main/.agents/playbooks/find-competitors.md`. Header: `Authorization: Bearer <PAT>` via `GitHub PAT: Fragua read` credential. Response as text. |
| 9 | Build System Prompt | `n8n-nodes-base.set` | Assemble system prompt from header + playbook. | `systemMessage = <operative header with topic> + "\n\n---\n\n" + <playbook body from step 8>`. See Data Flow section for exact header text. |
| 10 | AI Agent | `@n8n/n8n-nodes-langchain.agent` | Execute playbook with tool-use. | Input: `{{ "Investiga competidores para: " + $json.topic }}`. System message: `{{ $json.systemMessage }}`. No memory attached. |
| 11 | OpenRouter Chat Model | `@n8n/n8n-nodes-langchain.lmChatOpenRouter` | LLM for agent reasoning and report writing. | Model: `anthropic/claude-sonnet-4.5`. Uses `OpenRouter account` credential. Base URL: `https://openrouter.ai/api/v1`. |
| 12 | Tavily Search | `@n8n/n8n-nodes-langchain.toolHttpRequest` | Search tool for the agent. | HTTP Request tool sub-node. POST `https://api.tavily.com/search`. Header: `Authorization: Bearer <tavily_key>` via `Tavily API: Research` credential. Body: `{"query": "{{ $json.query }}", "max_results": 5}`. Returns JSON with search results. |
| 13 | Split Response Into Chunks | `n8n-nodes-base.code` | Paginate long reports for Telegram. | JavaScript: split agent output on paragraph boundaries (`\n\n`), respect ~3500-char budget per chunk, return array of `{chunk, index, total}`. Prefix each chunk with `[index/total]\n\n`. |
| 14 | Send Telegram Reply | `n8n-nodes-base.telegram` | Send report chunks to user. | Chat ID: `{{ $json.chatId }}`. Text: `{{ $json.chunk }}`. `reply_to_message_id`: `{{ $json.messageId }}` (only on first chunk; optional refinement). Runs once per chunk (n8n default per-item execution). |

## Credentials

Workflow references credentials **by name** and never stores credential values inline.

| Credential Name | Type | Used By Node | Owner | Notes |
|---|---|---|---|---|
| `Telegram account` | Telegram Bot API token | Telegram Trigger, Send Telegram Reply | Operator | Existing credential, shared with `telegram-openrouter-chat`. |
| `OpenRouter account` | OpenRouter API key | OpenRouter Chat Model | Operator | Existing credential. |
| `Tavily API: Research` | HTTP Header Auth | Tavily Search (HTTP Request tool) | Operator | **New credential**. Header: `Authorization: Bearer <tavily_api_key>`. |
| `GitHub PAT: Fragua read` | HTTP Header Auth | Fetch Playbook (HTTP Request) | Operator | **New credential**. Header: `Authorization: Bearer <github_pat>`. PAT scoped to read private Fragua repo only. |

## Data Flow

### Input shape (Telegram Trigger)

Telegram update payload from the Telegram Trigger node.

### Normalized fields (Normalize Telegram Message)

```javascript
input = {{ $json.message?.text || '' }}
chatId = {{ $json.message?.chat?.id }}
userId = {{ $json.message?.from?.id }}
messageId = {{ $json.message?.message_id }}
rawText = {{ $json.message?.text || '' }}
```

### Command parsing (Parse /competitors Command)

Regex: `^(/competitors(?:@\w+)?)\s*(.*)$`

Extracts:
- `command`: `/competitors` or `/competitors@botname`
- `topic`: everything after the command (trimmed)

Example:
- Input: `/competitors herramientas de automatización no-code`
- Output: `command = "/competitors"`, `topic = "herramientas de automatización no-code"`

### System prompt assembly (Build System Prompt)

**Operative header** (prepended to playbook):

```
Eres un agente que ejecuta el siguiente playbook de investigación de competidores. Dispones de la herramienta `tavily_search` para buscar fuentes reales. El tema a investigar es: {{ $json.topic }}. Devuelve un informe markdown estructurado, con citas a URLs concretas. Si excedes ~3500 caracteres, divide la respuesta en partes numeradas.
```

**Final system message**:

```
systemMessage = <operative header above> + "\n\n---\n\n" + <playbook body from Fetch Playbook node>
```

### Agent input

```
text = "Investiga competidores para: " + {{ $json.topic }}
```

The topic is passed both in the system prompt (as context) and in the user input (to make tool-use prompts unambiguous).

### Tavily tool request/response

**Request** (from agent to Tavily):
```json
POST https://api.tavily.com/search
Authorization: Bearer <tavily_api_key>
Content-Type: application/json

{
  "query": "<agent-generated search query>",
  "max_results": 5
}
```

**Response** (Tavily to agent):
```json
{
  "results": [
    {"url": "...", "title": "...", "content": "..."},
    ...
  ]
}
```

### Agent output

Markdown report with:
- At least 3 competitors identified.
- Each competitor: URL, positioning (1 line), target audience, pricing model, 2-3 key features.
- Citations to real URLs obtained via Tavily.

### Chunking (Split Response Into Chunks)

JavaScript Code node:

```javascript
const text = $input.item.json.output; // agent output
const maxChars = 3500;
const paragraphs = text.split('\n\n');
const chunks = [];
let currentChunk = '';

for (const para of paragraphs) {
  if ((currentChunk + para).length > maxChars && currentChunk.length > 0) {
    chunks.push(currentChunk.trim());
    currentChunk = para;
  } else {
    currentChunk += (currentChunk ? '\n\n' : '') + para;
  }
}
if (currentChunk) chunks.push(currentChunk.trim());

return chunks.map((chunk, i) => ({
  json: {
    chunk: `[${i+1}/${chunks.length}]\n\n${chunk}`,
    index: i + 1,
    total: chunks.length,
    chatId: $input.item.json.chatId,
    messageId: $input.item.json.messageId
  }
}));
```

### Telegram output (Send Telegram Reply)

```
chatId = {{ $json.chatId }}
text = {{ $json.chunk }}
reply_to_message_id = {{ $json.messageId }}  // only on first chunk (index === 1)
```

## Error Handling

- **Empty topic** (`/competitors` with no text): Fast path to Send Help Message node. Expected latency: <5 seconds.
- **Playbook fetch failure** (HTTP Request node fails due to network, auth, or rate limit): Workflow execution fails. Future enhancement: add error workflow or `continueOnFail` + conditional Telegram error message: `"No pude cargar el playbook de investigación: {{ $json.error }}. Intenta de nuevo."`.
- **Tavily API failure** (timeout, quota, service unavailable): AI Agent node fails. Future enhancement: add error workflow or Telegram fallback message: `"La búsqueda falló: {{ $json.error }}. Inténtalo de nuevo en unos minutos."`.
- **AI Agent failure** (OpenRouter error, model unavailable): Workflow execution fails. Future enhancement: Telegram error message with error code.
- **No retries in v1**: All failures surface as failed n8n executions visible in Executions tab. User retries manually by sending the command again.
- **Duplicate Telegram updates**: Low risk; each `/competitors` command may produce another report. No idempotency store planned initially.

## Observability

- **n8n UI → Executions**: Shows each `/competitors` execution, node-level payloads, errors, and execution time.
- **Telegram chat history**: User-facing verification of report delivery and quality.
- **No external alerting in v1**: Failed executions visible only in n8n UI. Future enhancement: error workflow sending Telegram alert to operator.

## Open Questions

1. **Fragua repo coordinates**: Confirm `<fragua-owner>/<fragua-repo>` and branch (`main` vs pinned commit SHA) during build phase. Test raw URL fetch with PAT before building workflow.

2. **`reply_to_message_id` on all chunks vs first only**: Does setting `reply_to_message_id` on all chunks create a clean thread in Telegram, or does it clutter the UI? Test during build and decide. If cluttered, set only on first chunk.

3. **HTTP Request tool sub-node availability**: Verify that `@n8n/n8n-nodes-langchain.toolHttpRequest` exists at the expected typeVersion in n8n 2.19.4. If not available, fallback to a custom Code tool node wrapping Tavily API calls.

4. **Follow-up change for `telegram-openrouter-chat`**: Should we ship `update-telegram-openrouter-chat-ignore-slash-commands` before activating this workflow, or accept temporary double-reply during testing? Decision affects activation timeline.

5. **Chunking precision**: The 3500-char budget leaves ~600-char margin below Telegram's 4096 limit. Is this sufficient for the `[i/N]` prefix and markdown overhead, or should we reduce to 3000? Test with real reports during build.

## Decisions

- **No memory**: Each `/competitors` invocation is independent. No Postgres Chat Memory node. Rationale: competitor research is a one-shot query, not a conversation.

- **HTTP playbook fetch over git pull**: Fetch playbook via HTTP Request to GitHub raw URL on every execution. Rejected git pull + SSH deploy key because it requires cron, filesystem access, and introduces drift. HTTP fetch is simpler and always gets the latest version. Network latency (~50-200ms) is negligible compared to LLM + Tavily execution time (minutes).

- **HTTP Request tool for Tavily**: Use `@n8n/n8n-nodes-langchain.toolHttpRequest` sub-node attached to AI Agent, pointing at Tavily REST API. Rejected native Tavily community node (if it exists) because HTTP Request tool is guaranteed to work and requires no community node dependencies.

- **Model: `anthropic/claude-sonnet-4.5`**: Same model as `telegram-openrouter-chat`. Good tool-use, good long-form markdown, consistency across workflows. Rejected Opus (overkill, slower, more expensive) and leaving it TBD (decision made upfront for clarity).

- **Same bot, filter by `/competitors`**: Reuse `Telegram account` credential. Both `telegram-openrouter-chat` and `research-competitors` listen to the same bot; this workflow filters to `/competitors` only. Rejected dedicated new bot because it adds operational overhead (BotFather setup, new credential). Side-effect: `telegram-openrouter-chat` will also reply to `/competitors` unless filtered. Mitigation: test with chat workflow deactivated, or ship follow-up change first.

- **Chunking via Code node**: Split agent output on paragraph boundaries (`\n\n`), respect ~3500-char budget per chunk, prefix `[i/N]`. Rejected server-side pagination (not applicable to LLM output) and client-side "read more" links (Telegram doesn't support interactive buttons in this context without inline keyboards, which are out of scope for v1).

- **Error surfacing**: v1 surfaces errors as failed n8n executions (visible in Executions tab) rather than silent failures. Future enhancement: add error workflow sending Telegram error messages to user. Rationale: fail-fast and visible is better than silent for initial deployment.

- **Telegram chat ID session key**: Not applicable (no memory). Removed from normalized fields.

- **Playbook branch**: Use `main` branch initially. If playbook changes in Fragua break workflow expectations, pin to a specific commit SHA in the GitHub raw URL. Rationale: playbook is stable and versioned; dynamic loading is the whole point of this pattern.
