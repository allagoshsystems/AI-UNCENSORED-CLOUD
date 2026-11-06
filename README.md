# 🚀 AI UNLEASHED — LLAMA.CPP CLOUD

### Your AI. Your Models. Your Cloud. No Dedicated Server Required.

**AI-UNLEASHED-LLAMA-CPP-CLOUD** is an open-source project designed to deploy and access uncensored, open-source AI language models through a cloud-based environment using **GitHub Actions, llama.cpp, and Cloudflare Tunnel**.

No complicated server configuration. No need to build a frontend from scratch. Just set up the repository, configure your required settings, launch the workflow, and connect to your AI.

---

## ✨ Features

- 🤖 **Uncensored AI Models** — Run compatible open-source and uncensored language models.
- ☁️ **Cloud-Based Deployment** — Launch your AI environment through GitHub Actions.
- ⚡ **llama.cpp Engine** — Efficient inference using GGUF-compatible models.
- 🌐 **Public Access** — Expose your running AI server through Cloudflare Tunnel.
- 💬 **Web Chat Interface** — Access the native llama.cpp chat interface through your browser.
- 🔧 **Custom Models** — Configure compatible Hugging Face models.
- 🔄 **Automated Startup** — Automate model initialization, health checks, and tunnel startup.
- 🆓 **Free-First Design** — Designed to use available free resources where possible.

## 🧠 How It Works

The deployment follows this sequence:

1. GitHub Actions starts the configured environment.
2. The workflow installs or initializes llama.cpp.
3. The selected AI model is downloaded and loaded.
4. The llama.cpp server starts.
5. A health check verifies that the AI server is responding.
6. Cloudflare Tunnel creates a public connection.
7. Open the generated URL and start chatting with your AI.

```text
          YOU
           |
           v
      GitHub Actions
           |
           v
       AI Runtime
           |
           v
        llama.cpp
           |
           v
     GGUF AI MODEL
           |
           v
      Cloudflare Tunnel
           |
           v
      PUBLIC AI URL
           |
           v
       WEB CHAT UI
```

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/allagoshsystems/AI-UNCENSORED-CLOUD.git

cd AI-UNLEASHED-LLAMA-CPP-CLOUD
```

### 2. Configure GitHub Secrets

Open your repository:

**Settings → Secrets and variables → Actions**

Add the secrets required by your selected deployment workflow.

For Cloudflare Tunnel deployments, you will generally need a Cloudflare Tunnel token. Check the workflow configuration for the exact secret name.

Never publish your private tokens or API credentials in your repository.

### 3. Enable GitHub Actions

1. Open the repository on GitHub.
2. Navigate to the **Actions** tab.
3. Allow GitHub Actions if prompted.
4. Select the available deployment workflow.
5. Click **Run workflow**.

### 4. Connect to Your AI

Wait for the workflow to download the model, start llama.cpp, pass its health check, and establish the Cloudflare Tunnel.

Once the workflow displays the public URL, open it in your browser.

**That's it. Your AI chat interface is ready!**

---

## 🧩 Model Compatibility

This project is designed around llama.cpp and compatible GGUF models.

You can configure different models depending on available memory and hardware.

Potential model families include:

- Llama
- Gemma
- Qwen
- Mistral
- DeepSeek
- Other compatible GGUF models

Model availability, quantization, and hardware requirements depend on your selected configuration.

## ⚙️ Customization

You can customize:

- Hugging Face model repository
- Model filename
- GGUF quantization
- Context size
- GPU layers and CPU offloading
- Server configuration
- Cloudflare Tunnel settings

Refer to the workflow files and configuration included in this repository.

## ⚠️ Important Notes

- GitHub Actions coordinates the deployment; it does not automatically provide a free GPU.
- Standard GitHub-hosted runners are generally CPU-only. GPU execution requires an available GPU-enabled environment.
- Free GitHub Actions usage and execution limits depend on your account and runner type.
- Cloudflare Tunnel URLs are available only while the tunnel and underlying server are running.
- Large AI models require sufficient RAM, VRAM, storage, and download time.
- Some models may have their own licenses and usage restrictions. Check the model publisher's license before use.

## 🔐 Privacy & Security

- Keep Cloudflare tokens and other credentials in GitHub Secrets.
- Do not commit private API keys or access tokens.
- Review the license and security requirements of every model you deploy.
- Only expose services you intend to make publicly accessible.

## 📜 Disclaimer

This repository is an AI deployment and inference project. It does not host or claim ownership of third-party AI models.

Users are responsible for complying with applicable laws, model licenses, and the policies of the services they use.

## ⭐ Support the Project

If you find this project useful:

- ⭐ Star this repository.
- 🍴 Fork it.
- 🛠️ Contribute improvements.
- 🐛 Report bugs and issues.
- 💡 Share compatible models and configurations.

---

### Built for people who want more control over their AI.

**AI UNLEASHED — Your Models. Your Rules. Your Cloud.**
