#!/bin/bash
set -euo pipefail

# ============================================================================
# Documan Quick Start
# https://docs.documan.ai
#
# Usage (interactive):
#   curl -fsSL https://raw.githubusercontent.com/documan-ai/documan/main/scripts/quickstart.sh | bash
#
# Usage (non-interactive):
#   curl -fsSL ... | DOCUMAN_MODE=docker DOCUMAN_PROJECT_NAME="My Docs" DOCUMAN_HTTP_PORT=3003 bash
#   curl -fsSL ... | DOCUMAN_MODE=binary DOCUMAN_PROJECT_NAME="My Docs" DOCUMAN_HTTP_PORT=3003 bash
# ============================================================================

GITHUB_REPO="documan-ai/documan"
DEFAULT_PORT="3003"
DEFAULT_PROJECT_NAME="My Docs"

# --- Colors ----------------------------------------------------------------

setup_colors() {
    if [ -t 1 ] 2>/dev/null; then
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        RED='\033[0;31m'
        BOLD='\033[1m'
        DIM='\033[2m'
        NC='\033[0m'
    else
        GREEN='' YELLOW='' RED='' BOLD='' DIM='' NC=''
    fi
}

# --- Helpers ---------------------------------------------------------------

info() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }

ask() {
    local prompt="$1" default="${2:-}" reply
    if [ -n "$default" ]; then
        printf "  %b ${DIM}[%s]${NC}: " "$prompt" "$default" >/dev/tty
    else
        printf "  %b: " "$prompt" >/dev/tty
    fi
    read -r reply </dev/tty 2>/dev/null || reply=""
    echo "${reply:-$default}"
}

# Read a value from an env file. Returns empty string if not found.
# Usage: read_env_value <file> <key>
read_env_value() {
    local file="$1" key="$2"
    grep "^${key}=" "$file" 2>/dev/null | head -1 | sed "s/^${key}=//; s/^'//; s/'$//" || true
}

# Replace a key's value in a file (portable, no sed -i).
# Usage: replace_env_value <file> <key> <value>
replace_env_value() {
    local file="$1" key="$2" value="$3"
    local tmp="${file}.tmp.$$"
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            "${key}="*) echo "${key}=${value}" ;;
            *)          echo "$line" ;;
        esac
    done < "$file" > "$tmp"
    mv "$tmp" "$file"
}

# Ensure an env file has all required variables.
# Missing keys are appended. Existing keys are left unchanged.
# Usage: ensure_env_file <file> <var1> <var2> ...
ensure_env_file() {
    local file="$1"; shift
    local -a vars=("$@")

    if [ ! -f "$file" ]; then
        printf '%s\n' "${vars[@]}" > "$file"
        info "Created $file"
        return
    fi

    local changed=0
    for var in "${vars[@]}"; do
        local key="${var%%=*}"
        if ! grep -q "^${key}=" "$file" 2>/dev/null; then
            echo "$var" >> "$file"
            changed=1
        fi
    done

    if [ "$changed" -eq 1 ]; then
        info "Updated $file (added missing variables)"
    else
        info "Found $file (no changes needed)"
    fi
}

# Update specific keys in an env file with user-provided values.
# Only overwrites keys that are explicitly passed.
# Usage: update_env_values <file> <var1> <var2> ...
update_env_values() {
    local file="$1"; shift
    [ ! -f "$file" ] && return

    local changed=0
    for var in "$@"; do
        local key="${var%%=*}"
        local value="${var#*=}"
        if grep -q "^${key}=" "$file" 2>/dev/null; then
            local current
            current=$(grep "^${key}=" "$file" | head -1 | sed "s/^${key}=//")
            if [ "$current" != "$value" ]; then
                replace_env_value "$file" "$key" "$value"
                changed=1
            fi
        fi
    done
}

# Idempotently create a file from a content function.
# Usage: ensure_file <path> <content_fn> [mkdir_path]
ensure_file() {
    local target="$1" content_fn="$2" dir="${3:-}"

    [ -n "$dir" ] && mkdir -p "$dir"

    if [ -f "$target" ]; then
        info "Found $target (unchanged)"
        return
    fi

    "$content_fn" > "$target"
    info "Created $target"
}

# --- Prompts ---------------------------------------------------------------

