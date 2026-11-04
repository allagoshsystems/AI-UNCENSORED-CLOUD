#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p logs

SERVER_PID=""
TUNNEL_PID=""

cleanup() {
  echo "Cleaning up background processes..."
  if [[ -n "${TUNNEL_PID}" ]]; then
    kill "${TUNNEL_PID}" 2>/dev/null || true
  fi
  if [[ -n "${SERVER_PID}" ]]; then
    kill "${SERVER_PID}" 2>/dev/null || true
  fi
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

: "${MODEL_PATH:?MODEL_PATH is required}"
: "${LLAMA_PORT:=8080}"
: "${LLAMA_CTX_SIZE:=4096}"
: "${LLAMA_THREADS:=4}"
: "${LLAMA_BATCH_SIZE:=128}"
: "${CLOUDFLARE_TUNNEL_TOKEN:?CLOUDFLARE_TUNNEL_TOKEN is required}"

SERVER_BIN="./llama.cpp/build/bin/llama-server"
if [[ ! -x "$SERVER_BIN" ]]; then
  echo "Missing llama-server binary: $SERVER_BIN"
  exit 1
fi
if [[ ! -s "$MODEL_PATH" ]]; then
  echo "GGUF model is missing or empty: $MODEL_PATH"
  exit 1
fi

echo "Starting Gemma 4 model server on 127.0.0.1:${LLAMA_PORT}"
"$SERVER_BIN" \
  --model "$MODEL_PATH" \
  --host 127.0.0.1 \
  --port "$LLAMA_PORT" \
  --ctx-size "$LLAMA_CTX_SIZE" \
  --threads "$LLAMA_THREADS" \
  --batch-size "$LLAMA_BATCH_SIZE" \
  --jinja \
  --temp 1.0 \
  --top-p 0.95 \
  --top-k 64 \
  --parallel 1 \
  > logs/llama-server.log 2>&1 &
SERVER_PID=$!

echo "Waiting for llama.cpp health endpoint..."
READY=0
for attempt in $(seq 1 180); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "llama-server exited before becoming healthy."
    tail -n 150 logs/llama-server.log || true
    exit 1
  fi

  HTTP_CODE="$(curl --silent --output /dev/null \
    --write-out '%{http_code}' \
    "http://127.0.0.1:${LLAMA_PORT}/health" || true)"

  if [[ "$HTTP_CODE" == "200" ]]; then
    READY=1
    break
  fi

  if (( attempt % 12 == 0 )); then
    echo "Still waiting (attempt ${attempt}/180; HTTP ${HTTP_CODE:-no response})..."
  fi
  sleep 5
done

if [[ "$READY" != "1" ]]; then
  echo "Model did not become healthy within 15 minutes."
  tail -n 200 logs/llama-server.log || true
  exit 1
fi

echo "Model is healthy. Starting Cloudflare Tunnel now."
cloudflared tunnel --no-autoupdate run \
  --token "$CLOUDFLARE_TUNNEL_TOKEN" \
  > logs/cloudflared.log 2>&1 &
TUNNEL_PID=$!

sleep 5
if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
  echo "cloudflared exited during startup."
  tail -n 100 logs/cloudflared.log || true
  exit 1
fi

echo "Both services are running."
echo "Configure the Cloudflare public hostname service as http://127.0.0.1:${LLAMA_PORT}"
echo "The native llama.cpp web UI is served by llama-server itself."

while kill -0 "$SERVER_PID" 2>/dev/null && kill -0 "$TUNNEL_PID" 2>/dev/null; do
  sleep 10
done

echo "A service exited unexpectedly."
tail -n 100 logs/llama-server.log || true
tail -n 100 logs/cloudflared.log || true
exit 1
