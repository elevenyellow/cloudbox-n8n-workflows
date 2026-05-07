# Design: <Workflow Name>

## Overview

<2–3 sentences describing what the workflow does end-to-end and why this shape was chosen over alternatives.>

## Trigger

- **Type**: <Manual | Webhook | Schedule | App event>
- **Configuration**:
  - <e.g. Cron: `0 8 * * *` Europe/Madrid>
  - <e.g. Webhook path: `/hooks/<name>`, method: POST, auth: header token>
  - <e.g. Telegram trigger: bot `@my_bot`, command `/digest`>

## Node Graph

```
<Trigger>
   │
   ▼
<Node 1: e.g. HTTP Request — fetch source>
   │
   ▼
<Node 2: e.g. Set — normalize fields>
   │
   ▼
<Node 3: e.g. IF — branch on condition>
   ├── true ──► <Node 4a>
   └── false ─► <Node 4b>
              │
              ▼
        <Sink: e.g. Slack / DB / Webhook>
```

## Nodes

| # | Node | Type | Purpose | Notes |
|---|------|------|---------|-------|
| 1 | <name> | <n8n type> | <one line> | <retry, timeout, expression notes> |
| 2 | <name> | <n8n type> | <one line> | |
| 3 | <name> | <n8n type> | <one line> | |

## Credentials

Workflow references credentials **by name** (never inline). All must exist in n8n before deployment.

| Credential Name | Type | Used By Node | Owner |
|---|---|---|---|
| `<Service>: <Purpose>` | <OAuth2 / API Key / Basic Auth> | <node #> | <who manages rotation> |

## Data Flow

- **Input shape**: <JSON schema or example payload at the trigger>
- **Transformations**: <how data mutates between nodes — link to expressions if non-trivial>
- **Output shape**: <what the final node emits / sends>

## Error Handling

- <Node-level: which nodes have `Continue On Fail` or retry, and why>
- <Workflow-level: error workflow attached? Telegram alert?>
- <Idempotency: can the workflow run twice on the same input safely? If not, document the dedupe key>

## Observability

- <Where to look for execution history (n8n UI → Executions)>
- <Any logging/notification on failure (e.g. Telegram alert via shared error workflow)>

## Open Questions

- <Anything unresolved that the build phase needs to answer before deploying>

## Decisions

- **<Decision title>**: <choice taken> — <one-sentence rationale>.
