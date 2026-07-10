# Setup Ideas & Future Improvements

This document tracks potential additions and tool integrations for the coding-agent setup.

---

## 💻 1. VS Code Server & Secure Tunnel

### Overview
VS Code Server allows developers to run VS Code on a remote machine and access it via a lightweight, secure web interface or standard VS Code desktop clients. 

### Why Integrate It?
* **Remote Access:** Code, debug, and run agent workflows directly on the VM from any device with a web browser.
* **Unified Development:** Bridges the gap between terminal-based agent interactions and a full GUI IDE environment.
* **Direct Agent Integration:** Allows coding agents (like Antigravity or Claude Code) to easily manipulate files, while developers inspect the results in real-time in their editor workspace.

### How to Install & Configure
Install using Microsoft's standalone CLI installer:
```bash
# Download and unpack
curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output vscode_cli.tar.gz
tar -xf vscode_cli.tar.gz

# Make it globally accessible and clean up
sudo mv code /usr/local/bin/
rm vscode_cli.tar.gz

# Start the secure tunnel (creates a visualstudio.com link to access the VS Code web UI)
code tunnel
```

### Verification
Run `code --version` or verify the active secure tunnel service.

---

## 🤖 2. OpenCode, OpenRouter, & LiteLLM Integration

### Overview
These utilities provide robust LLM orchestration, proxying, and client interfaces for unified agent execution across diverse models and providers.

### Why Integrate Them?
* **OpenCode:** Integrates customized coding assistant extensions and plugins for prompt execution and syntax analysis.
* **OpenRouter:** A single, unified API endpoint to access over 100+ state-of-the-art models (including Claude 3.5 Sonnet, Gemini 1.5 Pro, Llama-3) with simplified token usage and billing.
* **LiteLLM:** A lightweight, OpenAI-compatible translation proxy. It translates standard OpenAI chat-completion API formats to Anthropic, Vertex AI, Cohere, and other providers seamlessly.

### How to Install & Configure
* **LiteLLM CLI & Proxy:**
  Can be installed via `pip` or global `uv tool`:
  ```bash
  uv tool install litellm --with "litellm[proxy]"
  ```
  Run the proxy locally to translate local workspace requests to OpenAI format:
  ```bash
  litellm --model vertex_chat/gemini-1.5-pro
  ```
* **OpenRouter:**
  Typically configured as an environment-variable endpoint target for your model client or agent:
  ```bash
  export OPENROUTER_API_KEY="your-api-key"
  ```
* **OpenCode:**
  Typically installed as an extension or IDE integration.

### Verification
Run `litellm --version` or execute a query through the LiteLLM proxy port.
