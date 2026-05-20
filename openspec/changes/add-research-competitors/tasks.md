# Tasks: Research Competitors Workflow

## Pre-requisites (Manual — DO BEFORE IMPLEMENTATION)

- [ ] **Confirm existing credentials in n8n UI**
  - Open `https://n8n.rola.dev/` → Credentials
  - Verify `Telegram account` exists and tests OK
  - Verify `OpenRouter account` exists and tests OK

- [ ] **Create `Tavily API: Research` credential**
  - In n8n UI → Credentials → Add Credential
  - Type: **HTTP Header Auth**
  - Name: `Tavily API: Research`
  - Header Name: `Authorization`
  - Header Value: `Bearer <your_tavily_api_key>`
  - Test the credential (if n8n supports test for HTTP Header Auth)
  - Save

- [ ] **Create `GitHub PAT: Fragua read` credential**
  - Generate GitHub PAT with scope: `repo` (read access to private Fragua repo)
  - In n8n UI → Credentials → Add Credential
  - Type: **HTTP Header Auth**
  - Name: `GitHub PAT: Fragua read`
  - Header Name: `Authorization`
  - Header Value: `Bearer <your_github_pat>`
  - Save

- [ ] **Confirm Fragua repo coordinates**
  - Identify Fragua repo: `<owner>/<repo>` (e.g., `elevenyellow/fragua`)
  - Confirm branch: `main` (or specific commit SHA if pinning required)
  - Confirm playbook path: `.agents/playbooks/find-competitors.md`
  - Test raw URL fetch from local machine:
    ```bash
    curl -H "Authorization: Bearer <github_pat>" \
      https://raw.githubusercontent.com/<owner>/<repo>/main/.agents/playbooks/find-competitors.md
    ```
  - Verify response contains playbook markdown content (not 404 or auth error)

- [ ] **Decide on follow-up change for `telegram-openrouter-chat`**
  - Current state: `telegram-openrouter-chat` responds to all text messages, including `/competitors`.
  - Options:
    1. Ship follow-up change `update-telegram-openrouter-chat-ignore-slash-commands` before activating this workflow (recommended for production).
    2. Test this workflow with `telegram-openrouter-chat` deactivated temporarily.
    3. Accept temporary double-reply during testing and fix later.
  - Document decision in build phase.

- [ ] **Confirm `.env` is loaded locally**
  ```bash
  grep N8N_API_KEY .env  # must return a non-empty value
  ```

## Implementation Tasks

### 1. Verify node availability

- [ ] Use n8n-mcp or n8n UI to confirm node names/type versions for:
  - `n8n-nodes-base.telegramTrigger`
  - `n8n-nodes-base.telegram` (send message)
  - `n8n-nodes-base.set` (Set/Edit Fields)
  - `n8n-nodes-base.if` (IF conditional)
  - `n8n-nodes-base.httpRequest` (HTTP Request)
  - `n8n-nodes-base.code` (Code node)
  - `@n8n/n8n-nodes-langchain.agent` (AI Agent)
  - `@n8n/n8n-nodes-langchain.lmChatOpenRouter` (OpenRouter Chat Model)
  - `@n8n/n8n-nodes-langchain.toolHttpRequest` (HTTP Request tool sub-node for AI Agent)
- [ ] Record any node type/version deviations in `design.md` § Open Questions before building.

### 2. Scaffold workflow directory

- [ ] Create `workflows/research-competitors/`
- [ ] Create empty `workflows/research-competitors/workflow.json` (will paste exported JSON later)
- [ ] Create `workflows/research-competitors/README.md` from template (Purpose, Trigger, Nodes, Credentials Required, Deployment, Testing)

**Commit**: `feat(research-competitors): scaffold workflow directory`

### 3. Build workflow in n8n UI

- [ ] Open n8n UI → New Workflow
- [ ] Set workflow name to `Research Competitors`
- [ ] Add tags: `telegram`, `ai`, `openrouter`, `research`, `tavily`, `production`

**Add nodes per design.md § Node Graph:**

- [ ] **Node 1: Telegram Trigger**
  - Type: `n8n-nodes-base.telegramTrigger`
  - Credential: `Telegram account`
  - Updates: `message`

