# Design: Akne Decisions Notifier (Fase 1)

## Overview

Este workflow recibe webhooks de GitHub cuando hay push a `main` en el repo `elevenyellow/akne`, filtra commits que afectan archivos `.md` en `docs/decisions/business/`, verifica que el frontmatter contenga `status: pending`, extrae el contenido estructurado del archivo, y postea un mensaje formateado en Slack como inicio de thread. El mapping entre `decision_id` y `slack_thread_ts` se persiste en Postgres para uso en Fase 2.

No se usa LLM en esta fase — el mensaje se construye directamente desde el frontmatter YAML y las secciones markdown usando un Code node.

## Trigger

- **Type**: Webhook
- **Configuration**:
  - Path: `/webhook/akne-decisions` (o UUID autogenerado por n8n)
  - Method: POST
  - Auth: GitHub webhook secret (HMAC SHA-256) via `GITHUB_WEBHOOK_SECRET_AKNE`
  - Events: `push` (solo)

### GitHub Webhook Setup

1. Repo `elevenyellow/akne` → Settings → Webhooks → Add webhook
2. Payload URL: `https://n8n.rola.dev/webhook/<path>`
3. Content type: `application/json`
4. Secret: valor de `GITHUB_WEBHOOK_SECRET_AKNE`
5. Events: Just the push event

## Node Graph

```
Webhook Trigger (GitHub Push)
   │
   ▼
Validate Webhook Signature ──(invalid)──► Stop & Return 401
   │ (valid)
   ▼
Is Push to Main? ──(no)──► Stop (ignore)
   │ (yes)
   ▼
Extract Modified Files (Code)
   │
   ▼
Filter Decision Files (Code) ──(none)──► Stop (no relevant files)
   │ (some)
   ▼
┌─► Loop: For Each File (SplitInBatches)
│      │
│      ▼
│   Fetch File Content (HTTP Request → GitHub API)
│      │
│      ▼
│   Parse Frontmatter & Sections (Code)
│      │
│      ▼
│   Is Status Pending? ──(no)──► Continue Loop
│      │ (yes)
│      ▼
│   Check Already Notified (Postgres SELECT)
│      │
│      ▼
│   Is New Decision? ──(no)──► Continue Loop
│      │ (yes)
│      ▼
│   Build Slack Message (Code)
│      │
│      ▼
│   Post to Slack #akne
│      │
│      ▼
│   Save Thread Mapping (Postgres INSERT)
│      │
└──────┘
   │
   ▼
End
```

## Nodes

| # | Node | Type | Purpose | Notes |
|---|------|------|---------|-------|
| 1 | Webhook Trigger | `n8n-nodes-base.webhook` | Recibe push events de GitHub | Path: `akne-decisions`, Method: POST |
| 2 | Validate Signature | `n8n-nodes-base.code` | Verifica HMAC SHA-256 | Lee `GITHUB_WEBHOOK_SECRET_AKNE` de env |
| 3 | Is Push to Main? | `n8n-nodes-base.if` | Filtra por `ref === 'refs/heads/main'` | |
| 4 | Extract Modified Files | `n8n-nodes-base.code` | Extrae `added` + `modified` de commits | Deduplica archivos |
| 5 | Filter Decision Files | `n8n-nodes-base.code` | Filtra `docs/decisions/business/*.md` | Retorna array de paths |
| 6 | Loop Files | `n8n-nodes-base.splitInBatches` | Procesa cada archivo | Batch size: 1 |
| 7 | Fetch File Content | `n8n-nodes-base.httpRequest` | GET contenido via GitHub API | Usa `GitHub: akne PAT` |
| 8 | Parse Frontmatter | `n8n-nodes-base.code` | Extrae YAML + secciones markdown | Ver código abajo |
| 9 | Is Status Pending? | `n8n-nodes-base.if` | Continúa solo si `status === 'pending'` | |
| 10 | Check Already Notified | `n8n-nodes-base.postgres` | SELECT por `decision_id` | Usa `Postgres account` |
| 11 | Is New Decision? | `n8n-nodes-base.if` | Continúa solo si no hay registro | |
| 12 | Build Slack Message | `n8n-nodes-base.code` | Construye blocks de Slack | Sin LLM, template-based |
| 13 | Post to Slack | `n8n-nodes-base.slack` | Envía mensaje a `#akne` | Usa `Slack: Akne Assistant` |
| 14 | Save Thread Mapping | `n8n-nodes-base.postgres` | INSERT mapping | Guarda `thread_ts` para Fase 2 |

