# Documan.ai

**Docs your AI actually understands.** The only documentation tool with a built-in MCP server.

Claude Code, Cursor, and other AI tools can search and understand your documentation in real-time.

**Full documentation:** [documan.ai](https://documan.ai)

## Key Features

- **Built-in MCP Server** - AI assistants search your docs semantically
- **Semantic Search** - Find docs by meaning, not just keywords
- **Single Binary** - No npm, no Node.js, no dependencies
- **CI/CD Ready** - Lint docs in your pipeline, Docker image included

## Quick Start

### Option 1: Binary

```bash
# Download from GitHub Releases
curl -L https://github.com/documan-ai/documan/releases/latest/download/documan-darwin-arm64.tar.gz | tar xz
mv documan-darwin-arm64 documan

# Configure
echo 'DOCUMAN_PROJECT_NAME=My Project
DOCUMAN_DOCS_FILES=docs/**/*.md,README.md
DOCUMAN_HTTP_PORT=3000' > .env

# Run
./documan fix         # Auto-fix frontmatter
./documan lint        # Check frontmatter, links, duplicates
./documan import      # Import to database
# Optional: Enable semantic search for MCP server (requires DOCUMAN_OPENAI_API_KEY)
# ./documan vectorize
./documan serve       # Start server
```

### Option 2: Docker

```bash
# Start container
docker run -d --name documan \
  -p 3000:3000 \
  -v $(pwd)/docs:/documan/data/docs \
  -v $(pwd)/README.md:/documan/data/README.md \
  -e DOCUMAN_PROJECT_NAME="My Project" \
  -e DOCUMAN_DOCS_FILES="**/*.md" \
  -e DOCUMAN_HTTP_PORT="3000" \
  jzaplet/documan:latest

# Fix, lint and import docs
docker exec -t documan /documan/bin/documan fix
docker exec -t documan /documan/bin/documan lint
docker exec -t documan /documan/bin/documan import
# Optional: Enable semantic search for MCP server (requires DOCUMAN_OPENAI_API_KEY)
# docker exec -t documan /documan/bin/documan vectorize
```

Web UI: `http://localhost:3000`

MCP Server: `http://localhost:3000/mcp`

For production CI/CD and docker-compose, see [Docker Setup Guide](https://docs.documan.ai/getting-started/docker-setup).

For semantic search setup (vectorize command), see [Commands](https://docs.documan.ai/commands#vectorize).

## Connect AI Tools

Register MCP server to Claude Code CLI:

```bash
claude mcp add documentation --transport http http://localhost:3000/mcp
```

For Cursor, Claude Desktop, and other tools, see [MCP Setup Guide](https://docs.documan.ai/getting-started/mcp-setup).
