# Design: Telegram OpenRouter Chat

## Overview

This workflow receives Telegram bot text messages, sends them to an OpenRouter-backed AI Agent, persists conversation history in Postgres Chat Memory, and replies in the same Telegram chat. It is implemented as a dedicated workflow instead of integrating with n8n's default internal chat because the default chat is not available as a reusable workflow surface.

## Trigger

- **Type**: App event
- **Configuration**:
- Telegram Trigger receives all incoming updates for the configured bot credential.
- The workflow processes text messages only.
- The bot replies to every text message, not only slash commands.

## Node Graph

```text
Telegram Trigger
   |
   v
Normalize Telegram Message
   |
   v
Is Text Message?
   | false
   v
Ignore Non-Text

Is Text Message?
   | true
   v
AI Agent
   |-- OpenRouter Chat Model
   |-- Postgres Chat Memory
   |
   v
Send Telegram Reply
```

## Nodes

| # | Node | Type | Purpose | Notes |
|---|------|------|---------|-------|
| 1 | Telegram Trigger | `n8n-nodes-base.telegramTrigger` | Receive Telegram bot messages. | Uses `Telegram account`. |
| 2 | Normalize Telegram Message | Set/Edit Fields | Produce stable fields for the agent and reply node. | Creates `input`, `chatId`, `userId`, `sessionId`, and `messageId`. |
| 3 | Is Text Message? | IF | Continue only when `input` is non-empty text. | Prevents images/files/stickers from hitting the LLM. |
| 4 | Ignore Non-Text | NoOp/Set | End unsupported message executions cleanly. | Optional Telegram notice can be added later. |
| 5 | AI Agent | LangChain AI Agent | Generate the assistant response. | Uses OpenRouter model and Postgres memory. |
| 6 | OpenRouter Chat Model | OpenRouter chat model | Call OpenRouter model `anthropic/claude-3.5-sonnet`. | Uses native OpenRouter credential type. |
| 7 | Postgres Chat Memory | LangChain Postgres memory | Persist conversation history by Telegram chat. | Session key `={{ $json.sessionId }}`. |
| 8 | Send Telegram Reply | `n8n-nodes-base.telegram` | Send agent output back to Telegram. | Chat ID `={{ $json.chatId }}`. |

## Credentials

Workflow references credentials **by name** and never stores credential values inline.

| Credential Name | Type | Used By Node | Owner |
|---|---|---|---|
| `Telegram account` | Telegram Bot API token | Telegram Trigger, Send Telegram Reply | Operator |
| `OpenRouter account` | OpenRouter API key | OpenRouter Chat Model | Operator |
| `Postgres account` | Postgres connection | Postgres Chat Memory | Operator |

## Data Flow

- **Input shape**: Telegram update payload from the Telegram Trigger.
- **Normalized fields**:

```text
input = {{$json.message.text}}
chatId = {{$json.message.chat.id}}
userId = {{$json.message.from.id}}
messageId = {{$json.message.message_id}}
sessionId = telegram:{{$json.message.chat.id}}
```

- **Agent input**: `={{ $json.input }}`.
- **Memory session key**: `={{ $json.sessionId }}`.
- **Telegram output**:

```text
chatId = {{$json.chatId}}
text = <AI Agent final response>
```

## Error Handling

- Non-text messages are ignored before the LLM call to avoid unnecessary OpenRouter usage.
- OpenRouter or AI Agent failures should surface as failed n8n executions during the first implementation. A later enhancement can add a fallback Telegram message.
- Telegram send failures should fail the execution so they are visible in n8n's Executions tab.
- Duplicate Telegram updates are low risk because each message may produce another response; no idempotency store is planned initially.

## Observability

- n8n UI -> Executions shows each Telegram message execution and node-level payloads/errors.
- Postgres Chat Memory stores conversation history by `telegram:<chat_id>` for persistence verification.
- Telegram chat history provides user-facing response verification.

## Open Questions

- Confirm exact node type/version names for AI Agent, OpenAI-compatible Chat Model, and Postgres Chat Memory in n8n 2.19.4 using n8n-mcp or UI.
- Confirm whether `Postgres: n8n Memory` points to an existing database/schema suitable for chat memory tables.
- Decide whether to add chat allowlisting after the first working version.

## Decisions

- **Dedicated workflow**: Telegram integration is separate from n8n's default chat UI because the internal chat is not a workflow surface.
- **Respond to all text messages**: The bot is assumed to be dedicated to this chat use case, so slash commands are not required.
- **Postgres memory**: Persistent conversation state is required, so Simple/Window memory is not sufficient.
- **Telegram chat ID session key**: `telegram:<chat_id>` isolates private chats and groups while keeping the session key stable.
- **OpenRouter Claude model**: Use `anthropic/claude-3.5-sonnet` per product requirement.
