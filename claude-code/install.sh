#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://ai.oneinstep.com"
DISABLE_NONESSENTIAL_TRAFFIC="1"
ATTRIBUTION_HEADER="0"
BEGIN_MARKER="# >>> claude-code-oneinstep-env >>>"
END_MARKER="# <<< claude-code-oneinstep-env <<<"

usage() {
  cat <<'EOF'
Usage:
  bash install.sh <ANTHROPIC_AUTH_TOKEN>
  ./install.sh <ANTHROPIC_AUTH_TOKEN>

Example:
  bash install.sh 'sk-your-token'
EOF
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

info() {
  printf '%s\n' "$1"
}

quote_for_shell() {
  printf "'"
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

require_macos() {
  local os_name
  os_name="$(uname -s)"
  if [ "$os_name" != "Darwin" ]; then
    fail "this installer only supports macOS. Detected: $os_name"
  fi
}

parse_token() {
  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
  fi

  if [ "$#" -ne 1 ]; then
    usage
    exit 1
  fi

  if [ -z "$1" ]; then
    fail "token must not be empty"
  fi

  printf '%s' "$1"
}

build_env_block() {
  local token="$1"
  local quoted_base_url quoted_token
  local quoted_disable_nonessential_traffic quoted_attribution_header

  quoted_base_url="$(quote_for_shell "$BASE_URL")"
  quoted_token="$(quote_for_shell "$token")"
  quoted_disable_nonessential_traffic="$(quote_for_shell "$DISABLE_NONESSENTIAL_TRAFFIC")"
  quoted_attribution_header="$(quote_for_shell "$ATTRIBUTION_HEADER")"

  printf '%s\n' "$BEGIN_MARKER"
  printf 'export ANTHROPIC_BASE_URL=%s\n' "$quoted_base_url"
  printf 'export ANTHROPIC_AUTH_TOKEN=%s\n' "$quoted_token"
  printf 'export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=%s\n' "$quoted_disable_nonessential_traffic"
  printf 'export CLAUDE_CODE_ATTRIBUTION_HEADER=%s\n' "$quoted_attribution_header"
  printf '%s\n' "$END_MARKER"
}

remove_existing_block() {
  local source_file="$1"
  local target_file="$2"

  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin {
      skipping = 1
      next
    }
    $0 == end {
      skipping = 0
      next
    }
    skipping != 1 {
      print
    }
  ' "$source_file" > "$target_file"
}

append_env_block_to_profile() {
  local profile_file="$1"
  local env_block="$2"
  local temp_file

  mkdir -p "$(dirname "$profile_file")"
  touch "$profile_file"

  temp_file="$(mktemp "${TMPDIR:-/tmp}/claude-profile.XXXXXX")"
  remove_existing_block "$profile_file" "$temp_file"

  {
    if [ -s "$temp_file" ]; then
      cat "$temp_file"
      printf '\n'
    fi
    printf '%s\n' "$env_block"
  } > "$profile_file"

  rm -f "$temp_file"
}

profile_files_to_update() {
  printf '%s\n' "$HOME/.zshrc"
  printf '%s\n' "$HOME/.bashrc"

  if [ -f "$HOME/.bash_profile" ]; then
    printf '%s\n' "$HOME/.bash_profile"
    return
  fi

  case "${SHELL:-}" in
    */bash)
      printf '%s\n' "$HOME/.bash_profile"
      ;;
  esac
}

update_shell_profiles() {
  local token="$1"
  local env_block profile_file

  env_block="$(build_env_block "$token")"

  while IFS= read -r profile_file; do
    [ -n "$profile_file" ] || continue
    append_env_block_to_profile "$profile_file" "$env_block"
    info "Updated $profile_file"
  done <<EOF
$(profile_files_to_update | awk '!seen[$0]++')
EOF
}

update_settings_with_python() {
  SETTINGS_JSON_PATH="$1" \
  CLAUDE_INSTALL_BASE_URL="$BASE_URL" \
  CLAUDE_INSTALL_TOKEN="$2" \
  CLAUDE_INSTALL_DISABLE_NONESSENTIAL_TRAFFIC="$DISABLE_NONESSENTIAL_TRAFFIC" \
  CLAUDE_INSTALL_ATTRIBUTION_HEADER="$ATTRIBUTION_HEADER" \
  python3 <<'PY'
import json
import os
import pathlib
import tempfile

path = pathlib.Path(os.environ["SETTINGS_JSON_PATH"]).expanduser()
path.parent.mkdir(parents=True, exist_ok=True)

data = {}
if path.exists() and path.stat().st_size > 0:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"{path} must contain a JSON object")

data["env"] = {
    "ANTHROPIC_BASE_URL": os.environ["CLAUDE_INSTALL_BASE_URL"],
    "ANTHROPIC_AUTH_TOKEN": os.environ["CLAUDE_INSTALL_TOKEN"],
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": os.environ["CLAUDE_INSTALL_DISABLE_NONESSENTIAL_TRAFFIC"],
    "CLAUDE_CODE_ATTRIBUTION_HEADER": os.environ["CLAUDE_INSTALL_ATTRIBUTION_HEADER"],
}

fd, temp_name = tempfile.mkstemp(prefix="settings.", suffix=".json", dir=str(path.parent))
try:
    with os.fdopen(fd, "w", encoding="utf-8") as temp_file:
        json.dump(data, temp_file, ensure_ascii=False, indent=2)
        temp_file.write("\n")
    os.chmod(temp_name, 0o600)
    os.replace(temp_name, path)
finally:
    if os.path.exists(temp_name):
        os.unlink(temp_name)
PY
}

