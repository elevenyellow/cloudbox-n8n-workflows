#!/bin/bash
# Setup environment variables for n8n
# This script should be run on the n8n server (rola.dev)

set -e

echo "Setting up n8n environment variables..."

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
   echo "Please run as root or with sudo"
   exit 1
fi

# Find n8n docker container or systemd service
if docker ps | grep -q n8n; then
    echo "Found n8n running in Docker"
    CONTAINER_ID=$(docker ps | grep n8n | awk '{print $1}')
    
    # Get docker-compose file path
    COMPOSE_FILE=$(docker inspect $CONTAINER_ID | jq -r '.[0].Config.Labels["com.docker.compose.project.config_files"]')
    
    if [ -n "$COMPOSE_FILE" ] && [ -f "$COMPOSE_FILE" ]; then
        echo "Found docker-compose file: $COMPOSE_FILE"
        echo ""
        echo "Add the following to the n8n service environment section:"
        echo ""
        echo "    environment:"
        echo "      - TAVILY_API_KEY=\${TAVILY_API_KEY}"
        echo ""
        echo "Then add to .env file in the same directory:"
        echo "TAVILY_API_KEY=your_tavily_api_key_here"
        echo ""
        echo "After editing, run: docker-compose up -d"
    else
        echo "Could not find docker-compose file"
        echo "Manually add TAVILY_API_KEY to container environment"
    fi
elif systemctl list-units | grep -q n8n; then
    echo "Found n8n running as systemd service"
    SERVICE_FILE=$(systemctl status n8n | grep "Loaded:" | awk '{print $3}' | tr -d '()')
    
    echo "Service file: $SERVICE_FILE"
    echo ""
    echo "Add the following to the [Service] section:"
    echo "Environment=\"TAVILY_API_KEY=your_tavily_api_key_here\""
    echo ""
    echo "After editing, run:"
    echo "  systemctl daemon-reload"
    echo "  systemctl restart n8n"
else
    echo "Could not find n8n running (checked Docker and systemd)"
    exit 1
fi
