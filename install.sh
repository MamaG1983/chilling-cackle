#!/bin/sh
set -eu

# Grocery Bot participant CLI. No sudo or shell-profile changes.
version='0.1.0a1'
wheel_name='grocerybot-0.1.0a1-py3-none-any.whl'
expected_sha256='c61eb590470d19680f94030796dbf7e43c28ebfdeae10427d8d46ece15d7b49f'
base_url="${GROCERYBOT_DOWNLOAD_BASE:-https://grocerybot.no/static/cli}"

command -v curl >/dev/null 2>&1 || { echo 'Install curl first.' >&2; exit 1; }
python=''
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null; then
    python="$candidate"
    break
  fi
done
[ -n "$python" ] || { echo 'Grocery Bot needs Python 3.11 or newer. Install Python, then run this command again.' >&2; exit 1; }

install_dir="${GROCERYBOT_INSTALL_DIR:-$HOME/.local/share/grocerybot/cli/$version}"
bin_dir="${GROCERYBOT_BIN_DIR:-$HOME/.local/bin}"
if [ -e "$bin_dir/grocerybot" ] || [ -L "$bin_dir/grocerybot" ]; then
  case "$(readlink "$bin_dir/grocerybot" 2>/dev/null || true)" in
    "$install_dir/bin/grocerybot") ;;
    *) echo "An existing grocerybot command is at $bin_dir/grocerybot. Keep it or remove it yourself before installing here." >&2; exit 1 ;;
  esac
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
curl -fsSL "$base_url/grocerybot.whl?sha256=$expected_sha256" -o "$tmp_dir/$wheel_name"
"$python" - "$tmp_dir/$wheel_name" "$expected_sha256" <<'PY'
import hashlib
import pathlib
import sys
if hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest() != sys.argv[2]:
    sys.exit('Download checksum mismatch. Nothing was installed.')
PY
"$python" -m venv "$install_dir"
"$install_dir/bin/python" -m pip install --disable-pip-version-check --force-reinstall "$tmp_dir/$wheel_name"
mkdir -p "$bin_dir"
ln -sf "$install_dir/bin/grocerybot" "$bin_dir/grocerybot"
printf '\nGrocery Bot %s installed.\n' "$version"
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) printf 'For this terminal, run:\n  export PATH="%s:$PATH"\n' "$bin_dir" ;;
esac
printf '\nCreate your bot:\n  grocerybot init my-bot\n  cd my-bot\n  grocerybot login\n  grocerybot play --store easy\n'


