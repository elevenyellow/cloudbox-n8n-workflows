#!/bin/bash
set -euo pipefail

# Export a workflow from n8n to JSON file

WORKFLOW_ID="${1:-}"
OUTPUT_FILE="${2:-}"

if [[ -z "$WORKFLOW_ID" ]] || [[ -z "$OUTPUT_FILE" ]]; then
  echo "Usage: $0 <workflow-id> <output.json>"
  echo ""
  echo "Example:"
  echo "  $0 42 workflows/example/workflow.json"
  echo ""
  echo "To find workflow ID:"
  echo "  1. Open workflow in n8n UI"
  echo "  2. Check URL: https://n8n.rola.dev/workflow/<id>"
  echo "  3. Or list all: curl -H \"X-N8N-API-KEY: \$N8N_API_KEY\" https://n8n.rola.dev/api/v1/workflows | jq '.[] | {id, name}'"
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

echo "Exporting workflow ID: $WORKFLOW_ID"
echo "Output file: $OUTPUT_FILE"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$N8N_API_URL/workflows/$WORKFLOW_ID")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "$BODY" | jq '.' > "$OUTPUT_FILE"
  
  if [[ -f "$OUTPUT_FILE" ]]; then
    WORKFLOW_NAME=$(jq -r '.name' "$OUTPUT_FILE")
    echo "✅ Exported successfully!"
    echo "   Name: $WORKFLOW_NAME"
    echo "   File: $OUTPUT_FILE"
    echo ""
    echo "Next steps:"
    echo "  1. Review changes: git diff $OUTPUT_FILE"
    echo "  2. Update README.md if workflow logic changed"
    echo "  3. Commit: git add $OUTPUT_FILE && git commit -m \"feat(workflows): update ...\""
    exit 0
  else
    echo "❌ Export failed (file not created)"
    exit 1
  fi
else
  echo "❌ Export failed (HTTP $HTTP_CODE)"
  echo ""
  echo "Response:"
  echo "$BODY" | jq . || echo "$BODY"
  echo ""
  echo "Troubleshooting:"
  echo "  - 401: Invalid API key (check .env)"
  echo "  - 403: Not from Tailscale IP (check Tailscale connection)"
  echo "  - 404: Workflow ID not found (check ID, list all workflows)"
  exit 1
fi
