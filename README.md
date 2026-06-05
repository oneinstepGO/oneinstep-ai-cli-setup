# OneInStep AI CLI Setup

One-step setup scripts for OneInStep AI CLI tools.

## Claude Code

Run on macOS:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oneinstepGO/oneinstep-ai-cli-setup/main/claude-code/install.sh)" -- 'sk-your-token'
```

The token is passed as the first script argument. Do not commit real tokens to this repository.

The Claude Code installer updates:

- `~/.zshrc`
- `~/.bashrc`
- `~/.bash_profile` when it already exists or when the current shell is bash
- `~/.claude/settings.json`

It writes a managed environment block to shell profile files and replaces the `env` object in Claude Code settings while preserving other top-level settings.

## Layout

```text
claude-code/install.sh
codex/install.sh
```

`codex/install.sh` is reserved for the Codex CLI setup script.
