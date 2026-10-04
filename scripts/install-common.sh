#!/usr/bin/env bash
# Mac / Ubuntu 共用：uv Python 3.12 + pynvim，以及目前 Node 的 Neovim provider。
set -euo pipefail

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
export PATH="$HOME/.local/bin:$PATH"
export UV_TOOL_BIN_DIR="$HOME/.local/bin"

if ! command -v uv >/dev/null 2>&1; then
  case "$(uname -s)" in
    Darwin) brew install uv ;;
    Linux)
      curl -fsSL --retry 3 https://astral.sh/uv/install.sh -o "$WORK_DIR/uv-install.sh"
      UV_INSTALL_DIR="$HOME/.local/bin" UV_NO_MODIFY_PATH=1 sh "$WORK_DIR/uv-install.sh"
      ;;
    *) echo "不支援的作業系統。" >&2; exit 1 ;;
  esac
fi

echo "==> uv 安裝 Python 3.12 與 pynvim"
# Mac 的使用者命令預設為 Python 3.12；Ubuntu / ROS 保留系統 python3。
if [[ "$(uname -s)" == Darwin ]]; then
  uv python install 3.12 --default
  uv python pin --global 3.12
else
  uv python install 3.12
fi
PYTHON=$(uv python find --managed-python 3.12)
PIPX_PYNVIM=0
if command -v pipx >/dev/null 2>&1; then
  pipx list --json > "$WORK_DIR/pipx.json"
  PIPX_PYNVIM=$("$PYTHON" -c 'import json, sys; print(int("pynvim" in json.load(open(sys.argv[1]))["venvs"]))' "$WORK_DIR/pipx.json")
fi

if [[ "$PIPX_PYNVIM" == 1 ]]; then
  # 先準備並驗證 uv 環境，再移除 pipx 的 pynvim；不影響其他 pipx 工具。
  UV_TOOL_BIN_DIR="$WORK_DIR/bin" uv tool install --force --managed-python --python 3.12 'pynvim>=0.6.0'
  "$(uv tool dir)/pynvim/bin/python" -c 'import pynvim, sys; assert sys.version_info[:2] == (3, 12)'
  pipx uninstall pynvim
  uv tool install --force --offline --managed-python --python 3.12 'pynvim>=0.6.0'
else
  uv tool install --managed-python --python 3.12 'pynvim>=0.6.0'
fi
"$(uv tool dir)/pynvim/bin/python" -c 'import pynvim, sys; assert sys.version_info[:2] == (3, 12)'

echo "==> 安裝目前 Node 版本的 Neovim provider"
npm install --global neovim
if [[ "$(uname -s)" == Linux ]]; then
  # LazyVim / nvim-treesitter 編譯 parser 使用；Mac 由 Homebrew 提供。
  npm install --global tree-sitter-cli
fi

echo "==> 驗證 Neovim 的 Python / Node provider"
cat > "$WORK_DIR/check-provider.lua" <<'LUA'
vim.g.python3_host_prog = vim.fn.expand("~/.local/bin/pynvim-python")
assert(vim.fn.has("python3") == 1, "Python provider unavailable")
assert(vim.fn.py3eval("6 * 7") == 42, "Python evaluation failed")
local version = vim.fn.py3eval('__import__("sys").version.split()[0]')
assert(version:match("^3%.12%."), "Expected Python 3.12, got " .. version)
vim.cmd([[python3 vim.vars['provider_check'] = 'ok']])
assert(vim.g.provider_check == "ok", "Python RPC failed")
assert(vim.fn["provider#node#Prog"]() ~= "", "Node provider unavailable")
local channel = vim.fn["remote#host#Require"]("node")
assert(channel > 0 and vim.fn.rpcrequest(channel, "poll") == "ok", "Node RPC failed")
print("Neovim providers OK; Python " .. version)
LUA
nvim --headless -u NONE -i NONE -n -l "$WORK_DIR/check-provider.lua"
