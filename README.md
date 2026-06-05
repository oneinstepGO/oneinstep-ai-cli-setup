# OneInStep AI CLI Setup

One-step setup scripts for OneInStep AI CLI tools.

## Claude Code

Run on macOS:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oneinstepGO/oneinstep-ai-cli-setup/main/claude-code/install.sh)" -- 'sk-your-token'
```

The token is passed as the first script argument. Do not commit real tokens to this repository.
Pass the token exactly as provided, including its existing `sk-` prefix. Do not add another `sk-`.

The Claude Code installer updates:

- `~/.zshrc`
- `~/.bashrc`
- `~/.bash_profile` when it already exists or when the current shell is bash
- `~/.claude/settings.json`

It writes a managed environment block to shell profile files and replaces the `env` object in Claude Code settings while preserving other top-level settings.

## Codex CLI

Run on macOS:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oneinstepGO/oneinstep-ai-cli-setup/main/codex/install.sh)" -- 'sk-your-token'
```

The Codex installer updates:

- `~/.codex/config.toml`
- `~/.codex/auth.json`

It configures Codex CLI to use the OneInStep OpenAI-compatible endpoint and writes the token to `OPENAI_API_KEY` in `auth.json`.
Pass the token exactly as provided, including its existing `sk-` prefix. Do not add another `sk-`.

## Layout

```text
claude-code/install.sh
codex/install.sh
```
