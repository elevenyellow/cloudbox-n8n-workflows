# Workflow: Akne Decisions Notifier

**Purpose**: Notify the PM in Slack when developers push new business decisions requiring input. Bridges the gap between technical documentation in GitHub and non-technical stakeholders.

**Trigger**: GitHub Webhook (push to `main` branch of `elevenyellow/akne`)

**Nodes**:

- **Webhook Trigger**: Receives GitHub push events.
- **Validate Webhook Signature**: Verifies HMAC SHA-256 signature using `GITHUB_WEBHOOK_SECRET_AKNE`.
- **Is Push to Main?**: Filters to only process pushes to `refs/heads/main`.
- **Extract Modified Files**: Extracts `added` and `modified` files from commits.
- **Filter Decision Files**: Keeps only files matching `docs/decisions/business/*.md`.
- **Loop Files**: Processes each decision file individually.
- **Fetch File Content**: Retrieves file content via GitHub API.
- **Parse Frontmatter**: Extracts YAML frontmatter and markdown sections.
- **Is Status Pending?**: Continues only if `status: pending` in frontmatter.
- **Check Already Notified**: Queries Postgres to prevent duplicate notifications.
- **Is New Decision?**: Continues only if decision hasn't been notified before.
- **Build Slack Message**: Constructs Slack blocks with decision details.
- **Post to Slack**: Sends formatted message to `#akne` channel.
- **Save Thread Mapping**: Persists `decision_id` ↔ `slack_thread_ts` for Phase 2.

**Credentials Required**:

- `GitHub: akne PAT`: Fine-grained PAT with Contents and Pull requests read/write access.
- `Slack: Akne Assistant`: Slack API credential with Access Token and Signing Secret.
- `Postgres account`: Postgres credential for thread mapping persistence.

**Environment Variables**:

- `GITHUB_WEBHOOK_SECRET_AKNE`: Secret for validating GitHub webhook signatures.

**Deployment**:

```bash
cd ~/sdk/projects/cloudbox-n8n-workflows
source .env
./scripts/deploy-workflow.sh workflows/akne-decisions-notifier/workflow.json
```

**Testing**:

1. Import `workflows/akne-decisions-notifier/workflow.json` into n8n UI.
2. Attach all credentials by name.
3. Create a test decision file in `elevenyellow/akne`:
   ```markdown
   ---
   id: "test-001"
   title: Test Decision
   status: pending
   created: 2026-06-01
   owner_question: dev
   owner_answer: pm
   ---
   
   # Decision test-001: Test Decision
   
   ## Context
   Test context.
   
   ## Options
   - A: Option A
   - B: Option B
   
   ## Question for PM
   Which option?
   
   ## PM Answer
   
   ## Discussion log
   ```
4. Commit and push to `main`.
5. Verify message appears in `#akne` Slack channel.
6. Verify record created in `akne_decision_threads` Postgres table.
7. Re-push same file and verify NO duplicate message.
8. Delete test file after validation.

**Notes**:

- This is Phase 1 of the Akne Assistant bot. Future phases will add:
  - Phase 2: Capture PM response from Slack → PR back to repo
  - Phase 3: Conversational copilot with tools
  - Phase 4: RAG over docs for open questions
- No LLM is used in Phase 1. Messages are constructed from structured frontmatter.
- Deduplication is handled via `decision_id` in Postgres.
- The Slack message is posted as a thread parent, ready for discussion.

**Related Documentation**:

- [Design](../../openspec/changes/add-akne-decisions-notifier/design.md)
- [Tasks](../../openspec/changes/add-akne-decisions-notifier/tasks.md)