confirm_directory() {
    echo ""
    echo -e "  ${BOLD}Documan${NC} — Quick Start"
    echo -e "  ${DIM}https://docs.documan.ai${NC}"
    echo ""
    echo -e "  Directory: ${BOLD}$(pwd)${NC}"

    local confirm
    confirm=$(ask "Install here? (y/n)" "y")
    case "$confirm" in
        y|Y|yes) ;;
        *)       echo ""; echo "  Aborted."; exit 0 ;;
    esac
}

prompt_mode() {
    if [ -n "${DOCUMAN_MODE:-}" ]; then
        case "$DOCUMAN_MODE" in
            docker|binary) MODE="$DOCUMAN_MODE"; return ;;
        esac
    fi

    echo ""
    echo -e "  ${BOLD}How do you want to run Documan?${NC}"
    echo ""
    echo "    1) Docker  — Docker Compose with production Dockerfile"
    echo "    2) Binary  — download standalone binary for your platform"
    echo ""

    local choice
    choice=$(ask "Choose" "1")

    case "$choice" in
        1|docker) MODE="docker" ;;
        2|binary) MODE="binary" ;;
        *)        MODE="docker" ;;
    esac
}

prompt_makefile() {
    USE_MAKEFILE="false"

    if [ -n "${DOCUMAN_MAKEFILE:-}" ]; then
        case "$DOCUMAN_MAKEFILE" in
            yes|true|1) USE_MAKEFILE="true" ;;
        esac
        return
    fi

    local mf
    mf=$(ask "Are you using Makefile? (y/n)" "n")
    case "$mf" in
        y|Y|yes) ;;
        *)       return ;;
    esac

    if ! command -v make &>/dev/null; then
        warn "make is not installed, skipping Makefile"
        return
    fi

    info "make is available"
    USE_MAKEFILE="true"
}

prompt_config() {
    echo ""
    PROJECT_NAME="${DOCUMAN_PROJECT_NAME:-}"
    PORT="${DOCUMAN_HTTP_PORT:-}"

    # Pre-fill from existing .env if available
    if [ -f ".env" ]; then
        [ -z "$PROJECT_NAME" ] && PROJECT_NAME=$(read_env_value .env DOCUMAN_PROJECT_NAME)
        [ -z "$PORT" ] && PORT=$(read_env_value .env DOCUMAN_HTTP_PORT)
    fi

    PROJECT_NAME=$(ask "Project name" "${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}")
    PORT=$(ask "HTTP port" "${PORT:-$DEFAULT_PORT}")

    PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}"
    PORT="${PORT:-$DEFAULT_PORT}"
}

# --- Check Docker -----------------------------------------------------------

check_docker() {
    if ! command -v docker &>/dev/null; then
        fail "Docker is not installed. Get it at https://docs.docker.com/get-docker/"
    fi

    if ! docker info &>/dev/null; then
        fail "Docker is not running. Start Docker and try again."
    fi

    if ! docker compose version &>/dev/null; then
        fail "Docker Compose v2 required. Update Docker or install the compose plugin."
    fi

    info "Docker is available"
}

# --- Create files -----------------------------------------------------------

create_docs() {
    mkdir -p docs
    ensure_file "docs/home.md" _content_home_md
}

create_env() {
    # All variables with defaults
    local -a all_vars=(
        "DOCUMAN_PROJECT_NAME='${PROJECT_NAME}'"
        "DOCUMAN_HTTP_PORT=${PORT}"
        "DOCUMAN_OPENAI_API_KEY="
        "DOCUMAN_LICENSE_KEY="
    )

    if [ "$MODE" = "binary" ]; then
        all_vars+=("DOCUMAN_DB_PATH=./documan.db" "DOCUMAN_DOCS_FILES='docs/**/*.md'")
    fi

    # Only project name and port are user-provided — these get overwritten
    local -a user_vars=(
        "DOCUMAN_PROJECT_NAME='${PROJECT_NAME}'"
        "DOCUMAN_HTTP_PORT=${PORT}"
    )

    # Add missing variables, then overwrite user-provided values
    ensure_env_file ".env.example" "${all_vars[@]}"
    update_env_values ".env.example" "${user_vars[@]}"

    ensure_env_file ".env" "${all_vars[@]}"
    update_env_values ".env" "${user_vars[@]}"
}

