
#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Universal llama.cpp + Cloudflare Quick Tunnel launcher
# Supports any compatible GGUF model.
# ============================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${DATA_DIR:-$ROOT_DIR/data}"

BIN_DIR="$DATA_DIR/bin"
MODEL_DIR="$DATA_DIR/models"
CONFIG_DIR="$DATA_DIR/config"
LOG_DIR="$DATA_DIR/logs"
CONVERSATIONS_DIR="$DATA_DIR/conversations"

mkdir -p "$LOG_DIR" "$CONVERSATIONS_DIR"

# -------------------- MODEL SETTINGS -------------------------

MODEL_PATH="${MODEL_PATH:-$MODEL_DIR/model.gguf}"
MODEL_NAME="${MODEL_NAME:-$(basename "$MODEL_PATH")}"

LLAMA_SERVER="${LLAMA_SERVER:-$BIN_DIR/llama-server}"
CLOUDFLARED="${CLOUDFLARED:-$BIN_DIR/cloudflared}"

LLAMA_HOST="${LLAMA_HOST:-127.0.0.1}"
LLAMA_PORT="${LLAMA_PORT:-8080}"

CONTEXT_SIZE="${CONTEXT_SIZE:-8192}"
THREADS="${THREADS:-4}"
BATCH_SIZE="${BATCH_SIZE:-128}"
GPU_LAYERS="${GPU_LAYERS:-0}"
PARALLEL="${PARALLEL:-1}"

# -------------------- INFERENCE SETTINGS --------------------

TEMP="${TEMP:-0.6}"
TOP_P="${TOP_P:-0.95}"
TOP_K="${TOP_K:-40}"
MIN_P="${MIN_P:-0.05}"
REPEAT_PENALTY="${REPEAT_PENALTY:-1.1}"

# Optional extra llama-server arguments.
# Example: EXTRA_ARGS="--jinja --flash-attn on"
EXTRA_ARGS="${EXTRA_ARGS:-}"

# -------------------- LOG FILES -----------------------------

MODEL_LOG="$LOG_DIR/llama-server.log"
TUNNEL_LOG="$LOG_DIR/cloudflared.log"

MODEL_PID=""
TUNNEL_PID=""

# -------------------- CLEANUP --------------------------------

