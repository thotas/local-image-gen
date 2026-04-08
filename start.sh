#!/bin/zsh

# start.sh - Launch Ollama and ComfyUI for local image generation

set -euo pipefail

COMFYUI_DIR="$HOME/Development/ComfyUI"
COMFYUI_VENV="$COMFYUI_DIR/venv"
COMFYUI_PORT=8188

echo "=== Local Image Generation Launcher ==="
echo ""

# --- Ollama ---
if pgrep -x "ollama" > /dev/null 2>&1 || curl -s --connect-timeout 2 http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
  echo "[Ollama] Already running."
else
  echo "[Ollama] Starting..."
  ollama serve > /dev/null 2>&1 &
  OLLAMA_PID=$!
  echo "[Ollama] Started (PID: $OLLAMA_PID)"

  # Wait for Ollama to be ready
  echo "[Ollama] Waiting for service to be ready..."
  for i in {1..30}; do
    if curl -s --connect-timeout 2 http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
      echo "[Ollama] Ready."
      break
    fi
    if (( i == 30 )); then
      echo "[Ollama] ERROR: Failed to start after 30 seconds."
      exit 1
    fi
    sleep 1
  done
fi

# --- ComfyUI ---
if curl -s --connect-timeout 2 "http://localhost:$COMFYUI_PORT/system_stats" > /dev/null 2>&1; then
  echo "[ComfyUI] Already running on port $COMFYUI_PORT."
else
  echo "[ComfyUI] Starting on port $COMFYUI_PORT..."

  if [[ ! -d "$COMFYUI_VENV" ]]; then
    echo "[ComfyUI] ERROR: venv not found at $COMFYUI_VENV"
    exit 1
  fi

  export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0

  source "$COMFYUI_VENV/bin/activate"
  cd "$COMFYUI_DIR"
  python3 main.py --force-fp16 --port $COMFYUI_PORT > /dev/null 2>&1 &
  COMFYUI_PID=$!
  echo "[ComfyUI] Started (PID: $COMFYUI_PID)"

  # Wait for ComfyUI to be ready
  echo "[ComfyUI] Waiting for service to be ready..."
  for i in {1..60}; do
    if curl -s --connect-timeout 2 "http://localhost:$COMFYUI_PORT/system_stats" > /dev/null 2>&1; then
      echo "[ComfyUI] Ready."
      break
    fi
    if (( i == 60 )); then
      echo "[ComfyUI] ERROR: Failed to start after 60 seconds."
      exit 1
    fi
    sleep 1
  done
fi

echo ""
echo "=== All services ready ==="
echo "  Ollama:  http://127.0.0.1:11434"
echo "  ComfyUI: http://localhost:$COMFYUI_PORT"
echo ""
echo "Run ./generate.sh \"your prompt here\" to generate an image."