create_dockerfile() {
    ensure_file "docker/documan/Dockerfile" _content_dockerfile "docker/documan"
}

create_docker_compose() {
    local target="docker-compose.yml"

    # Check for .yaml extension too
    [ ! -f "$target" ] && [ -f "docker-compose.yaml" ] && target="docker-compose.yaml"

    # File doesn't exist — create from scratch
    if [ ! -f "$target" ]; then
        { echo "services:"; _content_compose_service; } > "$target"
        info "Created $target"
        return
    fi

    # Service already defined — skip
    if grep -qE '^[[:space:]]+documan:' "$target"; then
        info "Found $target (documan service already defined)"
        return
    fi

    # No services key — append both
    if ! grep -q '^services:' "$target"; then
        { echo ""; echo "services:"; _content_compose_service; } >> "$target"
        info "Updated $target (added documan service)"
        return
    fi

    # Insert documan service at the end of the services: block.
    # The services block ends before the next top-level key (a line starting
    # with a non-space character that isn't a comment) or at end of file.
    local tmp="${target}.tmp.$$"
    local in_services=false
    local inserted=false

    while IFS= read -r line || [ -n "$line" ]; do
        # Detect entering services block
        if [ "$line" = "services:" ]; then
            in_services=true
            echo "$line"
            continue
        fi

        # Detect next top-level key (non-indented, non-empty, non-comment)
        if $in_services && ! $inserted; then
            case "$line" in
                ""|"#"*|" "*|"	"*)
                    # Still inside services or blank/comment line
                    echo "$line"
                    continue
                    ;;
                *)
                    # Hit next top-level key — insert service before it
                    _content_compose_service
                    echo ""
                    inserted=true
                    ;;
            esac
        fi

        echo "$line"
    done < "$target" > "$tmp"

    # If we were in services but never hit another top-level key (services is last)
    if $in_services && ! $inserted; then
        _content_compose_service >> "$tmp"
    fi

    mv "$tmp" "$target"
    info "Updated $target (added documan service)"
}

create_makefile() {
    local target="Makefile"

    # Targets already defined — skip
    if [ -f "$target" ] && grep -q '^documan:' "$target"; then
        info "Found $target (documan targets already defined)"
        return
    fi

    # Append with blank line separator if file exists
    [ -f "$target" ] && echo "" >> "$target"
    local label="Created"
    [ -f "$target" ] && label="Updated"

    _content_makefile_targets >> "$target"
    info "$label $target"
}

create_claude_skill() {
    ensure_file ".claude/commands/documan.md" _content_claude_skill ".claude/commands"
}

# --- Detect platform -------------------------------------------------------

detect_platform() {
    local os arch
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    case "$os" in
        linux)                PLATFORM_OS="linux" ;;
        darwin)               PLATFORM_OS="darwin" ;;
        mingw*|msys*|cygwin*) PLATFORM_OS="windows" ;;
        *)                    fail "Unsupported OS: $os" ;;
    esac

    case "$arch" in
        x86_64|amd64)    PLATFORM_ARCH="amd64" ;;
        aarch64|arm64)   PLATFORM_ARCH="arm64" ;;
        armv7l|armv6l)   PLATFORM_ARCH="arm" ;;
        i386|i686)       PLATFORM_ARCH="386" ;;
        *)               fail "Unsupported architecture: $arch" ;;
    esac
}

# --- Download binary -------------------------------------------------------

