# Tasks: <Workflow Name>

## Pre-requisites (Manual — DO BEFORE IMPLEMENTATION)

- [ ] **Confirm credentials exist in n8n UI**
  - Open `https://n8n.rola.dev/` → Credentials
  - Verify each credential listed in `design.md` § Credentials is present and tests OK
  - If missing: create with the canonical name `<Service>: <Purpose>`

- [ ] **Confirm `.env` is loaded locally**
  ```bash
  grep N8N_API_KEY .env  # must return a non-empty value
  ```

- [ ] **(If webhook trigger) Decide on path and auth**
  - Path: `/hooks/<name>`
  - Auth: <header token | basic | none + ACL upstream>

## Implementation Tasks

### 1. Scaffold workflow directory

- [ ] `mkdir workflows/<workflow-name>`
- [ ] Create empty `workflows/<workflow-name>/workflow.json` (will paste exported JSON later)
- [ ] Create `workflows/<workflow-name>/README.md` from the template (Purpose, Trigger, Nodes, Credentials Required, Deployment, Testing)

**Commit**: `feat(<workflow-name>): scaffold workflow directory`

### 2. Build workflow in n8n UI

- [ ] Open n8n UI → New Workflow
- [ ] Add trigger node per `design.md`
- [ ] Add nodes 1..N per `design.md` § Node Graph
- [ ] Wire connections, set expressions
- [ ] Attach credentials by name (no inline secrets)
- [ ] Set workflow name to `<workflow-name>` and add tags

### 3. Test in n8n UI

- [ ] Execute workflow manually with a representative input
- [ ] Inspect each node's output — fix red nodes
- [ ] Re-run until all nodes are green and final output matches the expected shape in `design.md`
- [ ] Test edge cases: <list 1–3 from design.md § Error Handling>

### 4. Export and commit JSON

- [ ] In n8n UI: workflow menu → Download (JSON)
- [ ] Replace `workflows/<workflow-name>/workflow.json` with the downloaded file
- [ ] Verify `active: false` in the JSON (we activate later, after API deploy)
- [ ] `grep -i -E '(token|secret|api[_-]?key|password)' workflows/<workflow-name>/workflow.json` — must be empty
- [ ] Update README with the actual node list and any deviations from design.md

**Commit**: `feat(<workflow-name>): add workflow JSON and README`

### 5. Delete the UI-built copy and deploy from git

- [ ] In n8n UI: delete the workflow built in step 2 (we will redeploy from git as the source of truth)
- [ ] `./scripts/deploy-workflow.sh workflows/<workflow-name>/workflow.json`
- [ ] Note the returned workflow ID and URL
- [ ] Open URL — verify workflow appears with correct nodes, tags, credentials bound

### 6. Final verification

- [ ] Manual execution from the deployed workflow succeeds
- [ ] Activate the workflow in the UI (toggle Active on)
- [ ] If scheduled: confirm next run time in UI
- [ ] If webhook: hit the production webhook URL once and confirm execution recorded

### 7. Update specs and archive

- [ ] If this change introduces a new convention, ensure `specs/` delta in this folder is filled in
- [ ] Move folder to `openspec/changes/archive/<change-id>/`
- [ ] Apply spec deltas to `openspec/specs/` (canonical)

**Commit**: `chore(openspec): archive <change-id>`

## Verification Checklist

Run before marking the change complete:

- [ ] `workflow.json` is in git, matches what's deployed (export and `git diff` to confirm)
- [ ] README lists every credential the workflow uses, by canonical name
- [ ] No secrets in `workflow.json` (final grep)
- [ ] Workflow is active in n8n UI
- [ ] At least one successful execution recorded in Executions tab