- [ ] **Node 2: Normalize Telegram Message**
  - Type: `n8n-nodes-base.set`
  - Assignments:
    - `input` = `{{ $json.message?.text || '' }}`
    - `chatId` = `{{ $json.message?.chat?.id }}`
    - `userId` = `{{ $json.message?.from?.id }}`
    - `messageId` = `{{ $json.message?.message_id }}`
    - `rawText` = `{{ $json.message?.text || '' }}`
  - Include other fields: true

- [ ] **Node 3: Parse /competitors Command**
  - Type: `n8n-nodes-base.set`
  - Assignments:
    - `command` = `{{ $json.input.match(/^(\/competitors(?:@\w+)?)/)?.[1] || '' }}`
    - `topic` = `{{ $json.input.replace(/^\/competitors(?:@\w+)?\s*/, '').trim() }}`
  - Include other fields: true

- [ ] **Node 4: Is /competitors?**
  - Type: `n8n-nodes-base.if`
  - Condition: `{{ $json.command }}` starts with `/competitors`
  - True branch → Node 6 (Has Topic?)
  - False branch → Node 5 (Ignore Non-Command)

- [ ] **Node 5: Ignore Non-Command**
  - Type: `n8n-nodes-base.set`
  - Assignments:
    - `ignored` = `true`
    - `reason` = `"not a /competitors command"`
  - End of false branch

- [ ] **Node 6: Has Topic?**
  - Type: `n8n-nodes-base.if`
  - Condition: `{{ $json.topic }}` is not empty
  - True branch → Node 8 (Fetch Playbook)
  - False branch → Node 7 (Send Help Message)

- [ ] **Node 7: Send Help Message**
  - Type: `n8n-nodes-base.telegram`
  - Credential: `Telegram account`
  - Chat ID: `{{ $json.chatId }}`
  - Text: `Uso: /competitors <tema>\n\nEjemplo: /competitors herramientas de automatización no-code`
  - End of false branch

- [ ] **Node 8: Fetch Playbook**
  - Type: `n8n-nodes-base.httpRequest`
  - Method: GET
  - URL: `https://raw.githubusercontent.com/<fragua-owner>/<fragua-repo>/main/.agents/playbooks/find-competitors.md`
  - Authentication: Generic Credential Type → `GitHub PAT: Fragua read`
  - Response Format: Text
  - Options → Continue On Fail: false (fail workflow if playbook fetch fails)

- [ ] **Node 9: Build System Prompt**
  - Type: `n8n-nodes-base.set`
  - Assignments:
    - `systemMessage` = `{{ "Eres un agente que ejecuta el siguiente playbook de investigación de competidores. Dispones de la herramienta tavily_search para buscar fuentes reales. El tema a investigar es: " + $('Parse /competitors Command').item.json.topic + ". Devuelve un informe markdown estructurado, con citas a URLs concretas. Si excedes ~3500 caracteres, divide la respuesta en partes numeradas.\n\n---\n\n" + $json.data }}`
  - Include other fields: true

- [ ] **Node 10: AI Agent**
  - Type: `@n8n/n8n-nodes-langchain.agent`
  - Prompt Type: Define below
  - Text: `{{ "Investiga competidores para: " + $('Parse /competitors Command').item.json.topic }}`
  - Options → System Message: `{{ $json.systemMessage }}`
  - Attach sub-nodes: OpenRouter Chat Model, Tavily Search (HTTP Request tool)

- [ ] **Node 11: OpenRouter Chat Model** (sub-node of AI Agent)
  - Type: `@n8n/n8n-nodes-langchain.lmChatOpenRouter`
  - Credential: `OpenRouter account`
  - Model: `anthropic/claude-sonnet-4.5`
  - Base URL: `https://openrouter.ai/api/v1`

