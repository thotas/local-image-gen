#!/bin/zsh

# generate.sh - CLI wrapper to trigger ComfyUI image generation
# Usage: ./generate.sh ["prompt text"]

set -euo pipefail

PROMPT="${1:-a photorealistic portrait}"
COMFYUI_URL="http://localhost:8188"
WORKFLOW_FILE="$(dirname "$0")/workflows/photorealistic_ollama.json"
PYTHON="$HOME/Development/ComfyUI/venv/bin/python3"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Error: Workflow file not found at $WORKFLOW_FILE"
  exit 1
fi

if ! curl -s --connect-timeout 3 "$COMFYUI_URL/system_stats" > /dev/null 2>&1; then
  echo "Error: ComfyUI is not running at $COMFYUI_URL"
  echo "Run ./start.sh first."
  exit 1
fi

echo "Prompt: $PROMPT"
echo "Loading workflow from: $WORKFLOW_FILE"

# Use Python to inject prompt and randomize seed, then send to ComfyUI
RESPONSE=$("$PYTHON" - "$WORKFLOW_FILE" "$PROMPT" "$COMFYUI_URL" <<'PYEOF'
import json, random, sys, urllib.request

workflow_file = sys.argv[1]
user_prompt = sys.argv[2]
comfyui_url = sys.argv[3]

with open(workflow_file, 'r') as f:
    workflow = json.load(f)

# Inject the user prompt into node 1 (OllamaGenerateAdvance)
workflow['1']['inputs']['prompt'] = user_prompt

# Randomize the seed in node 6 (KSampler)
workflow['6']['inputs']['seed'] = random.randint(0, 2**63 - 1)

print(f"Seed: {workflow['6']['inputs']['seed']}", file=sys.stderr)

# Wrap workflow in {"prompt": <workflow>} for the API
payload = json.dumps({'prompt': workflow}).encode('utf-8')

req = urllib.request.Request(
    f'{comfyui_url}/prompt',
    data=payload,
    headers={'Content-Type': 'application/json'}
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
print(result['prompt_id'])
PYEOF
)

PROMPT_ID=$(echo "$RESPONSE" | tail -1)
echo "Submitted! Prompt ID: $PROMPT_ID"
echo "Waiting for generation to complete..."

# Poll /history for completion
while true; do
  STATUS_FILE=$(mktemp)
  IMAGES=$("$PYTHON" - "$COMFYUI_URL" "$PROMPT_ID" "$STATUS_FILE" <<'PYEOF'
import json, urllib.request, sys

comfyui_url = sys.argv[1]
prompt_id = sys.argv[2]
status_file = sys.argv[3]

req = urllib.request.Request(f'{comfyui_url}/history/{prompt_id}')
try:
    resp = urllib.request.urlopen(req)
    data = json.loads(resp.read())
    if prompt_id in data:
        outputs = data[prompt_id].get('outputs', {})
        for node_id, node_out in outputs.items():
            if 'images' in node_out:
                for img in node_out['images']:
                    filename = img.get('filename', '')
                    subfolder = img.get('subfolder', '')
                    if subfolder:
                        print(f'{subfolder}/{filename}')
                    else:
                        print(filename)
        with open(status_file, 'w') as f:
            f.write('DONE')
    else:
        with open(status_file, 'w') as f:
            f.write('PENDING')
except Exception as e:
    with open(status_file, 'w') as f:
        f.write(f'ERROR: {e}')
PYEOF
)

  STATUS=$(cat "$STATUS_FILE" 2>/dev/null)
  rm -f "$STATUS_FILE"

  if [[ "$STATUS" == "DONE" ]]; then
    if [[ -n "$IMAGES" ]]; then
      echo ""
      echo "Generation complete!"
      echo "Output image(s):"
      echo "$IMAGES" | while read -r img; do
        echo "  $HOME/Development/ComfyUI/output/$img"
      done
    else
      echo ""
      echo "Generation complete! (no output images found in history)"
    fi
    break
  elif [[ "$STATUS" == ERROR* ]]; then
    echo "Error polling history: $STATUS"
    break
  fi

  sleep 2
done