download_binary() {
    detect_platform

    local binary_name="documan-${PLATFORM_OS}-${PLATFORM_ARCH}"
    local ext final_name="documan"

    case "$PLATFORM_OS" in
        linux)          ext="tar.gz" ;;
        darwin|windows) ext="zip" ;;
    esac

    [ "$PLATFORM_OS" = "windows" ] && binary_name="${binary_name}.exe" && final_name="documan.exe"

    if [ -f "$final_name" ]; then
        info "Found $final_name (unchanged)"
        return
    fi

    local url="https://github.com/${GITHUB_REPO}/releases/latest/download/${binary_name}.${ext}"
    local archive="${binary_name}.${ext}"

    info "Detected platform: ${PLATFORM_OS}/${PLATFORM_ARCH}"
    echo -e "  Downloading ${BOLD}${binary_name}${NC}..."

    if command -v curl &>/dev/null; then
        curl -fsSL -o "$archive" "$url" || fail "Download failed. Check https://github.com/${GITHUB_REPO}/releases"
    elif command -v wget &>/dev/null; then
        wget -q -O "$archive" "$url" || fail "Download failed. Check https://github.com/${GITHUB_REPO}/releases"
    else
        fail "curl or wget is required"
    fi

    case "$ext" in
        tar.gz) tar -xzf "$archive" ;;
        zip)    unzip -o -q "$archive" ;;
    esac

    rm -f "$archive"
    mv "$binary_name" "$final_name" 2>/dev/null || true
    [ "$PLATFORM_OS" != "windows" ] && chmod +x "$final_name"

    # macOS: remove quarantine attribute if present.
    # All macOS binaries are signed and notarized via Apple Developer ID —
    # the release pipeline will not produce a binary without valid notarization.
    # However, depending on how the file was downloaded, macOS may still set
    # the com.apple.quarantine extended attribute. Removing it prevents
    # Gatekeeper from blocking execution (e.g. when Apple's servers are
    # unreachable for online notarization check).
    if [ "$PLATFORM_OS" = "darwin" ] && command -v xattr &>/dev/null; then
        xattr -d com.apple.quarantine "$final_name" 2>/dev/null || true
    fi

    info "Downloaded $final_name"
}

# --- Start: Docker ---------------------------------------------------------

start_docker() {
    echo ""
    echo -e "  ${BOLD}Starting Documan...${NC}"
    echo ""

    docker compose build --build-arg SKIP_BUILD_STEPS=true documan
    docker compose up -d documan
    info "Container started"

    docker compose exec -T documan /documan/bin/documan fix
    info "Fixed frontmatter"

    docker compose exec -T documan /documan/bin/documan import
    info "Imported documentation"
}

# --- Start: Binary ---------------------------------------------------------

start_binary() {
    local bin="./documan"
    [ "${PLATFORM_OS:-}" = "windows" ] && bin="./documan.exe"

    if [ ! -f "$bin" ]; then
        warn "Binary not found, skipping initial import"
        return
    fi

    echo ""

    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a

    "$bin" fix
    info "Fixed frontmatter"

    "$bin" import
    info "Imported documentation"
}

# --- Done -------------------------------------------------------------------

print_done() {
    echo ""
    if [ "$MODE" = "docker" ]; then
        echo -e "  ${GREEN}Done!${NC} Open ${BOLD}http://localhost:${PORT}${NC}"
        echo ""
        echo "  Next steps:"
        if [ "$USE_MAKEFILE" = "true" ]; then
            echo "    make documan           — rebuild and start container"
            echo "    make documan-import    — re-import after editing docs"
            echo "    make documan-fix       — auto-fix frontmatter"
            echo "    make documan-lint      — validate documentation"
            echo "    make documan-vectorize — vectorize for semantic search"
        else
            echo "    docker compose up -d documan --build                              — rebuild and start container"
            echo "    docker compose exec -t documan /documan/bin/documan import        — re-import after editing docs"
            echo "    docker compose exec -t documan /documan/bin/documan fix           — auto-fix frontmatter"
            echo "    docker compose exec -t documan /documan/bin/documan lint          — validate documentation"
            echo "    docker compose exec -t documan /documan/bin/documan vectorize     — vectorize for semantic search"
        fi
    else
        echo -e "  ${GREEN}Done!${NC} Run ${BOLD}./documan serve${NC} to start"
        echo ""
        echo -e "  Then open ${BOLD}http://localhost:${PORT}${NC}"
        echo ""
        echo "  Commands:"
        echo "    ./documan serve      — start the web server"
        echo "    ./documan import     — import documentation"
        echo "    ./documan fix        — auto-fix frontmatter"
        echo "    ./documan lint       — validate documentation"
        echo "    ./documan vectorize  — vectorize for semantic search"
    fi
    echo ""
}

# --- Main -------------------------------------------------------------------

main() {
    setup_colors
    confirm_directory
    prompt_mode

    if [ "$MODE" = "docker" ]; then
        check_docker
        echo ""
        prompt_makefile
    fi

    prompt_config

    echo ""
    create_docs
    create_env
    create_claude_skill

    if [ "$MODE" = "docker" ]; then
        create_dockerfile
        create_docker_compose
        [ "$USE_MAKEFILE" = "true" ] && create_makefile
        start_docker
    else
        download_binary
        start_binary
    fi

    print_done
}

