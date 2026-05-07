#!/bin/bash
set -euo pipefail

# Deploy a workflow JSON file to n8n via API

WORKFLOW_FILE="${1:-}"

if [[ -z "$WORKFLOW_FILE" ]]; then
  echo "Usage: $0 <workflow.json>"
  echo ""
  echo "Example:"
  echo "  $0 workflows/example/workflow.json"
  exit 1
fi

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Error: File not found: $WORKFLOW_FILE"
  exit 1
fi

# Load API key from .env
if [[ -f .env ]]; then
  source .env
fi

if [[ -z "${N8N_API_KEY:-}" ]]; then
  echo "Error: N8N_API_KEY not set."
  echo ""
  echo "Add to .env:"
  echo "  N8N_API_KEY=your_api_key_here"
  echo ""
  echo "Or export:"
  echo "  export N8N_API_KEY=your_api_key_here"
  exit 1
fi

N8N_API_URL="${N8N_API_URL:-https://n8n.rola.dev/api/v1}"

echo "Deploying workflow: $WORKFLOW_FILE"
echo "API endpoint: $N8N_API_URL/workflows"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @"$WORKFLOW_FILE" \
  "$N8N_API_URL/workflows")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "201" ]]; then
  WORKFLOW_ID=$(echo "$BODY" | jq -r '.id')
  WORKFLOW_NAME=$(echo "$BODY" | jq -r '.name')
  echo "✅ Deployed successfully!"
  echo "   ID: $WORKFLOW_ID"
  echo "   Name: $WORKFLOW_NAME"
  echo "   URL: https://n8n.rola.dev/workflow/$WORKFLOW_ID"
  exit 0
else
  echo "❌ Deployment failed (HTTP $HTTP_CODE)"
  echo ""
  echo "Response:"
  echo "$BODY" | jq . || echo "$BODY"
  echo ""
  echo "Troubleshooting:"
  echo "  - 401: Invalid API key (check .env)"
  echo "  - 403: Not from Tailscale IP (check Tailscale connection)"
  echo "  - 400: Invalid workflow JSON (check syntax with 'jq . $WORKFLOW_FILE')"
  exit 1
fi