- [ ] **Node 12: Tavily Search** (sub-node of AI Agent, HTTP Request tool)
  - Type: `@n8n/n8n-nodes-langchain.toolHttpRequest`
  - Name: `tavily_search`
  - Description: `Search the web for information about competitors, products, and market positioning. Returns URLs, titles, and content snippets.`
  - Method: POST
  - URL: `https://api.tavily.com/search`
  - Authentication: Generic Credential Type → `Tavily API: Research`
  - Body (JSON):
    ```json
    {
      "query": "={{ $json.query }}",
      "max_results": 5
    }
    ```
  - Response: JSON
  - (If `toolHttpRequest` sub-node doesn't exist, document in design.md § Open Questions and use alternative: custom Code tool node wrapping Tavily API)

- [ ] **Node 13: Split Response Into Chunks**
  - Type: `n8n-nodes-base.code`
  - Mode: Run Once for All Items
  - JavaScript:
    ```javascript
    const text = $input.item.json.output; // AI Agent output
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

    const chatId = $('Normalize Telegram Message').item.json.chatId;
    const messageId = $('Normalize Telegram Message').item.json.messageId;

    return chunks.map((chunk, i) => ({
      json: {
        chunk: `[${i+1}/${chunks.length}]\n\n${chunk}`,
        index: i + 1,
        total: chunks.length,
        chatId: chatId,
        messageId: messageId
      }
    }));
    ```

- [ ] **Node 14: Send Telegram Reply**
  - Type: `n8n-nodes-base.telegram`
  - Credential: `Telegram account`
  - Chat ID: `{{ $json.chatId }}`
  - Text: `{{ $json.chunk }}`
  - Additional Fields → Reply To Message ID: `{{ $json.index === 1 ? $json.messageId : '' }}`
  - (Runs once per chunk due to n8n's default per-item execution)

- [ ] **Wire connections** per design.md § Node Graph
- [ ] Verify all credentials attached by name (no inline secrets)

### 4. Test in n8n UI

**Test case 1: Empty topic (help message)**
- [ ] Execute/listen with Telegram Trigger
- [ ] Send `/competitors` (no topic) to the bot
- [ ] Verify workflow executes nodes 1-7 only
- [ ] Verify help message received in Telegram in <5 seconds
- [ ] Verify nodes 8-14 not executed

**Test case 2: Valid topic (full report)**
- [ ] Send `/competitors n8n alternatives` to the bot
- [ ] Verify workflow executes all nodes 1-14
- [ ] Verify playbook fetched successfully (node 8 output contains markdown)
- [ ] Verify system prompt built correctly (node 9 output contains operative header + playbook)
- [ ] Verify AI Agent calls Tavily at least once (check node 10 execution details)
- [ ] Verify report received in Telegram within 3 minutes
- [ ] Verify report contains:
  - At least 3 competitors
  - Each competitor: URL, positioning, audience, pricing, 2-3 features
  - Citations to real URLs (not invented)
- [ ] Verify chunking if report >3500 chars (multiple messages with `[1/N]`, `[2/N]`, etc.)

**Test case 3: Non-/competitors message**
- [ ] Send plain text message (e.g., `hello`) to the bot
- [ ] Verify workflow executes nodes 1-5 only
- [ ] Verify node 5 output: `ignored: true`, `reason: "not a /competitors command"`
- [ ] Verify no Telegram reply from this workflow
- [ ] (Note: `telegram-openrouter-chat` may reply if active; document behavior)

**Test case 4: Playbook fetch failure (simulated)**
- [ ] Temporarily change GitHub URL in node 8 to invalid branch (e.g., `nonexistent-branch`)
- [ ] Send `/competitors test` to the bot
- [ ] Verify workflow execution fails at node 8
- [ ] Verify error visible in n8n Executions tab
- [ ] Restore correct branch in node 8

**Test case 5: Tavily failure (simulated, optional)**
- [ ] Temporarily revoke Tavily API key in credential
- [ ] Send `/competitors test` to the bot
- [ ] Verify workflow execution fails at node 10 (AI Agent)
- [ ] Verify error visible in n8n Executions tab
- [ ] Restore Tavily API key

**Test case 6: Long report (chunking)**
- [ ] Send `/competitors project management tools` (broad topic likely to produce long report)
- [ ] Verify multiple Telegram messages received with `[1/N]`, `[2/N]`, etc.
- [ ] Verify each chunk <4096 chars (Telegram limit)
- [ ] Verify all chunks received in order

**Test case 7: Double-reply with `telegram-openrouter-chat` (if active)**
- [ ] If `telegram-openrouter-chat` is active, send `/competitors test`
- [ ] Verify both workflows reply (chat workflow gives conversational answer, this workflow gives report)
- [ ] Document behavior and confirm follow-up change needed
- [ ] Deactivate `telegram-openrouter-chat` for remaining tests if double-reply confirmed

- [ ] Inspect failed executions (if any) and fix red nodes
- [ ] Re-run tests until all green

### 5. Export and commit JSON

- [ ] In n8n UI: workflow menu → Download (JSON)
- [ ] Replace `workflows/research-competitors/workflow.json` with the downloaded file
- [ ] Verify workflow is inactive in JSON (`active: false` or field omitted)
- [ ] Verify credentials referenced by name/id only (no inline secrets):
  ```bash
  grep -i -E '(token|secret|api[_-]?key|password)' workflows/research-competitors/workflow.json
  ```
  (Should only match credential references, not literal values)

- [ ] Update `workflows/research-competitors/README.md` with:
  - Actual node list (copy from design.md § Nodes table)
  - Any deviations from design.md (e.g., node type versions, Tavily tool implementation)
  - Fragua repo coordinates (owner/repo/branch)
  - Test results summary

**Commit**: `feat(research-competitors): add workflow JSON and README`

### 6. Delete the UI-built copy and deploy from git

- [ ] In n8n UI: delete the workflow built in step 3 (after exporting JSON)
- [ ] Deploy from git source of truth:
  ```bash
  ./scripts/deploy-workflow.sh workflows/research-competitors/workflow.json
  ```
- [ ] Note the returned workflow ID and URL
- [ ] Open the workflow URL in n8n UI
- [ ] Verify nodes, tags, and credentials match the exported JSON

### 7. Final verification

- [ ] Activate the deployed workflow in n8n UI (toggle Active on)
- [ ] Send `/competitors test topic` via Telegram
- [ ] Verify report received (confirms end-to-end deployment success)
- [ ] Confirm at least one successful execution recorded in n8n Executions tab
- [ ] Confirm no secrets in git diff:
  ```bash
  git diff HEAD~1 | grep -i -E '(token|secret|api[_-]?key|password)'
  ```
  (Should be empty or only match credential names, not values)

- [ ] If `telegram-openrouter-chat` was deactivated for testing, decide:
  - Re-activate it and accept double-reply until follow-up change ships, OR
  - Keep it deactivated and ship follow-up change first, OR
  - Ship follow-up change `update-telegram-openrouter-chat-ignore-slash-commands` now before re-activating

## Verification Checklist

Run before marking the change complete:

- [ ] `workflow.json` is in git and matches the deployed workflow (export from UI and `git diff` to confirm)
- [ ] `README.md` lists every credential by canonical name:
  - `Telegram account`
  - `OpenRouter account`
  - `Tavily API: Research`
  - `GitHub PAT: Fragua read`
- [ ] No secrets in `workflow.json` (final grep clean)
- [ ] Workflow is active in n8n UI
- [ ] At least one successful `/competitors` execution recorded in Executions tab
- [ ] Report quality meets success criteria:
  - ≥3 competitors
  - Each with URL, positioning, audience, pricing, features
  - Real URLs cited (Tavily-sourced)
- [ ] Latency acceptable (<3 min for typical topics)
- [ ] Help message works (`/competitors` with no topic → help in <5s)
- [ ] Chunking works (long reports paginated with `[i/N]`)
- [ ] Double-reply behavior documented (if `telegram-openrouter-chat` active)
- [ ] Follow-up change decision documented (ignore slash commands in chat workflow)

## Post-Implementation Follow-ups

- [ ] **Optional**: Ship `update-telegram-openrouter-chat-ignore-slash-commands` to prevent double-reply
  - Add IF node after Normalize Telegram Message in chat workflow
  - Condition: `{{ !$json.input.startsWith('/') }}`
  - True branch → continue to AI Agent
  - False branch → Ignore (NoOp/Set)
  - Test, export, commit, deploy

- [ ] **Optional**: Add error workflow for graceful Telegram error messages instead of silent failures
  - Create shared error workflow that sends Telegram message on workflow failure
  - Attach to this workflow via Settings → Error Workflow

- [ ] **Optional**: Monitor Tavily quota usage in Tavily dashboard
  - Set up alert if approaching monthly limit
  - Document quota in README

- [ ] **Optional**: Pin playbook to specific commit SHA if Fragua playbook changes break workflow
  - Update GitHub URL in node 8 from `/main/` to `/<commit-sha>/`
  - Document in README why pinned
