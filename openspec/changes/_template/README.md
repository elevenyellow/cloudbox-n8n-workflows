# Change Template

Starting point for a new n8n workflow change. Copy this directory and rename:

```bash
cp -r openspec/changes/_template openspec/changes/<change-id>
```

Use a kebab-case `<change-id>` that names the workflow or the modification, e.g. `add-telegram-bot`, `update-daily-digest-schedule`, `migrate-rss-feed-to-webhook`.

Then fill in every `<...>` placeholder in:

1. `proposal.md` — what and why
2. `design.md` — workflow shape (trigger, nodes, data flow, credentials)
3. `tasks.md` — step-by-step build/test/deploy checklist
4. `specs/` — only if this change introduces or modifies a canonical convention; otherwise delete the folder

Delete this `README.md` from the copied folder before committing.
