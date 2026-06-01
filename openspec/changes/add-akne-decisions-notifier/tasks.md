# Tasks: Akne Decisions Notifier (Fase 1)

## Pre-requisites (Manual — DO BEFORE IMPLEMENTATION)

### GitHub Setup

- [ ] **Crear GitHub Fine-grained PAT**
  - GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
  - Token name: `akne-n8n`
  - Repository access: Only select repositories → `elevenyellow/akne`
  - Permissions:
    - Contents → Read and write
    - Pull requests → Read and write
  - Expiration: 90 días (o custom)
  - Generate token, copiar valor

- [ ] **Crear credential `GitHub: akne PAT` en n8n UI**
  - `https://n8n.rola.dev/` → Credentials → Add Credential
  - Type: Header Auth
  - Name: `Authorization`
  - Value: `Bearer <token>`
  - Credential name: `GitHub: akne PAT`
  - Test (no debería dar error)

### Slack Setup

- [ ] **Crear Slack App `Akne Assistant`**
  - https://api.slack.com/apps → Create New App → From scratch
  - App Name: `Akne Assistant`
  - Workspace: seleccionar el workspace correcto

- [ ] **Configurar Bot Token Scopes**
  - OAuth & Permissions → Bot Token Scopes:
    - `chat:write`
    - `channels:read`

- [ ] **Instalar App en Workspace**
  - OAuth & Permissions → Install to Workspace
  - Autorizar
  - Copiar **Bot User OAuth Token** (`xoxb-...`)

- [ ] **Obtener Signing Secret**
  - Basic Information → App Credentials → Signing Secret
  - Copiar valor

- [ ] **Crear credential `Slack: Akne Assistant` en n8n UI**
  - Type: Slack API
  - Credential name: `Slack: Akne Assistant`
  - Access Token: pegar `xoxb-...`
  - Signing Secret: pegar
  - Test connection

- [ ] **Invitar bot al canal `#akne`**
  - En Slack: ir a `#akne`
  - `/invite @Akne Assistant`
  - Verificar que el bot aparece en miembros del canal

### Postgres Setup

- [ ] **Verificar credential `Postgres account`**
  - Confirmar que existe y conecta OK

- [ ] **Crear tabla `akne_decision_threads`**
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

### n8n Environment Setup

- [ ] **Generar webhook secret**
  ```bash
  openssl rand -hex 32
  ```
  Guardar el valor generado.

- [ ] **Agregar variable de entorno `GITHUB_WEBHOOK_SECRET_AKNE` a n8n**
  - En cloudbox/ansible o donde se configure n8n
  - Reiniciar n8n si es necesario para que tome la variable

- [ ] **Confirmar `.env` local tiene `N8N_API_KEY`**
  ```bash
  grep N8N_API_KEY .env
  ```

---

## Implementation Tasks

### 1. Scaffold workflow directory

- [ ] `mkdir -p workflows/akne-decisions-notifier`
- [ ] Crear `workflows/akne-decisions-notifier/workflow.json` (vacío inicialmente)
- [ ] Crear `workflows/akne-decisions-notifier/README.md` con estructura básica

**Commit**: `feat(akne-decisions-notifier): scaffold workflow directory`

### 2. Build workflow in n8n UI

#### 2.1 Setup inicial
- [ ] n8n UI → New Workflow
- [ ] Nombre: `Akne Decisions Notifier`
- [ ] Tags: `github`, `slack`, `akne`, `production`

#### 2.2 Webhook Trigger
- [ ] Agregar node: Webhook
  - HTTP Method: POST
  - Path: `akne-decisions`
  - Response Mode: Immediately
  - Response Code: 200
- [ ] Anotar la URL completa del webhook

