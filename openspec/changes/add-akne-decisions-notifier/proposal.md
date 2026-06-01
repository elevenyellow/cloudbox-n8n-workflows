# Proposal: Akne Decisions Notifier (Fase 1)

## Status

**Proposed** — awaiting review

## Problem

En el proyecto interno **akne** (repo privado `elevenyellow/akne` en GitHub), el equipo de desarrollo documenta decisiones de producto en `docs/decisions/business/*.md` que requieren respuesta del Product Manager. El PM no tiene perfil técnico y no accede directamente a GitHub.

Actualmente no hay mecanismo automático para notificar al PM cuando aparecen nuevas decisiones pendientes, lo que genera retrasos en las respuestas y fricción en el flujo de trabajo.

## Proposed Solution

Add an n8n workflow at `workflows/akne-decisions-notifier/` that:

- **Trigger**: GitHub Webhook (push a `main` del repo `elevenyellow/akne`)
- **Action**: Detecta archivos `.md` nuevos o modificados en `docs/decisions/business/` con `status: pending` en frontmatter, extrae el contenido estructurado (título, contexto, opciones, pregunta) y postea un mensaje formateado en Slack
- **Output**: Mensaje en canal `#akne` de Slack como parent de thread (para discusión futura)

### Roadmap (fuera de scope de esta change)

- **Fase 2**: Captura de respuesta del PM en Slack → PR de vuelta al repo
- **Fase 3**: Copiloto conversacional con tools (openspec CLI, gh CLI)
- **Fase 4**: RAG sobre `docs/` para preguntas abiertas

## Scope

### In Scope

- `workflows/akne-decisions-notifier/workflow.json` (n8n native JSON, `active: false` inicialmente)
- `workflows/akne-decisions-notifier/README.md` (purpose, trigger, nodes, credentials, deployment, testing)
- Nuevas credenciales en n8n:
  - `GitHub: akne PAT` — Fine-grained token con `Contents: Read and write` + `Pull requests: Read and write` para repo `elevenyellow/akne` (permisos preparados para Fases 2-4)
  - `Slack: Akne Assistant` — Slack API con Access Token y Signing Secret, scopes `chat:write`, `channels:read`
- Webhook secret almacenado como variable de entorno en n8n (`GITHUB_WEBHOOK_SECRET_AKNE`)
- Tabla en Postgres para persistir mapping `decision_id` ↔ `slack_thread_ts` (para Fase 2)
- Deployment via `scripts/deploy-workflow.sh`

### Out of Scope

- Uso de LLM (reservado para Fases 2-4)
- Captura de respuestas del PM en Slack (Fase 2)
- Modificación del repo akne (PRs automáticos) — Fase 2
- Copiloto conversacional — Fase 3
- RAG sobre documentación — Fase 4
- Creación del canal `#akne` (ya existe)

## Success Criteria

- [ ] `workflow.json` validates as importable n8n JSON (loads in UI without errors)
- [ ] Push a `main` con `.md` nuevo en `docs/decisions/business/` y `status: pending` genera mensaje en Slack
- [ ] Push a `main` con `.md` modificado (sin cambio de status a pending) NO genera mensaje duplicado
- [ ] Push a `main` con archivos fuera de `docs/decisions/business/` NO activa el workflow
- [ ] Mensaje en Slack incluye: título, contexto, opciones, pregunta, link a GitHub
- [ ] Mapping `decision_id` ↔ `slack_thread_ts` persistido en Postgres
- [ ] Deployed via `./scripts/deploy-workflow.sh workflows/akne-decisions-notifier/workflow.json`
- [ ] Workflow visible in n8n UI with tags `github`, `slack`, `akne`, `production`
- [ ] README documents every credential the workflow consumes (by name)
- [ ] No secrets or tokens committed to git (grep clean)
- [ ] Workflow activated in UI after end-to-end test passes

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| GitHub PAT expira o revocado | High | Documentar rotación en README, monitorear ejecuciones fallidas |
| Slack bot no invitado al canal | High | Verificar membership antes de deploy, documentar setup |
| Push con múltiples archivos pending | Medium | Workflow procesa cada archivo individualmente con loop |
| Frontmatter malformado en .md | Medium | Validar parsing YAML, skip con warning si falla |
| Rate limit de GitHub API (fetch content) | Low | Usar conditional requests, batch si es necesario |
| Mensaje duplicado por re-push | Medium | Deduplicar por `decision_id` en Postgres antes de postear |

