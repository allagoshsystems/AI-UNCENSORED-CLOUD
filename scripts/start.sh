
#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================
# CONFIGURATION
# ==========================================

DATA_DIR="${DATA_DIR:-${GITHUB_WORKSPACE:-.}/data}"

MODEL_PATH="${MODEL_PATH:-$DATA_DIR/models/model.gguf}"
LLAMA_SERVER="${LLAMA_SERVER:-$DATA_DIR/bin/llama-server}"

LLAMA_PORT="${LLAMA_PORT:-8080}"
LLAMA_CTX_SIZE="${LLAMA_CTX_SIZE:-4096}"
LLAMA_THREADS="${LLAMA_THREADS:-4}"
LLAMA_BATCH_SIZE="${LLAMA_BATCH_SIZE:-128}"

CLOUDFLARED="$DATA_DIR/bin/cloudflared"
LOG_DIR="$DATA_DIR/logs"

mkdir -p "$LOG_DIR"

LLAMA_PID=""
TUNNEL_PID=""

# ==========================================
# CLEANUP
# ==========================================

cleanup() {
    echo "Stopping services..."

    if [[ -n "$TUNNEL_PID" ]]; then
        kill "$TUNNEL_PID" 2>/dev/null || true
    fi

    if [[ -n "$LLAMA_PID" ]]; then
        kill "$LLAMA_PID" 2>/dev/null || true
    fi

    wait 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# ==========================================
# VALIDATE
# ==========================================

echo "=========================================="
echo "          GEMMA 4 AI CLOUD"
echo "=========================================="

test -s "$MODEL_PATH"
test -x "$LLAMA_SERVER"
test -x "$CLOUDFLARED"

[[ "$(head -c 4 "$MODEL_PATH")" == "GGUF" ]]

echo "Model: Gemma 4"
echo "Engine: llama.cpp"
echo "Context: $LLAMA_CTX_SIZE"
echo "Port: $LLAMA_PORT"

# ==========================================
# START LLAMA SERVER
# ==========================================

echo
echo "Starting llama.cpp server..."

"$LLAMA_SERVER" \
    --model "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port "$LLAMA_PORT" \
    --ctx-size "$LLAMA_CTX_SIZE" \
    --threads "$LLAMA_THREADS" \
    --batch-size "$LLAMA_BATCH_SIZE" \
    > "$LOG_DIR/llama.log" 2>&1 &

LLAMA_PID=$!

# ==========================================
# HEALTH CHECK
# ==========================================

echo
echo "Waiting for Gemma 4 to become ready..."

HEALTHY=false

for i in $(seq 1 180); do

    if curl --silent --fail \
        "http://127.0.0.1:${LLAMA_PORT}/health" \
        >/dev/null; then

        HEALTHY=true
        break
    fi

    if ! kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo "ERROR: llama.cpp exited."
        cat "$LOG_DIR/llama.log"
        exit 1
    fi

    echo "Health check $i/180"
    sleep 5

done

if [[ "$HEALTHY" != "true" ]]; then
    echo "ERROR: Model health check timed out."
    cat "$LOG_DIR/llama.log"
    exit 1
fi

echo
echo "=========================================="
echo "          GEMMA 4 IS READY"
echo "=========================================="

# ==========================================
# START CLOUDFLARE QUICK TUNNEL
# ==========================================

echo
echo "Starting Cloudflare Quick Tunnel..."

"$CLOUDFLARED" tunnel \
    --url "http://127.0.0.1:${LLAMA_PORT}" \
    --no-autoupdate \
    > "$LOG_DIR/cloudflared.log" 2>&1 &

TUNNEL_PID=$!

# ==========================================
# EXTRACT AUTOMATIC PUBLIC URL
# ==========================================

echo
echo "Waiting for Cloudflare public URL..."

PUBLIC_URL=""

for i in $(seq 1 90); do

    PUBLIC_URL=$(
        grep -Eo 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' \
            "$LOG_DIR/cloudflared.log" |
        head -n 1 || true
    )

    if [[ -n "$PUBLIC_URL" ]]; then
        break
    fi

    if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
        echo "ERROR: Cloudflare tunnel stopped."
        cat "$LOG_DIR/cloudflared.log"
        exit 1
    fi

    sleep 2

done

# ==========================================
# VERIFY PUBLIC URL
# ==========================================

if [[ -z "$PUBLIC_URL" ]]; then
    echo "ERROR: Unable to obtain Cloudflare URL."
    cat "$LOG_DIR/cloudflared.log"
    exit 1
fi

# ==========================================
# DISPLAY URL
# ==========================================

echo
echo "=========================================="
echo "          GEMMA 4 PUBLIC CHAT"
echo "=========================================="

echo "PUBLIC URL: $PUBLIC_URL"

echo "MODEL: GEMMA 4 UNCENSORED"
echo "ENGINE: LLAMA.CPP"
echo "STATUS: RUNNING"

echo "=========================================="

# GitHub Actions clickable annotation
echo "::notice title=Gemma 4 Public Chat::$PUBLIC_URL"

# Keep runner alive
wait "$TUNNEL_PID"
