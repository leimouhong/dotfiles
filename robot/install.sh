#!/usr/bin/env bash
# Ubuntu 機器人：Mac 代理設定與 Codex CLI。
set -euo pipefail

INSTALL_CODEX=1
case "${1:-}" in
  --proxy-only) INSTALL_CODEX=0; shift ;;
  -h|--help)
    echo "用法：bash robot/install.sh [--proxy-only]"
    echo "設定代理並安裝 Codex；--proxy-only 只設定及檢查代理。"
    exit 0
    ;;
esac
if [[ $# -ne 0 ]]; then
  echo "不支援的參數：$*" >&2
  exit 1
fi

if [[ "$(uname -s)" != Linux || ! -r /etc/os-release ]]; then
  echo "此腳本只適用於 Ubuntu 機器人。" >&2
  exit 1
fi
. /etc/os-release
if [[ "${ID:-}" != ubuntu ]]; then
  echo "此腳本只適用於 Ubuntu，目前為 ${ID:-unknown}。" >&2
  exit 1
fi
case "$(uname -m)" in
  x86_64|aarch64|arm64) ;;
  *) echo "不支援的架構：$(uname -m)" >&2; exit 1 ;;
esac

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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/robot"
CONFIG_FILE="$CONFIG_DIR/proxy.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# 線上安裝尚未取得 proxy.sh 時，也需經由 Mac 下載套件及設定。
export http_proxy="http://$listen_address:8888"
export https_proxy="$http_proxy" HTTP_PROXY="$http_proxy" HTTPS_PROXY="$http_proxy"

if ! command -v curl >/dev/null 2>&1 || [[ ! -s /etc/ssl/certs/ca-certificates.crt ]]; then
  SUDO=()
  if [[ $EUID -ne 0 ]]; then SUDO=(sudo); fi
  # sudo 通常不保留代理環境變數，故只為這兩次 apt 指令明確傳入。
  APT_PROXY=(-o "Acquire::http::Proxy=$http_proxy" -o "Acquire::https::Proxy=$https_proxy")
  "${SUDO[@]}" apt-get "${APT_PROXY[@]}" update
  "${SUDO[@]}" apt-get "${APT_PROXY[@]}" install -y curl ca-certificates
fi

if [[ -f "$SCRIPT_DIR/proxy.sh" ]]; then
  cp "$SCRIPT_DIR/proxy.sh" "$WORK_DIR/proxy.template.sh"
else
  curl -fsSL --connect-timeout 10 --max-time 60 \
    https://raw.githubusercontent.com/leimouhong/dotfiles/main/robot/proxy.sh -o "$WORK_DIR/proxy.template.sh"
fi
sed -e "s/@listen_address@/$listen_address/g" -e "s/@client_address@/$client_address/g" \
  "$WORK_DIR/proxy.template.sh" > "$WORK_DIR/proxy.sh"
bash -n "$WORK_DIR/proxy.sh"
mkdir -p "$CONFIG_DIR"
if ! cmp -s "$WORK_DIR/proxy.sh" "$CONFIG_FILE"; then
  if [[ -e "$CONFIG_FILE" ]]; then
    BACKUP=$(mktemp "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S).XXXXXX")
    cp -p "$CONFIG_FILE" "$BACKUP"
    echo "   已備份原有代理設定至 $BACKUP"
  fi
  cp "$WORK_DIR/proxy.sh" "$CONFIG_FILE"
fi

BASHRC_LINE='[[ -r "$HOME/.config/robot/proxy.sh" ]] && . "$HOME/.config/robot/proxy.sh"'
if ! grep -Fqx "$BASHRC_LINE" "$HOME/.bashrc" 2>/dev/null; then
  if [[ -e "$HOME/.bashrc" ]]; then
    BACKUP=$(mktemp "$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S).XXXXXX")
    cp -p "$HOME/.bashrc" "$BACKUP"
    echo "   已備份原有 .bashrc 至 $BACKUP"
  fi
  printf '\n# dotfiles robot proxy\n%s\n' "$BASHRC_LINE" >> "$HOME/.bashrc"
fi

# 不 source 整份 .bashrc，避免其中的互動式判斷或機器人啟動指令影響安裝。
. "$CONFIG_FILE"
echo "==> 檢查 Mac 代理 $https_proxy"
if ! curl -fsSL --proxy "$https_proxy" --noproxy "" --connect-timeout 10 --max-time 30 \
  http://tinyproxy.stats/ -o "$WORK_DIR/proxy-stats.html"; then
  echo "代理設定已保存，但無法使用 Mac tinyproxy；請檢查接線、兩端 IP、Allow 和 Mac 防火牆。" >&2
  exit 1
fi

if [[ "$INSTALL_CODEX" == 1 ]]; then
  if ! command -v codex >/dev/null 2>&1; then
    echo "==> 透過 Mac 代理下載並安裝 Codex CLI"
    curl -fsSL --connect-timeout 10 --max-time 120 \
      https://chatgpt.com/codex/install.sh -o "$WORK_DIR/codex-install.sh"
    sh "$WORK_DIR/codex-install.sh"
  else
    echo "==> Codex 已安裝，跳過安裝"
  fi
  codex --version
fi

echo "✅ 完成！在目前終端執行 source ~/.bashrc 生效。"
if [[ "$INSTALL_CODEX" == 1 ]]; then
  echo "   執行 codex 開始使用。"
fi