## Rollback Plan

1. Deactivate workflow in n8n UI (toggle Active off).
2. Delete workflow via UI or API: `curl -X DELETE -H "X-N8N-API-KEY: $N8N_API_KEY" $N8N_API_URL/workflows/<id>`.
3. `git revert` the commit that added `workflows/akne-decisions-notifier/`.
4. Remove GitHub webhook from repo `elevenyellow/akne` (Settings → Webhooks).
5. Remove credentials created exclusively for this workflow from the n8n UI (only if not used elsewhere).
6. Optionally drop Postgres table `akne_decision_threads` if no data retention needed.

**Time to rollback**: < 10 minutes (includes webhook removal).

## Alternatives Considered

- **GitHub Actions + Slack action**: Rejected because secrets estarían en GitHub (preferimos centralizar en n8n), y perdemos visibilidad unificada de ejecuciones.
- **Polling en lugar de webhook**: Rejected because introduce latencia innecesaria y consume más API calls.
- **Slack incoming webhook en lugar de Bot**: Rejected because incoming webhooks no permiten crear threads programáticamente con `thread_ts`, ni leer respuestas (necesario para Fase 2).
- **Sin Postgres (solo Slack)**: Rejected because necesitamos el mapping para Fase 2 (actualizar el archivo con la respuesta).
- **Slack OAuth2 credential**: Rejected because requiere configuración adicional del reverse proxy en cloudbox para exponer `/rest/oauth2-credential/callback`. Slack API con Access Token directo es más simple.

## Dependencies

### Pre-requisites (manual, before implementation)

1. GitHub Fine-grained PAT creado con `Contents: Read and write` + `Pull requests: Read and write` para repo `elevenyellow/akne`.
2. Credential `GitHub: akne PAT` creada en n8n UI (tipo Header Auth).
3. Slack App `Akne Assistant` creada en workspace con scopes `chat:write`, `channels:read`.
4. Slack App instalada en workspace, Bot User OAuth Token (`xoxb-...`) obtenido.
5. Slack Bot invitado al canal `#akne`.
6. Credential `Slack: Akne Assistant` creada en n8n UI (tipo Slack API con Access Token + Signing Secret).
7. Webhook secret generado y almacenado como variable de entorno `GITHUB_WEBHOOK_SECRET_AKNE` en n8n.
8. Webhook URL de n8n obtenida para configurar en GitHub.
9. Postgres credential `Postgres account` disponible (misma instancia que otros workflows).
10. Tabla `akne_decision_threads` creada en Postgres.
11. `.env` has a valid `N8N_API_KEY` for the deploy script.

### Implementation dependencies

- n8n platform running (`cloudbox/` repo, n8n role).
- Repo `elevenyellow/akne` accesible via GitHub API con el PAT.
- Canal `#akne` existe en Slack workspace.

## Estimated Effort

- **Design**: 1h
- **Build (workflow.json + README)**: 2-3h
- **Setup credentials + webhook**: 0.5h
- **Test (webhook + Slack post)**: 1h
- **Deploy + verify**: 0.5h
- **Total**: 5-6h

## Related Documentation

- [Architecture](../../../docs/architecture.md) — workflow lifecycle
- [Runbook: Deploying a Workflow](../../../docs/runbooks/deploying-a-workflow.md)
- [Runbook: Credential Management](../../../docs/runbooks/credential-management.md)
- [Workflow: Telegram OpenRouter Chat](../../../workflows/telegram-openrouter-chat/README.md) — patrón de referencia