#### 2.3 Validate Signature (Code)
- [ ] Agregar node: Code
- [ ] Nombre: `Validate Webhook Signature`
- [ ] Código: (ver design.md Node #2)

#### 2.4 Filter Main Branch (IF)
- [ ] Agregar node: IF
- [ ] Nombre: `Is Push to Main?`
- [ ] Condición: `{{ $json.body.ref }}` equals `refs/heads/main`

#### 2.5 Extract Files (Code)
- [ ] Agregar node: Code
- [ ] Nombre: `Extract Modified Files`
- [ ] Código: (ver design.md Node #4)

#### 2.6 Filter Decision Files (Code)
- [ ] Agregar node: Code
- [ ] Nombre: `Filter Decision Files`
- [ ] Código: (ver design.md Node #5)

#### 2.7 Loop (SplitInBatches)
- [ ] Agregar node: SplitInBatches
- [ ] Nombre: `Loop Files`
- [ ] Batch Size: 1

#### 2.8 Fetch File Content (HTTP Request)
- [ ] Agregar node: HTTP Request
- [ ] Nombre: `Fetch File Content`
- [ ] Method: GET
- [ ] URL: `https://api.github.com/repos/{{ $json.repo }}/contents/{{ $json.path }}?ref=main`
- [ ] Headers:
  - Accept: `application/vnd.github.raw`
- [ ] Authentication: Predefined Credential Type → Header Auth → `GitHub: akne PAT`
- [ ] Options: On Error → Continue

#### 2.9 Parse Frontmatter (Code)
- [ ] Agregar node: Code
- [ ] Nombre: `Parse Frontmatter`
- [ ] Código: (ver design.md Node #8)

#### 2.10 Filter Pending (IF)
- [ ] Agregar node: IF
- [ ] Nombre: `Is Status Pending?`
- [ ] Condiciones:
  - `{{ $json.frontmatter.status }}` equals `pending`
  - AND `{{ $json.skip }}` not equals `true`

#### 2.11 Check Already Notified (Postgres)
- [ ] Agregar node: Postgres
- [ ] Nombre: `Check Already Notified`
- [ ] Operation: Execute Query
- [ ] Query: `SELECT * FROM akne_decision_threads WHERE decision_id = '{{ $json.frontmatter.id }}'`
- [ ] Credential: `Postgres account`

#### 2.12 Filter New (IF)
- [ ] Agregar node: IF
- [ ] Nombre: `Is New Decision?`
- [ ] Condición: resultado del SELECT está vacío

#### 2.13 Build Slack Message (Code)
- [ ] Agregar node: Code
- [ ] Nombre: `Build Slack Message`
- [ ] Código: (ver design.md Node #12)

#### 2.14 Post to Slack
- [ ] Agregar node: Slack
- [ ] Nombre: `Post to Slack`
- [ ] Resource: Message
- [ ] Operation: Send
- [ ] Channel: `{{ $json.channel }}`
- [ ] Text: `{{ $json.text }}`
- [ ] Blocks: `{{ JSON.stringify($json.blocks) }}`
- [ ] Credential: `Slack: Akne Assistant`

#### 2.15 Save Thread Mapping (Postgres)
- [ ] Agregar node: Postgres
- [ ] Nombre: `Save Thread Mapping`
- [ ] Operation: Execute Query
- [ ] Query:
  ```sql
  INSERT INTO akne_decision_threads (decision_id, file_path, slack_thread_ts, slack_channel, github_repo)
  VALUES (
    '{{ $('Build Slack Message').item.json.decisionId }}',
    '{{ $('Build Slack Message').item.json.filePath }}',
    '{{ $json.ts }}',
    '{{ $('Build Slack Message').item.json.channel }}',
    '{{ $('Build Slack Message').item.json.repo }}'
  )
  ```
- [ ] Credential: `Postgres account`

#### 2.16 Connect Loop
- [ ] Conectar `Save Thread Mapping` de vuelta a `Loop Files` (done output)

### 3. Configure GitHub Webhook

- [ ] Ir a `elevenyellow/akne` → Settings → Webhooks → Add webhook
- [ ] Payload URL: `https://n8n.rola.dev/webhook/akne-decisions`
- [ ] Content type: `application/json`
- [ ] Secret: valor de `GITHUB_WEBHOOK_SECRET_AKNE`
- [ ] Events: Just the push event
- [ ] Active: ✓
- [ ] Add webhook

### 4. Test in n8n UI

- [ ] **Test con archivo de prueba**:
  - Crear `docs/decisions/business/test-001.md` en repo akne con frontmatter `status: pending`
  - Commit y push a `main`

- [ ] **Verificar ejecución en n8n**:
  - Ir a Executions
  - Confirmar todos los nodos ejecutaron OK (verde)

- [ ] **Verificar mensaje en Slack**:
  - Ir a `#akne`
  - Confirmar mensaje con formato correcto
  - Verificar link a GitHub funciona

- [ ] **Verificar Postgres**:
  ```sql
  SELECT * FROM akne_decision_threads WHERE decision_id = 'test-001';
  ```

- [ ] **Test deduplicación**:
  - Re-push el mismo archivo
  - Verificar que NO aparece mensaje duplicado

- [ ] **Test filtros**:
  - Push archivo con `status: answered` → NO debe postear
  - Push archivo fuera de `docs/decisions/business/` → NO debe postear

- [ ] **Cleanup**:
  - Borrar archivo test del repo
  - Borrar mensaje de Slack (opcional)
  - `DELETE FROM akne_decision_threads WHERE decision_id = 'test-001';`

### 5. Export and commit JSON

- [ ] n8n UI → workflow menu → Download
- [ ] Copiar JSON a `workflows/akne-decisions-notifier/workflow.json`
- [ ] Verificar `"active": false` en el JSON
- [ ] Scan de secretos:
  ```bash
  grep -iE '(token|secret|api[_-]?key|password|xoxb)' workflows/akne-decisions-notifier/workflow.json
  ```
- [ ] Actualizar README con lista de nodos final

**Commit**: `feat(akne-decisions-notifier): add workflow JSON and README`

### 6. Deploy from git

- [ ] Borrar workflow de prueba en n8n UI
- [ ] Ejecutar:
  ```bash
  ./scripts/deploy-workflow.sh workflows/akne-decisions-notifier/workflow.json
  ```
- [ ] Anotar workflow ID y URL
- [ ] Verificar en UI que aparece correctamente

### 7. Final verification

- [ ] Activar workflow en n8n UI
- [ ] Crear decisión real o de prueba
- [ ] Push a main
- [ ] Confirmar mensaje en `#akne`
- [ ] Confirmar registro en Postgres
- [ ] Confirmar al menos 1 ejecución exitosa

### 8. Archive change

- [ ] Mover `openspec/changes/add-akne-decisions-notifier/` a `openspec/changes/archive/`
- [ ] Actualizar status en proposal.md a **Completed**

**Commit**: `chore(openspec): archive add-akne-decisions-notifier`

---

## Verification Checklist

- [ ] `workflow.json` en git, matches deployed
- [ ] README lista todas las credentials por nombre canónico
- [ ] No secrets en `workflow.json`
- [ ] Workflow activo en n8n UI
- [ ] GitHub webhook configurado y entregando
- [ ] Slack bot en canal `#akne` y posteando
- [ ] Tabla Postgres creada con schema correcto
- [ ] Al menos 1 ejecución exitosa end-to-end
- [ ] Deduplicación funciona
- [ ] Filtros funcionan