update_settings_with_node() {
  SETTINGS_JSON_PATH="$1" \
  CLAUDE_INSTALL_BASE_URL="$BASE_URL" \
  CLAUDE_INSTALL_TOKEN="$2" \
  CLAUDE_INSTALL_DISABLE_NONESSENTIAL_TRAFFIC="$DISABLE_NONESSENTIAL_TRAFFIC" \
  CLAUDE_INSTALL_ATTRIBUTION_HEADER="$ATTRIBUTION_HEADER" \
  node <<'NODE'
const fs = require("fs");
const pathModule = require("path");

const path = process.env.SETTINGS_JSON_PATH;
const dir = pathModule.dirname(path);
fs.mkdirSync(dir, { recursive: true });

let data = {};
if (fs.existsSync(path) && fs.statSync(path).size > 0) {
  try {
    data = JSON.parse(fs.readFileSync(path, "utf8"));
  } catch (error) {
    console.error(`Invalid JSON in ${path}: ${error.message}`);
    process.exit(1);
  }

  if (data === null || Array.isArray(data) || typeof data !== "object") {
    console.error(`${path} must contain a JSON object`);
    process.exit(1);
  }
}

data.env = {
  ANTHROPIC_BASE_URL: process.env.CLAUDE_INSTALL_BASE_URL,
  ANTHROPIC_AUTH_TOKEN: process.env.CLAUDE_INSTALL_TOKEN,
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: process.env.CLAUDE_INSTALL_DISABLE_NONESSENTIAL_TRAFFIC,
  CLAUDE_CODE_ATTRIBUTION_HEADER: process.env.CLAUDE_INSTALL_ATTRIBUTION_HEADER,
};

const tempPath = pathModule.join(dir, `settings.${process.pid}.json`);
fs.writeFileSync(tempPath, `${JSON.stringify(data, null, 2)}\n`, { mode: 0o600 });
fs.renameSync(tempPath, path);
NODE
}

update_claude_settings() {
  local token="$1"
  local settings_path="$HOME/.claude/settings.json"

  if command -v python3 >/dev/null 2>&1; then
    update_settings_with_python "$settings_path" "$token"
  elif command -v node >/dev/null 2>&1; then
    update_settings_with_node "$settings_path" "$token"
  else
    fail "python3 or node is required to update $settings_path"
  fi

  info "Updated $settings_path"
}

set_launchctl_env() {
  local token="$1"

  if [ "${CLAUDE_INSTALL_SKIP_LAUNCHCTL:-}" = "1" ]; then
    return
  fi

  if ! command -v launchctl >/dev/null 2>&1; then
    return
  fi

  launchctl setenv ANTHROPIC_BASE_URL "$BASE_URL" || true
  launchctl setenv ANTHROPIC_AUTH_TOKEN "$token" || true
  launchctl setenv CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC "$DISABLE_NONESSENTIAL_TRAFFIC" || true
  launchctl setenv CLAUDE_CODE_ATTRIBUTION_HEADER "$ATTRIBUTION_HEADER" || true
}

main() {
  local token

  require_macos
  token="$(parse_token "$@")"

  update_shell_profiles "$token"
  update_claude_settings "$token"
  set_launchctl_env "$token"

  export ANTHROPIC_BASE_URL="$BASE_URL"
  export ANTHROPIC_AUTH_TOKEN="$token"
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="$DISABLE_NONESSENTIAL_TRAFFIC"
  export CLAUDE_CODE_ATTRIBUTION_HEADER="$ATTRIBUTION_HEADER"

  info "Done. Open a new terminal, or run source ~/.zshrc or source ~/.bashrc in the current terminal."
}

main "$@"