cleanup() {
    echo "Stopping services..."

    [[ -n "$TUNNEL_PID" ]] && kill "$TUNNEL_PID" 2>/dev/null || true
    [[ -n "$MODEL_PID" ]] && kill "$MODEL_PID" 2>/dev/null || true

    wait 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# -------------------- VALIDATION -----------------------------

for executable in "$LLAMA_SERVER" "$CLOUDFLARED"; do
    if [[ ! -x "$executable" ]]; then
        echo "ERROR: Executable missing or not executable: $executable"
        exit 1
    fi
done

if [[ ! -f "$MODEL_PATH" ]]; then
    echo "ERROR: Model file not found: $MODEL_PATH"
    exit 1
fi

if [[ ! -s "$MODEL_PATH" ]]; then
    echo "ERROR: Model file is empty: $MODEL_PATH"
    exit 1
fi

echo "============================================================"
echo "Universal llama.cpp deployment"
echo "============================================================"
echo "Model:       $MODEL_NAME"
echo "Model path:  $MODEL_PATH"
echo "Context:     $CONTEXT_SIZE"
echo "Threads:     $THREADS"
echo "Batch:       $BATCH_SIZE"
echo "GPU layers:  $GPU_LAYERS"
echo "Port:        $LLAMA_PORT"
echo "============================================================"

# -------------------- START MODEL SERVER ---------------------

SERVER_ARGS=(
    --model "$MODEL_PATH"
    --host "$LLAMA_HOST"
    --port "$LLAMA_PORT"
    --ctx-size "$CONTEXT_SIZE"
    --threads "$THREADS"
    --batch-size "$BATCH_SIZE"
    --n-gpu-layers "$GPU_LAYERS"
    --parallel "$PARALLEL"
    --temp "$TEMP"
    --top-p "$TOP_P"
    --top-k "$TOP_K"
    --min-p "$MIN_P"
    --repeat-penalty "$REPEAT_PENALTY"
)

# Split optional extra arguments.
if [[ -n "$EXTRA_ARGS" ]]; then
    read -r -a EXTRA_ARRAY <<< "$EXTRA_ARGS"
    SERVER_ARGS+=("${EXTRA_ARRAY[@]}")
fi

echo "Starting llama-server..."

"$LLAMA_SERVER" "${SERVER_ARGS[@]}" > "$MODEL_LOG" 2>&1 &
MODEL_PID=$!

# -------------------- HEALTH CHECK ---------------------------

echo "Waiting for model server..."

MAX_ATTEMPTS="${HEALTH_ATTEMPTS:-180}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-5}"

MODEL_READY=0

for ((i=1; i<=MAX_ATTEMPTS; i++)); do

    if ! kill -0 "$MODEL_PID" 2>/dev/null; then
        echo "ERROR: llama-server stopped unexpectedly."
        tail -n 100 "$MODEL_LOG" || true
        exit 1
    fi

    if curl -fsS "http://$LLAMA_HOST:$LLAMA_PORT/health" >/dev/null 2>&1; then
        MODEL_READY=1
        break
    fi

    echo "Model loading: $i/$MAX_ATTEMPTS"
    sleep "$HEALTH_INTERVAL"
done

if [[ "$MODEL_READY" -ne 1 ]]; then
    echo "ERROR: Model health check timed out."
    tail -n 100 "$MODEL_LOG" || true
    exit 1
fi

echo "Model server is ready!"

# -------------------- START CLOUDFLARE TUNNEL ----------------

echo "Starting Cloudflare Quick Tunnel..."

"$CLOUDFLARED" tunnel \
    --no-autoupdate \
    --url "http://$LLAMA_HOST:$LLAMA_PORT" \
    > "$TUNNEL_LOG" 2>&1 &

TUNNEL_PID=$!

# -------------------- EXTRACT PUBLIC URL ---------------------

echo "Waiting for public URL..."

TUNNEL_URL=""
TUNNEL_ATTEMPTS="${TUNNEL_ATTEMPTS:-60}"

for ((i=1; i<=TUNNEL_ATTEMPTS; i++)); do

    if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
        echo "ERROR: Cloudflare tunnel stopped."
        tail -n 100 "$TUNNEL_LOG" || true
        exit 1
    fi

    TUNNEL_URL="$(
        grep -Eo 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' \
        "$TUNNEL_LOG" | head -n 1 || true
    )"

    if [[ -n "$TUNNEL_URL" ]]; then
        break
    fi

    sleep 2
done

if [[ -z "$TUNNEL_URL" ]]; then
    echo "ERROR: Could not obtain Cloudflare public URL."
    tail -n 100 "$TUNNEL_LOG" || true
    exit 1
fi

# -------------------- DISPLAY PUBLIC URL --------------------

echo ""
echo "============================================================"
echo "          LLAMA.CPP SERVER IS ONLINE"
echo "============================================================"
echo ""
echo "MODEL:       $MODEL_NAME"
echo "PUBLIC URL:  $TUNNEL_URL"
echo "CHAT UI:     $TUNNEL_URL"
echo "API:         $TUNNEL_URL/v1"
echo ""
echo "============================================================"

# GitHub Actions summary
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        echo "# llama.cpp deployment"
        echo ""
        echo "- **Model:** $MODEL_NAME"
        echo "- **Context:** $CONTEXT_SIZE"
        echo "- **Public URL:** $TUNNEL_URL"
        echo "- **Chat UI:** $TUNNEL_URL"
        echo "- **API endpoint:** $TUNNEL_URL/v1"
    } >> "$GITHUB_STEP_SUMMARY"
fi

# GitHub Actions notice
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::notice title=llama.cpp Ready::$TUNNEL_URL"
fi

# -------------------- KEEP RUNNER ALIVE ---------------------

echo "Services are running. Keep this workflow active."

while true; do
    if ! kill -0 "$MODEL_PID" 2>/dev/null; then
        echo "ERROR: Model server exited."
        tail -n 100 "$MODEL_LOG" || true
        exit 1
    fi

    if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
        echo "ERROR: Cloudflare tunnel exited."
        tail -n 100 "$TUNNEL_LOG" || true
        exit 1
    fi

    sleep 15
done