## Credentials

| Credential Name | Type | Used By Node | Notes |
|---|---|---|---|
| `GitHub: akne PAT` | Header Auth | Fetch File Content (#7) | `Authorization: Bearer <token>` |
| `Slack: Akne Assistant` | Slack API | Post to Slack (#13) | Access Token (`xoxb-...`) + Signing Secret |
| `Postgres account` | Postgres | Check (#10), Save (#14) | Shared credential |

**Environment Variable**:
- `GITHUB_WEBHOOK_SECRET_AKNE` — usado en Code node #2 para validar signature

## Data Flow

### 1. Input: GitHub Webhook Payload

```json
{
  "ref": "refs/heads/main",
  "repository": {
    "full_name": "elevenyellow/akne"
  },
  "commits": [
    {
      "id": "abc123def456",
      "added": ["docs/decisions/business/001-pricing-tiers.md"],
      "modified": [],
      "removed": []
    }
  ]
}
```

### 2. Decision File Format (Contract)

```markdown
---
id: "001"
title: Pricing tiers
status: pending
created: 2026-06-01
owner_question: dev
owner_answer: pm
---

# Decision 001: Pricing tiers

## Context
Necesitamos definir los tiers de pricing para el lanzamiento.
El mercado tiene competidores con modelos freemium y enterprise.

## Options
- A: Freemium + Pro ($29/mo) + Enterprise (custom)
- B: Solo paid tiers: Starter ($19/mo) + Pro ($49/mo)
- C: Usage-based pricing sin tiers fijos

## Question for PM
¿Cuál modelo se alinea mejor con nuestra estrategia de go-to-market?

## PM Answer
<!-- Fase 2: aquí irá la respuesta -->

## Discussion log
<!-- Fase 2: log de la conversación -->
```

### 3. Parsed Data (output of node #8)

```json
{
  "frontmatter": {
    "id": "001",
    "title": "Pricing tiers",
    "status": "pending",
    "created": "2026-06-01",
    "owner_question": "dev",
    "owner_answer": "pm"
  },
  "sections": {
    "context": "Necesitamos definir los tiers de pricing...",
    "options": "- A: Freemium + Pro ($29/mo)...\n- B: Solo paid tiers...\n- C: Usage-based...",
    "question": "¿Cuál modelo se alinea mejor con nuestra estrategia de go-to-market?"
  },
  "filePath": "docs/decisions/business/001-pricing-tiers.md",
  "repo": "elevenyellow/akne"
}
```

### 4. Slack Message (output of node #12)

```json
{
  "channel": "#akne",
  "text": "Nueva decisión pendiente: Pricing tiers",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "Decision 001: Pricing tiers",
        "emoji": true
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Contexto*\nNecesitamos definir los tiers de pricing para el lanzamiento. El mercado tiene competidores con modelos freemium y enterprise."
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Opciones consideradas*\n• A: Freemium + Pro ($29/mo) + Enterprise (custom)\n• B: Solo paid tiers: Starter ($19/mo) + Pro ($49/mo)\n• C: Usage-based pricing sin tiers fijos"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Pregunta para PM*\n¿Cuál modelo se alinea mejor con nuestra estrategia de go-to-market?"
      }
    },
    {
      "type": "divider"
    },
    {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "<https://github.com/elevenyellow/akne/blob/main/docs/decisions/business/001-pricing-tiers.md|Ver en GitHub>"
        }
      ]
    }
  ]
}
```

### 5. Postgres Record (after node #14)

```json
{
  "id": 1,
  "decision_id": "001",
  "file_path": "docs/decisions/business/001-pricing-tiers.md",
  "slack_thread_ts": "1717234567.123456",
  "slack_channel": "#akne",
  "github_repo": "elevenyellow/akne",
  "created_at": "2026-06-01T10:30:00Z",
  "updated_at": "2026-06-01T10:30:00Z"
}
```

## Postgres Schema

```sql
CREATE TABLE IF NOT EXISTS akne_decision_threads (
  id SERIAL PRIMARY KEY,
  decision_id VARCHAR(50) NOT NULL UNIQUE,
  file_path VARCHAR(255) NOT NULL,
  slack_thread_ts VARCHAR(50) NOT NULL,
  slack_channel VARCHAR(100) NOT NULL DEFAULT '#akne',
  github_repo VARCHAR(100) NOT NULL DEFAULT 'elevenyellow/akne',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_akne_decision_id 
  ON akne_decision_threads(decision_id);
```

## Code Snippets

### Node #2: Validate Webhook Signature

```javascript
const crypto = require('crypto');

const signature = $input.first().json.headers['x-hub-signature-256'];
const payload = JSON.stringify($input.first().json.body);
const secret = $env.GITHUB_WEBHOOK_SECRET_AKNE;

if (!signature || !secret) {
  throw new Error('Missing signature or secret');
}

const expected = 'sha256=' + crypto
  .createHmac('sha256', secret)
  .update(payload, 'utf8')
  .digest('hex');

if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
  throw new Error('Invalid webhook signature');
}

return $input.all();
```

### Node #4: Extract Modified Files

```javascript
const body = $input.first().json.body;
const commits = body.commits || [];
const filesSet = new Set();

for (const commit of commits) {
  for (const file of [...(commit.added || []), ...(commit.modified || [])]) {
    filesSet.add(file);
  }
}

const files = Array.from(filesSet);
return [{ json: { files, repo: body.repository.full_name } }];
```

### Node #5: Filter Decision Files

```javascript
const { files, repo } = $input.first().json;
const pattern = /^docs\/decisions\/business\/.*\.md$/;

const decisionFiles = files.filter(f => pattern.test(f));

if (decisionFiles.length === 0) {
  return []; // Stops workflow (no items)
}

return decisionFiles.map(path => ({ json: { path, repo } }));
```

### Node #8: Parse Frontmatter & Sections

```javascript
const content = $input.first().json.data; // Raw markdown from GitHub API
const filePath = $('Filter Decision Files').item.json.path;
const repo = $('Filter Decision Files').item.json.repo;

// Extract frontmatter
const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
if (!fmMatch) {
  return [{ json: { skip: true, reason: 'No frontmatter found' } }];
}

// Parse YAML manually (simple key: value)
const lines = fmMatch[1].split('\n');
const frontmatter = {};
for (const line of lines) {
  const colonIndex = line.indexOf(':');
  if (colonIndex > 0) {
    const key = line.slice(0, colonIndex).trim();
    const value = line.slice(colonIndex + 1).trim().replace(/^["']|["']$/g, '');
    frontmatter[key] = value;
  }
}

// Extract sections
const body = content.slice(fmMatch[0].length);

function extractSection(name) {
  const regex = new RegExp(`## ${name}\\n([\\s\\S]*?)(?=\\n## |$)`, 'i');
  const match = body.match(regex);
  return match ? match[1].trim() : '';
}

const sections = {
  context: extractSection('Context'),
  options: extractSection('Options'),
  question: extractSection('Question for PM')
};

return [{
  json: {
    frontmatter,
    sections,
    filePath,
    repo
  }
}];
```

### Node #12: Build Slack Message

```javascript
const data = $('Parse Frontmatter').item.json;
const { frontmatter, sections, filePath, repo } = data;
const githubUrl = `https://github.com/${repo}/blob/main/${filePath}`;

// Convert markdown list to Slack bullets
const formatOptions = (text) => {
  return text.replace(/^- /gm, '• ').replace(/^\* /gm, '• ');
};

// Truncate to avoid Slack block limits
const truncate = (text, max = 2500) => {
  if (text.length <= max) return text;
  return text.slice(0, max) + '...';
};

const blocks = [
  {
    type: 'header',
    text: {
      type: 'plain_text',
      text: `Decision ${frontmatter.id}: ${frontmatter.title}`,
      emoji: true
    }
  },
  {
    type: 'section',
    text: {
      type: 'mrkdwn',
      text: `*Contexto*\n${truncate(sections.context)}`
    }
  },
  {
    type: 'section',
    text: {
      type: 'mrkdwn',
      text: `*Opciones consideradas*\n${truncate(formatOptions(sections.options))}`
    }
  },
  {
    type: 'section',
    text: {
      type: 'mrkdwn',
      text: `*Pregunta para PM*\n${truncate(sections.question)}`
    }
  },
  {
    type: 'divider'
  },
  {
    type: 'context',
    elements: [
      {
        type: 'mrkdwn',
        text: `<${githubUrl}|Ver en GitHub>`
      }
    ]
  }
];

return [{
  json: {
    channel: '#akne',
    text: `Nueva decisión pendiente: ${frontmatter.title}`,
    blocks,
    decisionId: frontmatter.id,
    filePath,
    repo
  }
}];
```

## Error Handling

| Node | Error Scenario | Handling |
|------|---------------|----------|
| #2 Validate Signature | Invalid/missing signature | Throw error → execution fails, returns 500 to GitHub |
| #3 Is Push to Main? | Not main branch | Normal stop (no error) |
| #5 Filter Decision Files | No matching files | Return empty array → workflow ends cleanly |
| #7 Fetch File Content | GitHub API error (404, 401, rate limit) | Continue on fail → skip file, log error |
| #8 Parse Frontmatter | Malformed YAML | Return `{ skip: true }` → filtered out by next IF |
| #13 Post to Slack | Slack API error | Fail execution → visible in n8n, don't save to Postgres |
| #14 Save to Postgres | DB error | Fail execution → Slack message posted but not tracked (manual fix needed) |

### Idempotency

- **Deduplication key**: `decision_id` (from frontmatter)
- Si el mismo archivo se re-pushea, el check en Postgres (#10) evita mensaje duplicado
- Si Slack post (#13) falla y se reintenta, no hay side effects previos
- Si Postgres insert (#14) falla después de Slack post, hay inconsistencia temporal (mensaje sin tracking) — aceptable para Fase 1, se puede resolver manualmente

## Observability

- **n8n Executions**: cada webhook genera una ejecución visible con payloads por nodo
- **Postgres audit**: tabla `akne_decision_threads` como registro de todas las notificaciones
- **Slack channel**: mensajes visibles en `#akne` para el equipo
- **GitHub webhook deliveries**: Settings → Webhooks → Recent Deliveries para debug

## Decisions

1. **Webhook push-based**: Latencia mínima, eficiente en API calls vs polling.

2. **Code nodes para parsing**: El formato del archivo es estructurado y predecible. No se necesita LLM para interpretar — eso se reserva para Fases 2-4.

3. **Postgres para thread mapping**: Necesario para Fase 2 (asociar respuesta del PM con archivo). También provee deduplicación y audit trail.

4. **Slack API con Access Token**: Más simple que OAuth2, evita configuración adicional del reverse proxy en cloudbox.

5. **Deduplicación por `decision_id`**: El `id` del frontmatter es clave natural. Re-push no crea duplicados.

6. **Un thread por decisión**: Cada `.md` genera su propio thread, permitiendo discusiones paralelas.

7. **HMAC validation con `timingSafeEqual`**: Previene timing attacks en la comparación de signatures.

8. **Truncation silenciosa**: Contenido largo se trunca a 2500 chars con `...` para cumplir límites de Slack blocks.
