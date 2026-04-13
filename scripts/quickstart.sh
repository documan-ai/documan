#!/bin/bash
set -euo pipefail

PORT="${DOCUMAN_HTTP_PORT:-3003}"
PROJECT_NAME="${DOCUMAN_PROJECT_NAME:-My Docs}"
CONTAINER_NAME="documan"
IMAGE="jzaplet/documan:latest"
DOCS_DIR="docs"
HOME_FILE="home.md"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }

# Check Docker
if ! command -v docker &>/dev/null; then
    fail "Docker is not installed. Get it at https://docs.docker.com/get-docker/"
fi

if ! docker info &>/dev/null; then
    fail "Docker is not running. Start Docker Desktop and try again."
fi

info "Docker is available"

# Create docs directory
if [ ! -d "$DOCS_DIR" ]; then
    mkdir -p "$DOCS_DIR"
    info "Created $DOCS_DIR/ directory"
else
    info "Found $DOCS_DIR/ directory"
fi

# Create home.md
TARGET="$DOCS_DIR/$HOME_FILE"
if [ -f "$TARGET" ]; then
    rm "$TARGET"
    info "Replaced existing home.md"
fi

cat > "$TARGET" << 'HOMEEOF'
---
layout: 'page'
uri: '/'
position: 1
slug: 'home'
navTitle: 'Home'
title: 'Welcome'
description: 'Welcome to your documentation site powered by Documan.'
---

# Welcome

Your documentation site is ready. Read the [Frontmatter guide](https://docs.documan.ai/getting-started/markdown-frontmatter) to learn how to structure your pages and navigation menu, then check the [Showcase](https://docs.documan.ai/getting-started/markdown-showcase) to see all supported features.

## AI coding skill

If you use an AI coding tool, consider adding the [Documan skill](https://docs.documan.ai/ai-integration/documan-skill) — it helps create and edit docs in the correct format.

## Getting started

- [Frontmatter guide](https://docs.documan.ai/getting-started/markdown-frontmatter) — how to structure pages and navigation menu
- [Showcase](https://docs.documan.ai/getting-started/markdown-showcase) — all supported markdown features and rendering
- [Commands](https://docs.documan.ai/getting-started/commands) — CLI commands reference (fix, lint, import, vectorize, serve)
- [Configuration](https://docs.documan.ai/getting-started/configuration) — all environment variables explained

## Deployment

- [Docker setup](https://docs.documan.ai/deployment/docker-setup) — production Dockerfile with build-time validation
- [Docker Compose](https://docs.documan.ai/deployment/docker-compose-setup) — local development with live file changes
- [CI/CD integration](https://docs.documan.ai/deployment/ci-cd-integration) — lint and deploy docs in your pipeline

## AI integration

- [MCP setup](https://docs.documan.ai/ai-integration/mcp-setup) — connect Claude Code, Cursor, and other AI tools to your docs
- [AI coding skill](https://docs.documan.ai/ai-integration/documan-skill) — add a Documan skill to Claude Code for creating and editing docs
HOMEEOF

info "Created $TARGET"

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker rm -f "$CONTAINER_NAME" &>/dev/null
    info "Removed existing $CONTAINER_NAME container"
fi

# Start container
docker run -d --name "$CONTAINER_NAME" \
    -p "${PORT}:${PORT}" \
    -v "$(pwd)/${DOCS_DIR}:/documan/data/docs" \
    -e DOCUMAN_PROJECT_NAME="$PROJECT_NAME" \
    -e DOCUMAN_DOCS_FILES="**/*.md" \
    -e DOCUMAN_HTTP_PORT="$PORT" \
    "$IMAGE" >/dev/null

info "Started $CONTAINER_NAME container"

# Fix and import
docker exec -t "$CONTAINER_NAME" /documan/bin/documan fix
info "Fixed frontmatter"

docker exec -t "$CONTAINER_NAME" /documan/bin/documan import
info "Imported documentation"

echo ""
echo -e "${GREEN}Done!${NC} Open http://localhost:${PORT}"