# ============================================================================
# File contents — kept at the end to keep the logic above readable.
# Each function outputs the content to stdout (used via redirection).
# ============================================================================

# --- Content: docs/home.md -------------------------------------------------

_content_home_md() {
    cat << 'EOF'
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

A Documan skill for AI coding tools has been added to `.claude/commands/documan.md`. Use it via the `/documan` command to create and edit documentation pages in the correct format. Learn more in the [Documan skill guide](https://docs.documan.ai/ai-integration/documan-skill).


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
EOF
}

# --- Content: docker/documan/Dockerfile -------------------------------------

_content_dockerfile() {
    # Part 1: dynamic values (unquoted heredoc — variables expanded)
    cat << HEADER
# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
FROM jzaplet/documan:latest

# Copy documentation source files into the image
COPY ./docs /documan/data/docs

# Set working directory
WORKDIR /documan/data

# Configure your project
ENV DOCUMAN_PROJECT_NAME='${PROJECT_NAME}'
ENV DOCUMAN_DOCS_FILES='docs/**/*.md'
ENV DOCUMAN_EXCLUDED_FILES=''
ENV DOCUMAN_HTTP_PORT=${PORT}
ENV DOCUMAN_OPENAI_EMBEDDING_MODEL='text-embedding-3-small'
ENV DOCUMAN_CHUNK_MAX_LEN=250
HEADER

    # Part 2: static content (quoted heredoc — no expansion)
    cat << 'BODY'

# Build-time args for PaaS platforms (e.g., EasyPanel) that pass secrets via --build-arg
# Locally, Docker secrets are used instead (mounted at /run/secrets/)
ARG DOCUMAN_LICENSE_KEY=''
ARG DOCUMAN_OPENAI_API_KEY=''

# Set to "true" to skip lint, import, and vectorize during build.
# Used by the quickstart script for first-time setup when docs may not be valid yet.
# After initial setup, omit this arg so build steps run normally.
ARG SKIP_BUILD_STEPS=false

# Validate markdown files — checks for broken links, invalid frontmatter, etc.
# Fails the build if any issues are found
RUN if [ "$SKIP_BUILD_STEPS" = "false" ]; then /documan/bin/documan lint; fi

# Import docs (license key optional — needed for >100 files)
# Uses Docker secret if available, otherwise falls back to ARG
RUN --mount=type=secret,id=DOCUMAN_LICENSE_KEY,required=false \
    if [ "$SKIP_BUILD_STEPS" = "true" ]; then exit 0; fi && \
    if [ -f /run/secrets/DOCUMAN_LICENSE_KEY ]; then \
      export DOCUMAN_LICENSE_KEY=$(cat /run/secrets/DOCUMAN_LICENSE_KEY); \
    fi && \
    /documan/bin/documan import

# Vectorize docs (only runs if OpenAI API key is provided)
# Uses Docker secret if available, otherwise falls back to ARG
RUN --mount=type=secret,id=DOCUMAN_OPENAI_API_KEY,required=false \
    if [ "$SKIP_BUILD_STEPS" = "true" ]; then exit 0; fi && \
    if [ -f /run/secrets/DOCUMAN_OPENAI_API_KEY ]; then \
      export DOCUMAN_OPENAI_API_KEY=$(cat /run/secrets/DOCUMAN_OPENAI_API_KEY); \
    fi && \
    if [ -n "${DOCUMAN_OPENAI_API_KEY}" ]; then /documan/bin/documan vectorize; fi

CMD ["/documan/bin/documan", "serve"]
BODY
}

# --- Content: docker-compose.yml service block ------------------------------

_content_compose_service() {
    cat << 'EOF'

  documan:
    build:
      context: .
      dockerfile: ./docker/documan/Dockerfile
    env_file:
      - .env
    ports:
      - "${DOCUMAN_HTTP_PORT}:${DOCUMAN_HTTP_PORT}"
    volumes:
      - ./docs:/documan/data/docs
EOF
}

# --- Content: Makefile targets ----------------------------------------------

_content_makefile_targets() {
    printf 'documan:\n\tdocker compose up -d documan --build\n\n'
    printf 'documan-import:\n\tdocker compose exec -t documan /documan/bin/documan import\n\n'
    printf 'documan-lint:\n\tdocker compose exec -t documan /documan/bin/documan lint\n\n'
    printf 'documan-fix:\n\tdocker compose exec -t documan /documan/bin/documan fix\n\n'
    printf 'documan-vectorize:\n\tdocker compose exec -t documan /documan/bin/documan vectorize\n'
}

# --- Content: .claude/commands/documan.md -----------------------------------

_content_claude_skill() {
    cat << 'EOF'
---
description: Documentation helper for creating and editing Documan markdown files in docs/. Use when working with project documentation, creating new pages/sections, or editing existing docs.
---

# Documan Documentation Helper

Write clearly and concisely. Always write documentation content in English.

## Workflow

EOF

    if [ "$MODE" = "docker" ]; then
        _content_claude_skill_workflow_docker
    else
        _content_claude_skill_workflow_binary
    fi

    cat << 'EOF'

## Frontmatter Rules

### Field order
```yaml
---
layout: 'page'              # 'page' or 'list' (for .list.md index files)
uri: '/section/page-name'   # absolute path, matches file path without docs/ prefix
position: 1                 # numeric ordering among siblings
slug: 'section-page-name'   # uri with hyphens instead of slashes (no leading slash)
parent: 'section'           # slug of parent .list.md (omit for root-level pages)
navTitle: 'Short Name'      # sidebar navigation label
title: 'Full Page Title'    # MUST match the # H1 heading exactly
description: 'Optional.'    # page description
---
```

### Rules
- `uri` = file path without `docs/` prefix, with leading `/`
- `slug` = uri with `-` instead of `/` (no leading hyphen)
- `parent` = slug of the parent category's `.list.md`
- `title` and `# H1` heading must be identical
- `.list.md` = `layout: 'list'`, regular pages = `layout: 'page'`
- Use **two blank lines** between major sections
- Links between docs: use URIs from frontmatter (`/section/page`), not file paths

## Templates

### New section (folder + index)
File: `docs/my-section/.list.md`
```yaml
---
layout: 'list'
uri: '/my-section'
position: 5
slug: 'my-section'
navTitle: 'My Section'
title: 'My Section'
---
```

### New page in section
File: `docs/my-section/my-page.md`
```yaml
---
layout: 'page'
uri: '/my-section/my-page'
position: 1
slug: 'my-section-my-page'
parent: 'my-section'
navTitle: 'My Page'
title: 'My Page Title'
description: 'What this page covers.'
---
```
EOF
}

_content_claude_skill_workflow_docker() {
    cat << 'EOF'
### Before any edit
1. Check container is running: `docker compose ps documan`
2. If not running: `docker compose up -d documan --build`

### After every MD file change
1. `docker compose exec -t documan /documan/bin/documan import` — sync changes
2. Ask user if they want to run `docker compose exec -t documan /documan/bin/documan fix` (auto-formatting)
3. Always run fix before committing

### Moving/renaming a page
1. Update frontmatter: `uri`, `slug`, and `parent`
2. Update child pages' `parent` slug if needed
3. Search `docs/**/*.md` for links to old URI and update
4. Run post-edit workflow

### Deleting a page
1. Delete the `.md` file (if `.list.md`, handle child pages first)
2. Update links in other docs
3. Run post-edit workflow

### Troubleshooting: duplicate URI error
If only one file has that URI, Docker volume has stale data. Run `docker compose up -d documan --build` for a full rebuild.
EOF
}

_content_claude_skill_workflow_binary() {
    cat << 'EOF'
### After every MD file change
1. `./documan import` — sync changes
2. Ask user if they want to run `./documan fix` (auto-formatting)
3. Always run `./documan fix` before committing

### Moving/renaming a page
1. Update frontmatter: `uri`, `slug`, and `parent`
2. Update child pages' `parent` slug if needed
3. Search `docs/**/*.md` for links to old URI and update
4. Run post-edit workflow

### Deleting a page
1. Delete the `.md` file (if `.list.md`, handle child pages first)
2. Update links in other docs
3. Run post-edit workflow

### Troubleshooting: duplicate URI error
If only one file has that URI, the database has stale data. Delete `documan.db` and re-run `./documan import`.
EOF
}

# --- Run --------------------------------------------------------------------

main "$@"
