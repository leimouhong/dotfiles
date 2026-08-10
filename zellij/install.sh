#!/usr/bin/env bash
# dotfiles/zellij/install.sh (zellij 單獨安裝 + 套用本資料夾的 config.kdl)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_URL="https://raw.githubusercontent.com/leimouhong/dotfiles/main/zellij/config.kdl"
CONFIG_DIR="$HOME/.config/zellij"

# ZELLIJ_REINSTALL=1 可強制重裝已存在的 zellij
ZELLIJ_REINSTALL="${ZELLIJ_REINSTALL:-0}"

# 取得最新版本號（帶 v 前綴）
_latest_v() { curl -s "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/'; }

########################################
# 安裝 zellij
########################################
install_zellij_macos() {
  if command -v brew >/dev/null 2>&1; then
    echo "==> 透過 Homebrew 安裝 zellij"
    brew install zellij
    return
  fi

  echo "==> 未偵測到 Homebrew，改用 GitHub release 安裝 zellij"
  case "$(uname -m)" in
    arm64|aarch64) ZJ_ARCH="aarch64-apple-darwin" ;;
    x86_64)        ZJ_ARCH="x86_64-apple-darwin" ;;
    *) echo "不支援的架構：$(uname -m)"; exit 1 ;;
  esac
  install_zellij_release "$ZJ_ARCH"
}

install_zellij_linux() {
  echo "==> 透過 GitHub release 安裝 zellij"
  case "$(uname -m)" in
    x86_64)        ZJ_ARCH="x86_64-unknown-linux-musl" ;;
    aarch64|arm64) ZJ_ARCH="aarch64-unknown-linux-musl" ;;
    *) echo "不支援的架構：$(uname -m)"; exit 1 ;;
  esac
  install_zellij_release "$ZJ_ARCH"
}

install_zellij_release() {
  local arch="$1" tag tmp
  tag=$(_latest_v zellij-org/zellij)
  if [[ -z "$tag" ]]; then
    echo "無法取得 zellij 最新版本（GitHub API 可能被限流），請稍後再試"
    exit 1
  fi
  echo "   版本：$tag（$arch）"
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/zellij.tar.gz" \
    "https://github.com/zellij-org/zellij/releases/download/${tag}/zellij-${arch}.tar.gz"
  tar -xzf "$tmp/zellij.tar.gz" -C "$tmp" zellij
  sudo install "$tmp/zellij" /usr/local/bin/zellij
  rm -rf "$tmp"
}

if command -v zellij >/dev/null 2>&1 && [[ "$ZELLIJ_REINSTALL" != "1" ]]; then
  echo "==> zellij 已安裝（$(zellij --version)），跳過安裝"
  echo "   要重裝請執行：ZELLIJ_REINSTALL=1 $0"
else
  case "$(uname -s)" in
    Darwin) install_zellij_macos ;;
    Linux)  install_zellij_linux ;;
    *) echo "不支援的作業系統：$(uname -s)"; exit 1 ;;
  esac
fi

########################################
# 套用 zellij 設定
########################################
echo "==> 套用 zellij 設定"
mkdir -p "$CONFIG_DIR"
if [[ -f "$CONFIG_DIR/config.kdl" ]]; then
  cp "$CONFIG_DIR/config.kdl" "$CONFIG_DIR/config.kdl.backup.$(date +%Y%m%d_%H%M%S)"
  echo "   已備份原有 zellij 設定至 ~/.config/zellij/config.kdl.backup.*"
fi
if [[ -f "$SCRIPT_DIR/config.kdl" ]]; then
  cp "$SCRIPT_DIR/config.kdl" "$CONFIG_DIR/config.kdl"
  echo "   已套用 $SCRIPT_DIR/config.kdl"
else
  curl -fsSL "$CONFIG_URL" -o "$CONFIG_DIR/config.kdl"
  echo "   已從 GitHub 下載設定檔"
fi

echo ""
echo "✅ 完成！執行 zellij 啟動（autolock plugin 首次啟動會自動下載）"
