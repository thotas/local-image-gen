# Local Photorealistic Image Generation

Fully local photorealistic image generation pipeline running on Apple Silicon. No cloud, no API keys.

## Stack

| Component | Version | Purpose |
|---|---|---|
| ComfyUI | v0.18.1 | Diffusion model UI and workflow engine |
| Ollama | v0.20.2 | LLM prompt orchestration |
| Juggernaut XL Ragnarok | latest | Photorealistic SDXL checkpoint |
| SD Prompt Maker (llama3) | impactframes/llama3_ifai_sd_prompt_mkr_q4km | Prompt enrichment LLM |
| Python | 3.14.3 | Runtime |
| PyTorch | 2.11.0 | ML framework (MPS backend) |

## Hardware

- Mac Mini M4 (base), 24GB unified memory
- 10-core GPU via Metal Performance Shaders (MPS)
- Expect ~60-90 seconds per 1024x1024 image at 25 steps

## Quick Start

### 1. Start Services

```bash
./start.sh
```

This starts Ollama (if not running) and ComfyUI with optimal settings for M4.

### 2. Generate an Image

```bash
./generate.sh "woman in rain, Tokyo street, night"
```

Your short prompt is automatically enriched by the local LLM before being sent to Juggernaut XL. The enriched prompt adds cinematic detail, lighting, atmosphere, and camera specifics.

### 3. View Results

- Images save to `~/Development/ComfyUI/output/`
- Filenames start with `photorealistic_`
- Open ComfyUI UI at http://localhost:8188 for visual workflow editing

## How It Works

```
Short user prompt
    -> Ollama LLM (SD Prompt Maker) enriches it
    -> CLIP encodes the enriched prompt
    -> KSampler denoises (25 steps, DPM++ 2M Karras, CFG 7)
    -> VAE decodes to pixels
    -> Saved as PNG
```

## Generation Settings

| Setting | Value |
|---|---|
| Resolution | 1024 x 1024 |
| Steps | 25 |
| CFG Scale | 7.0 |
| Sampler | DPM++ 2M |
| Scheduler | Karras |
| Precision | fp16 (forced) |
| Negative prompt | cartoon, anime, painting, illustration, blurry, low quality, bad anatomy, deformed hands, watermark |

## Directory Structure

```
local-image-gen/
  start.sh              # Launch Ollama + ComfyUI
  generate.sh           # CLI image generation
  workflows/
    photorealistic_ollama.json  # ComfyUI workflow (API format)
  README.md             # This file

~/Development/ComfyUI/
  main.py               # ComfyUI entry point
  venv/                 # Python virtual environment
  models/checkpoints/   # Model files (.safetensors)
  custom_nodes/         # ComfyUI-Manager, comfyui-ollama
  output/               # Generated images
```

## Adding New Models

1. Download `.safetensors` files (never `.ckpt`)
2. Place in `~/Development/ComfyUI/models/checkpoints/`
3. Restart ComfyUI
4. Update the workflow JSON or select in the UI

## Memory Notes

- Close heavy browser tabs during generation
- ComfyUI runs with `--force-fp16` to halve VRAM usage
- `PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0` is set by `start.sh` to prevent OOM
- If memory pressure hits red, add `--lowvram` to ComfyUI launch and restart

## Troubleshooting

| Error | Fix |
|---|---|
| `MPS backend out of memory` | Add `--lowvram` to ComfyUI launch, close other apps |
| ComfyUI node not found | Restart ComfyUI after installing nodes |
| Ollama not responding | Run `ollama serve` manually, check port 11434 |
| Black images generated | Add `--no-half-vae` to ComfyUI launch flags |
| Model not in dropdown | Confirm `.safetensors` is in `models/checkpoints/`, restart ComfyUI |
| SSL errors in Manager | Run `/Applications/Python 3.14/Install Certificates.command` |

## Manual ComfyUI Launch

If you prefer to run ComfyUI directly:

```bash
cd ~/Development/ComfyUI
source venv/bin/activate
PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0 python3 main.py --force-fp16
```

## Using the ComfyUI Web UI

1. Open http://localhost:8188
2. Load the workflow: Menu > Load > select `photorealistic_ollama.json`
3. Enter your prompt in the OllamaGenerateAdvance node
4. Click "Queue Prompt"

## Known Issues

- ComfyUI Manager's remote fetching requires SSL certificates to be installed for Python 3.14
- The `comfy-aimdo` module only supports Windows/Linux (harmless warning on macOS)
- First generation after launch takes longer due to model loading into GPU memory
