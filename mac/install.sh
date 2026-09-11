#!/usr/bin/env bash
# dotfiles/mac/install.sh (Mac 一鍵配置)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

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
  eza \
  fzf \
  fd \
  zoxide \
  starship \
  fastfetch \
  ripgrep \
  neovim \
  lazygit \
  zellij \
  tinyproxy

########################################
# 機器人 HTTP/HTTPS 代理
########################################
echo "==> 設定機器人使用的 tinyproxy"
(
  # 在子 shell 內處理暫存檔，避免影響後續安裝流程。
  read_ip() {
    local label="$1" default_ip="$2" value
    if [[ ! -t 0 ]]; then
      echo "請在互動式終端執行，以輸入 Mac 和機器人的 IP。" >&2
      return 1
    fi
    read -r -p "$label [$default_ip]：" value
    value="${value:-$default_ip}"
    if [[ ! "$value" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] ||
       ! awk -F. '{for (i=1; i<=NF; i++) if ($i>255) exit 1}' <<< "$value"; then
      echo "無效的 IPv4 位址：$value" >&2
      return 1
    fi
    printf '%s\n' "$value"
  }

  listen_address=$(read_ip "Mac 連接機器人的網線 IP" 192.168.10.10)
  client_address=$(read_ip "機器人的固定 IP" 192.168.10.102)
  if [[ "$listen_address" == "$client_address" ]]; then
    echo "Mac 和機器人不能使用相同 IP。" >&2
    exit 1
  fi

  BREW_PREFIX=$(brew --prefix)
  TINYPROXY_PREFIX=$(brew --prefix tinyproxy)
  CONFIG_DIR="$BREW_PREFIX/etc/tinyproxy"
  CONFIG_FILE="$CONFIG_DIR/tinyproxy.conf"
  WORK_DIR=$(mktemp -d)
  trap 'rm -rf "$WORK_DIR"' EXIT
  if [[ -f "$SCRIPT_DIR/tinyproxy.conf" ]]; then
    cp "$SCRIPT_DIR/tinyproxy.conf" "$WORK_DIR/template.conf"
  else
    curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/mac/tinyproxy.conf -o "$WORK_DIR/template.conf"
  fi
  sed -e "s/@listen_address@/$listen_address/g" \
    -e "s/@client_address@/$client_address/g" \
    -e "s|@brew_prefix@|$BREW_PREFIX|g" \
    -e "s|@tinyproxy_prefix@|$TINYPROXY_PREFIX|g" \
    "$WORK_DIR/template.conf" > "$WORK_DIR/tinyproxy.conf"

  mkdir -p "$CONFIG_DIR"
  if ! cmp -s "$WORK_DIR/tinyproxy.conf" "$CONFIG_FILE"; then
    if [[ -e "$CONFIG_FILE" ]]; then
      BACKUP=$(mktemp "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S).XXXXXX")
      cp -p "$CONFIG_FILE" "$BACKUP"
      echo "   已備份原有設定至 $BACKUP"
    fi
    cp "$WORK_DIR/tinyproxy.conf" "$CONFIG_FILE"
  fi
  echo "==> 已套用 $CONFIG_FILE"

  if ifconfig | awk -v ip="$listen_address" '$1 == "inet" && $2 == ip {found=1} END {exit !found}'; then
    echo "==> 重啟 tinyproxy"
    brew services restart tinyproxy
  else
    echo "   設定已保存，但 Mac 尚無 ${listen_address}，暫不重啟 tinyproxy。"
    echo "   接線並設定網卡 IP 後，執行 brew services restart tinyproxy。"
  fi
)

########################################
# NVM
########################################
if [[ ! -d "$HOME/.nvm" ]]; then
  echo "==> 安裝 NVM"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
else
  echo "==> NVM 已安裝，跳過"
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts

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
