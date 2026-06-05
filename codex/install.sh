#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://ai.oneinstep.com"
MODEL_PROVIDER="OpenAI"
MODEL="gpt-5.5"
REVIEW_MODEL="gpt-5.5"
MODEL_REASONING_EFFORT="xhigh"
PARSED_TOKEN=""

usage() {
  cat <<'EOF'
Usage:
  bash install.sh <OPENAI_API_KEY>
  ./install.sh <OPENAI_API_KEY>

Example:
  bash install.sh 'sk-your-token'

Pass the token exactly as provided. Do not add another sk- prefix.
EOF
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

info() {
  printf '%s\n' "$1"
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
    usage >&2
    exit 1
  fi

  if [ -z "$1" ]; then
    fail "token must not be empty"
  fi

  case "$1" in
    sk-sk-*)
      fail "token starts with sk-sk-. Pass the token exactly as provided, without adding another sk- prefix"
      ;;
  esac

  PARSED_TOKEN="$1"
}

update_config_toml() {
  local config_path="$1"
  local temp_file

  mkdir -p "$(dirname "$config_path")"
  touch "$config_path"
  temp_file="$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX")"

  awk \
    -v model_provider="$MODEL_PROVIDER" \
    -v model="$MODEL" \
    -v review_model="$REVIEW_MODEL" \
    -v reasoning_effort="$MODEL_REASONING_EFFORT" \
    -v base_url="$BASE_URL" '
function trim(value) {
  gsub(/^[ \t]+|[ \t]+$/, "", value)
  return value
}

function is_table(line) {
  return line ~ /^[ \t]*\[[^]]+\][ \t]*(#.*)?$/
}

function table_name(line, value) {
  value = line
  sub(/^[ \t]*\[/, "", value)
  sub(/\][ \t]*(#.*)?$/, "", value)
  return trim(value)
}

function is_openai_provider_table(name) {
  return name == "model_providers.OpenAI" || index(name, "model_providers.OpenAI.") == 1
}

function print_root_config() {
  if (root_config_printed) {
    return
  }

  print "model_provider = \"" model_provider "\""
  print "model = \"" model "\""
  print "review_model = \"" review_model "\""
  print "model_reasoning_effort = \"" reasoning_effort "\""
  print "disable_response_storage = true"
  print "network_access = \"enabled\""
  print "windows_wsl_setup_acknowledged = true"
  print ""
  root_config_printed = 1
}

function print_openai_provider() {
  if (provider_printed) {
    return
  }

  print "[model_providers.OpenAI]"
  print "name = \"OpenAI\""
  print "base_url = \"" base_url "\""
  print "wire_api = \"responses\""
  print "requires_openai_auth = true"
  print ""
  provider_printed = 1
}

BEGIN {
  print_root_config()
}

{
  header = ""
  current_line_is_table = is_table($0)
  if (current_line_is_table) {
    header = table_name($0)
  }

  if (skipping_provider) {
    if (!current_line_is_table || is_openai_provider_table(header)) {
      next
    }
    skipping_provider = 0
  }

  if (current_line_is_table) {
    if (!first_table_seen) {
      print_openai_provider()
      first_table_seen = 1
    }

    if (is_openai_provider_table(header)) {
      skipping_provider = 1
      next
    }

    in_features = header == "features"
    if (in_features) {
      features_seen = 1
      print $0
      print "goals = true"
      next
    }

    print $0
    next
  }

  if (!first_table_seen) {
    if ($0 ~ /^[ \t]*(model_provider|model|review_model|model_reasoning_effort|disable_response_storage|network_access|windows_wsl_setup_acknowledged)[ \t]*=/) {
      next
    }
    print $0
    next
  }

  if (in_features && $0 ~ /^[ \t]*goals[ \t]*=/) {
    next
  }

  print $0
}

END {
  if (!provider_printed) {
    print_openai_provider()
  }

  if (!features_seen) {
    print "[features]"
    print "goals = true"
  }
}
' "$config_path" > "$temp_file"

  mv "$temp_file" "$config_path"
  info "Updated $config_path"
}

update_auth_with_python() {
  CODEX_AUTH_JSON_PATH="$1" \
  CODEX_INSTALL_TOKEN="$2" \
  python3 <<'PY'
import json
import os
import pathlib
import tempfile

path = pathlib.Path(os.environ["CODEX_AUTH_JSON_PATH"]).expanduser()
path.parent.mkdir(parents=True, exist_ok=True)

data = {}
if path.exists() and path.stat().st_size > 0:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"{path} must contain a JSON object")

data["OPENAI_API_KEY"] = os.environ["CODEX_INSTALL_TOKEN"]

fd, temp_name = tempfile.mkstemp(prefix="auth.", suffix=".json", dir=str(path.parent))
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

update_auth_with_node() {
  CODEX_AUTH_JSON_PATH="$1" \
  CODEX_INSTALL_TOKEN="$2" \
  node <<'NODE'
const fs = require("fs");
const pathModule = require("path");

const path = process.env.CODEX_AUTH_JSON_PATH;
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

data.OPENAI_API_KEY = process.env.CODEX_INSTALL_TOKEN;

const tempPath = pathModule.join(dir, `auth.${process.pid}.json`);
fs.writeFileSync(tempPath, `${JSON.stringify(data, null, 2)}\n`, { mode: 0o600 });
fs.renameSync(tempPath, path);
NODE
}

update_auth_json() {
  local auth_path="$1"
  local token="$2"

  if command -v python3 >/dev/null 2>&1; then
    update_auth_with_python "$auth_path" "$token"
  elif command -v node >/dev/null 2>&1; then
    update_auth_with_node "$auth_path" "$token"
  else
    fail "python3 or node is required to update $auth_path"
  fi

  info "Updated $auth_path"
}

main() {
  local token
  local codex_dir

  parse_token "$@"
  token="$PARSED_TOKEN"
  require_macos
  codex_dir="$HOME/.codex"

  mkdir -p "$codex_dir"
  update_config_toml "$codex_dir/config.toml"
  update_auth_json "$codex_dir/auth.json" "$token"

  info "Done. Codex CLI configuration has been updated."
}

main "$@"
