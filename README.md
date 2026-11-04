# Gemma 4 GGUF — GitHub Actions + llama.cpp + Cloudflare Tunnel

This repository builds `llama.cpp`, downloads a selected GGUF quant from
Hugging Face, starts the native llama.cpp server UI, waits for `/health` to
return HTTP 200, and only then starts the Cloudflare Tunnel.

## Selected model

- Repository: `HauhauCS/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive`
- Default quant: `Q4_K_M`
- File: `Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf`
- Model card: https://huggingface.co/HauhauCS/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive

The model card lists Q4_K_M at about 5.0 GB and recommends `--jinja`,
temperature 1.0, top-p 0.95 and top-k 64. This repo applies those settings.
The optional mmproj file is not downloaded: this workflow is text-chat first.

## Required GitHub secret

In repository Settings → Secrets and variables → Actions, create:

- `CLOUDFLARE_TUNNEL_TOKEN`: token for a named Cloudflare Tunnel.
- `HF_TOKEN`: optional; only needed if Hugging Face requires authentication
  for the repository/file.

Never commit tunnel tokens or Hugging Face tokens.

## Cloudflare setup

1. Create a named tunnel in the Cloudflare Zero Trust dashboard.
2. Copy its tunnel token into the `CLOUDFLARE_TUNNEL_TOKEN` GitHub secret.
3. Add a public hostname, e.g. `ai.example.com`.
4. Set the origin service to `http://127.0.0.1:8080`.
5. Start the workflow manually from GitHub Actions.

The workflow starts llama-server first, checks `http://127.0.0.1:8080/health`,
and starts cloudflared only after the health check succeeds.

## Run

GitHub → Actions → Run Gemma 4 GGUF on GitHub Actions → Run workflow.

Start with:
- Context size: `4096`
- Quantization: `Q4_K_M`

If the runner runs out of disk or RAM, try `IQ4_XS` or `Q3_K_M`, or use a
larger self-hosted runner. Q4_K_M is still a roughly 5 GB download, so this is
a heavy workload for standard GitHub-hosted runners.

## Important: this is not permanent hosting

GitHub-hosted runners are ephemeral and GitHub Actions jobs have a maximum
runtime. The tunnel and model server are available only while the workflow job
is alive. The workflow timeout is set to 350 minutes, below the six-hour
GitHub-hosted job limit. It is for testing/demo sessions, not a 24/7 service.

For always-on hosting, run the same scripts on a persistent Linux VPS or
self-hosted runner and keep GitHub Actions as the build/deployment trigger.

## Public access warning

The Cloudflare hostname is publicly reachable unless you protect it. Anyone
who can reach the hostname may be able to use the model and consume CPU/RAM.
For a public production endpoint, add Cloudflare Access, rate limiting, and
usage controls. Do not expose an unrestricted inference API unintentionally.

## Notes

- No GitHub Pages site is used. GitHub Pages cannot execute llama.cpp or host
  a running Python/C++ inference server.
- The native chat UI is served by llama.cpp itself; no separate frontend.
- This workflow builds CPU-only llama.cpp. Standard GitHub-hosted runners do
  not provide a dedicated GPU for this job.
- The workflow builds the current llama.cpp default branch. If a later upstream
  change breaks compatibility, pin the clone to a tested commit.
