#!/usr/bin/env bash
# dotfiles/mac/install.sh (Mac 一鍵配置)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "此腳本僅供 macOS 使用。" >&2
  exit 1
fi

# Homebrew 已安裝但尚未加入 PATH 時，直接載入既有安裝。
if ! command -v brew >/dev/null 2>&1; then
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$brew_bin" ]]; then
      eval "$("$brew_bin" shellenv)"
      break
    fi
  done
  unset brew_bin
fi

########################################
# Homebrew
########################################
if ! command -v brew >/dev/null 2>&1; then
  echo "==> 安裝 Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # 依晶片載入 brew 路徑
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon
  elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"      # Intel
  fi
else
  echo "==> Homebrew 已安裝，更新中"
  brew update -q
fi

########################################
# 套件安裝
########################################
echo "==> 安裝套件"
brew install \
  zinit \
  bat \
  btop \
  dust \
  git-delta \
  uv \
  eza \
  fzf \
  fd \
  zoxide \
  starship \
  fastfetch \
  ripgrep \
  neovim \
  tree-sitter-cli \
  lazygit \
  zellij

# 只補上缺少的 Git 顯示設定，保留使用者已有的偏好。
git config --global --get core.pager >/dev/null || git config --global core.pager delta
git config --global --get interactive.diffFilter >/dev/null || git config --global interactive.diffFilter 'delta --color-only'
git config --global --get delta.side-by-side >/dev/null || git config --global delta.side-by-side true
git config --global --get delta.line-numbers >/dev/null || git config --global delta.line-numbers true
git config --global --get delta.syntax-theme >/dev/null || git config --global delta.syntax-theme Dracula

########################################
# NVM
########################################
if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  echo "==> 安裝 NVM"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
else
  echo "==> NVM 已安裝，跳過"
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# 重跑時沿用預設 Node，避免無意切換版本而遺失全域工具。
if ! nvm use default; then
  nvm install --lts
fi

########################################
# uv / Neovim providers
########################################
(
  set -euo pipefail

  WORK_DIR=$(mktemp -d)
  trap 'rm -rf "$WORK_DIR"' EXIT
  export PATH="$HOME/.local/bin:$PATH"
  export UV_TOOL_BIN_DIR="$HOME/.local/bin"

  if ! command -v uv >/dev/null 2>&1; then
    brew install uv
  fi

  echo "==> uv 安裝 Python 3.12 與 pynvim"
  # Mac 的使用者命令預設為 Python 3.12。
  uv python install 3.12 --default
  uv python pin --global 3.12
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
  # tree-sitter-cli 已由 Homebrew 安裝。

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
)

########################################
# 套用 zellij 設定
########################################
echo "==> 套用 zellij 設定"
mkdir -p "$HOME/.config/zellij"
if [[ -f "$HOME/.config/zellij/config.kdl" ]]; then
  cp "$HOME/.config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl.backup.$(date +%Y%m%d_%H%M%S)"
  echo "   已備份原有 zellij 設定至 ~/.config/zellij/config.kdl.backup.*"
fi
if [[ -f "$SCRIPT_DIR/../zellij/config.kdl" ]]; then
  cp "$SCRIPT_DIR/../zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
else
  curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/zellij/config.kdl -o "$HOME/.config/zellij/config.kdl"
fi

########################################
# 套用登入 shell 設定
########################################
echo "==> 套用 .zprofile"
if [[ -f "$HOME/.zprofile" ]]; then
  cp "$HOME/.zprofile" "$HOME/.zprofile.backup.$(date +%Y%m%d_%H%M%S)"
fi
if [[ -f "$SCRIPT_DIR/.zprofile" ]]; then
  cp "$SCRIPT_DIR/.zprofile" "$HOME/.zprofile"
else
  curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/mac/.zprofile -o "$HOME/.zprofile"
fi

########################################
# 套用 .zshrc
########################################
echo "==> 套用 .zshrc"
if [[ -f "$HOME/.zshrc" ]]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
  echo "   已備份原有 .zshrc 至 ~/.zshrc.backup.*"
fi
if [[ -f "$SCRIPT_DIR/.zshrc" ]]; then
  cp "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
else
  curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/mac/.zshrc -o "$HOME/.zshrc"
fi

########################################
# Tailscale（最後連線，首次登入不阻塞其他套件安裝）
########################################
echo "==> 安裝並啟用 Tailscale"
TAILSCALE_APP="/Applications/Tailscale.app"
if [[ ! -x "$TAILSCALE_APP/Contents/MacOS/Tailscale" &&
      -x "$HOME/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]]; then
  TAILSCALE_APP="$HOME/Applications/Tailscale.app"
fi

if [[ ! -x "$TAILSCALE_APP/Contents/MacOS/Tailscale" ]] &&
   brew list --formula tailscale >/dev/null 2>&1; then
  # 沿用已安裝的命令列版，避免同時啟動兩種 Tailscale。
  sudo "$(command -v brew)" services start tailscale
  TAILSCALE_CMD=(sudo "$(brew --prefix tailscale)/bin/tailscale")
else
  if [[ ! -x "$TAILSCALE_APP/Contents/MacOS/Tailscale" ]]; then
    brew install --cask --appdir=/Applications tailscale-app
  fi
  open -a "$TAILSCALE_APP"
  echo "   首次使用請在 Tailscale App／系統設定允許網路擴充功能及 VPN，並完成登入。"
  TAILSCALE_CMD=(env TAILSCALE_BE_CLI=1 "$TAILSCALE_APP/Contents/MacOS/Tailscale")
fi

if ! "${TAILSCALE_CMD[@]}" up; then
  echo "Tailscale 尚未完成連線。請處理上方錯誤／登入提示後，執行：" >&2
  printf ' %q' "${TAILSCALE_CMD[@]}" up >&2
  printf '\n' >&2
  exit 1
fi
"${TAILSCALE_CMD[@]}" status
unset TAILSCALE_APP TAILSCALE_CMD

echo ""
echo "✅ 完成！執行 source ~/.zshrc 生效"
