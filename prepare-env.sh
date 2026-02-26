#!/usr/bin/env bash
# prepare-env.sh — Create or update .env with auto-generated secrets.
# Safe to run multiple times: only fills in missing values, never overwrites existing ones.
#
# Usage:
#   ./prepare-env.sh              # interactive: prompts for provider key
#   ./prepare-env.sh --quiet      # non-interactive: skip prompts, only generate secrets

set -euo pipefail

ENV_FILE=".env"
QUIET=false

for arg in "$@"; do
  case "$arg" in
    --quiet|-q) QUIET=true ;;
  esac
done

# --- helpers ---

gen_hex() { openssl rand -hex "$1" 2>/dev/null || head -c "$1" /dev/urandom | xxd -p | tr -d '\n'; }

# Read current value from .env (KEY=VALUE format, no export prefix).
get_env_val() {
  local key="$1"
  if [ -f "$ENV_FILE" ]; then
    grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d'=' -f2-
  fi
}

# Set a key in .env. Appends if missing, replaces if empty.
set_env_val() {
  local key="$1" val="$2"
  if [ ! -f "$ENV_FILE" ]; then
    echo "${key}=${val}" >> "$ENV_FILE"
  elif grep -qE "^${key}=" "$ENV_FILE" 2>/dev/null; then
    # Key exists — only replace if current value is empty
    local current
    current="$(get_env_val "$key")"
    if [ -z "$current" ]; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
      else
        sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
      fi
    fi
  else
    echo "${key}=${val}" >> "$ENV_FILE"
  fi
}

# --- main ---

echo "=== GoClaw Environment Preparation ==="
echo ""

# 1. Create .env from .env.example if it doesn't exist
if [ ! -f "$ENV_FILE" ]; then
  if [ -f ".env.example" ]; then
    # Strip 'export ' prefix for Docker Compose compatibility
    sed 's/^export //' .env.example > "$ENV_FILE"
    echo "[created] .env from .env.example (stripped 'export' prefix)"
  else
    touch "$ENV_FILE"
    echo "[created] .env (empty)"
  fi
else
  echo "[exists]  .env"
fi

echo ""

# 2. Auto-generate GOCLAW_ENCRYPTION_KEY if missing
current_enc="$(get_env_val GOCLAW_ENCRYPTION_KEY)"
if [ -z "$current_enc" ]; then
  new_key="$(gen_hex 32)"
  set_env_val "GOCLAW_ENCRYPTION_KEY" "$new_key"
  echo "[generated] GOCLAW_ENCRYPTION_KEY"
else
  echo "[exists]    GOCLAW_ENCRYPTION_KEY"
fi

# 3. Auto-generate GOCLAW_GATEWAY_TOKEN if missing
current_tok="$(get_env_val GOCLAW_GATEWAY_TOKEN)"
if [ -z "$current_tok" ]; then
  new_tok="$(gen_hex 16)"
  set_env_val "GOCLAW_GATEWAY_TOKEN" "$new_tok"
  echo "[generated] GOCLAW_GATEWAY_TOKEN"
else
  echo "[exists]    GOCLAW_GATEWAY_TOKEN"
fi

# 4. Check provider API key
has_provider=false
for key in GOCLAW_OPENROUTER_API_KEY GOCLAW_ANTHROPIC_API_KEY GOCLAW_OPENAI_API_KEY \
           GOCLAW_MINIMAX_API_KEY GOCLAW_GROQ_API_KEY GOCLAW_DEEPSEEK_API_KEY \
           GOCLAW_GEMINI_API_KEY GOCLAW_MISTRAL_API_KEY GOCLAW_XAI_API_KEY; do
  val="$(get_env_val "$key")"
  if [ -n "$val" ]; then
    has_provider=true
    echo "[exists]    $key"
    break
  fi
done

if [ "$has_provider" = false ]; then
  echo ""
  echo "[missing] No LLM provider API key found."
  if [ "$QUIET" = false ]; then
    echo ""
    echo "Enter your API key (or press Enter to skip):"
    echo "  Supported: OpenRouter, Anthropic, OpenAI, MiniMax, Groq, DeepSeek, Gemini, Mistral, xAI"
    echo ""
    read -rp "  GOCLAW_OPENROUTER_API_KEY= " api_key
    if [ -n "$api_key" ]; then
      set_env_val "GOCLAW_OPENROUTER_API_KEY" "$api_key"
      echo "[set]       GOCLAW_OPENROUTER_API_KEY"
    else
      echo "[skipped]   No API key set — you must add one to .env before starting"
    fi
  else
    echo "  Add at least one GOCLAW_*_API_KEY to .env before starting."
  fi
fi

echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  1. Review .env and fill in any remaining values"
echo "  2. Run: docker compose -f docker-compose.yml -f docker-compose.managed.yml up -d --build"
echo ""
