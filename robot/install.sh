#!/usr/bin/env bash
# Ubuntu 機器人：Mac 代理設定、zellij 與 Codex CLI。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_CODEX=1
INSTALL_ZELLIJ=1
case "${1:-}" in
  --proxy-only) INSTALL_CODEX=0; INSTALL_ZELLIJ=0; shift ;;
  -h|--help)
    echo "用法：bash robot/install.sh [--proxy-only]"
    echo "設定代理並安裝 zellij 與 Codex；--proxy-only 只設定及檢查代理。"
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
    echo "請在互動式終端執行，以輸入 Mac 的網線 IP。" >&2
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

echo "==> Robot 代理設定"
listen_address=$(read_ip "Mac 連接機器人的網線 IP" 192.168.10.10)
client_address=192.168.10.102
if [[ "$listen_address" == "$client_address" ]]; then
  echo "Mac 和機器人不能使用相同 IP。" >&2
  exit 1
fi

WORK_DIR=$(mktemp -d)
CODEX_CONFIG_STAGE=""
trap 'rm -rf "$WORK_DIR"; if [[ -n "$CODEX_CONFIG_STAGE" ]]; then rm -f "$CODEX_CONFIG_STAGE"; fi' EXIT

# 代理設定直接寫入 .bashrc；範本只在安裝期間存放於暫存目錄。
cat > "$WORK_DIR/proxy.template.sh" <<'PROXY_CONFIG'
# >>> dotfiles robot proxy >>>
# ======================================================================
# 【機器人代理設定：開始】由 robot/install.sh 自動管理
# proxy_on：Mac 代理 | proxy_off：系統網路直連
# 重新安裝會更新此區塊，保留 .bashrc 的其他設定。
# ======================================================================

proxy_on() {
  export http_proxy="http://@listen_address@:8888"
  export https_proxy="$http_proxy"
  export HTTP_PROXY="$http_proxy"
  export HTTPS_PROXY="$http_proxy"
  export no_proxy="localhost,127.0.0.1,::1,@listen_address@,@client_address@,10.0.0.0/16,192.168.0.0/16"
  export NO_PROXY="$no_proxy"
  unset all_proxy ALL_PROXY
  printf 'proxy_on -> Mac proxy
  HTTP    : %s
  HTTPS   : %s
  no_proxy: %s
' "$http_proxy" "$https_proxy" "$no_proxy"
}

proxy_off() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY all_proxy ALL_PROXY
  printf 'proxy_off -> Direct system connection
  HTTP    : Not set
  HTTPS   : Not set
  no_proxy: Not set
'
}

# 每次載入 .bashrc 預設 proxy_off。
proxy_off

# Codex 官方獨立安裝程式的預設執行檔目錄。
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# ======================================================================
# 【機器人代理設定：結束】
# ======================================================================
# <<< dotfiles robot proxy <<<
PROXY_CONFIG
sed -e "s/@listen_address@/$listen_address/g" -e "s/@client_address@/$client_address/g" \
  "$WORK_DIR/proxy.template.sh" > "$WORK_DIR/proxy.sh"
# 更新已管理的區塊，保留 .bashrc 的其他內容。
BASHRC_INPUT=/dev/null
if [[ -e "$HOME/.bashrc" ]]; then BASHRC_INPUT="$HOME/.bashrc"; fi
if ! awk -v block="$WORK_DIR/proxy.sh" '
  BEGIN {
    while ((getline line < block) > 0) replacement = replacement line ORS
    close(block)
  }
  $0 == "# >>> dotfiles robot proxy >>>" {
    if (inside) {invalid=1; exit 1}
    if (!found) printf "%s", replacement
    found=1; inside=1; next
  }
  $0 == "# <<< dotfiles robot proxy <<<" {
    if (!inside) {invalid=1; exit 1}
    inside=0; next
  }
  !inside {print}
  END {
    if (invalid || inside) exit 1
    if (!found) printf "%s", replacement
  }
' "$BASHRC_INPUT" > "$WORK_DIR/bashrc"; then
  echo ".bashrc 的 robot proxy 區塊標記不完整，請先修正；原檔未修改。" >&2
  exit 1
fi
bash -n "$WORK_DIR/bashrc"
if ! cmp -s "$WORK_DIR/bashrc" "$HOME/.bashrc"; then
  if [[ -e "$HOME/.bashrc" ]]; then
    BACKUP=$(mktemp "$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S).XXXXXX")
    cp -p "$HOME/.bashrc" "$BACKUP"
    echo "   已備份原有 .bashrc 至 $BACKUP"
  fi
  cat "$WORK_DIR/bashrc" > "$HOME/.bashrc"
fi

# 只載入剛產生的設定，避免執行既有 .bashrc 中的機器人啟動指令。
. "$WORK_DIR/proxy.sh" >/dev/null
# 載入設定會先關閉代理；安裝程序需明確開啟，新終端仍預設直連。
proxy_on >/dev/null
: "${http_proxy:?proxy_on 未設定 http_proxy}" "${https_proxy:?proxy_on 未設定 https_proxy}"

# 安裝所需的套件、zellij 與 Codex 均經由 Mac 下載。
if ! command -v curl >/dev/null 2>&1 || [[ ! -s /etc/ssl/certs/ca-certificates.crt ]]; then
  SUDO=()
  if [[ $EUID -ne 0 ]]; then SUDO=(sudo); fi
  # sudo 通常不保留代理環境變數，故只為這兩次 apt 指令明確傳入。
  APT_PROXY=(-o "Acquire::http::Proxy=$http_proxy" -o "Acquire::https::Proxy=$https_proxy")
  "${SUDO[@]}" apt-get "${APT_PROXY[@]}" update
  "${SUDO[@]}" apt-get "${APT_PROXY[@]}" install -y curl ca-certificates
fi

echo "==> 檢查 Mac 代理 $https_proxy"
if ! curl -fsSL --proxy "$https_proxy" --noproxy "" --connect-timeout 10 --max-time 30 \
  http://tinyproxy.stats/ -o "$WORK_DIR/proxy-stats.html"; then
  echo "代理設定已保存，但無法使用 Mac tinyproxy；請檢查接線、兩端 IP、Allow 和 Mac 防火牆。" >&2
  exit 1
fi

if [[ "$INSTALL_ZELLIJ" == 1 ]]; then
  echo "==> 透過 Mac 代理安裝 zellij 並套用共用設定"
  if [[ -f "$SCRIPT_DIR/../zellij/install.sh" ]]; then
    bash "$SCRIPT_DIR/../zellij/install.sh"
  else
    curl -fsSL --retry 3 https://raw.githubusercontent.com/leimouhong/dotfiles/main/zellij/install.sh \
      -o "$WORK_DIR/zellij-install.sh"
    bash "$WORK_DIR/zellij-install.sh"
  fi
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

  echo "==> 套用 Codex 設定"
  CODEX_CONFIG_DIR="${CODEX_HOME:-$HOME/.codex}"
  # 全域設定必須在 [tui] 之前；內嵌範本也支援 bash <(curl ...) 安裝。
  cat > "$WORK_DIR/codex-config.toml" <<'CODEX_CONFIG'
# ===== 全域設定：必須放在所有 [xxx] 區段之前 =====

# 不詢問命令執行批准
approval_policy = "never"

# 完整檔案及網絡存取權限
sandbox_mode = "danger-full-access"

# 推理強度：需要目前使用的模型支援 xhigh
model_reasoning_effort = "xhigh"

# 即時網頁搜尋
web_search = "live"

# 保存文字日誌，方便排查問題
log_dir = "/home/booster/.codex/log"

# ===== 終端介面設定 =====
[tui]

# 保留終端捲動歷史
alternate_screen = "never"

# 關閉介面動畫
animations = false
CODEX_CONFIG
  mkdir -p "$CODEX_CONFIG_DIR"
  if cmp -s "$WORK_DIR/codex-config.toml" "$CODEX_CONFIG_DIR/config.toml"; then
    echo "   Codex 設定相同，保留現有檔案。"
  else
    # 先準備完整檔案，再備份及替換；不覆寫符號連結的目標。
    CODEX_CONFIG_STAGE=$(mktemp "$CODEX_CONFIG_DIR/.config.toml.XXXXXX")
    cat "$WORK_DIR/codex-config.toml" > "$CODEX_CONFIG_STAGE"
    if [[ -e "$CODEX_CONFIG_DIR/config.toml" || -L "$CODEX_CONFIG_DIR/config.toml" ]]; then
      BACKUP=$(mktemp -d "$CODEX_CONFIG_DIR/backup.$(date +%Y%m%d_%H%M%S).XXXXXX")
      cp -P "$CODEX_CONFIG_DIR/config.toml" "$BACKUP/config.toml"
      echo "   已備份原有 Codex 設定至 $BACKUP/config.toml"
    fi
    mv "$CODEX_CONFIG_STAGE" "$CODEX_CONFIG_DIR/config.toml"
    CODEX_CONFIG_STAGE=""
    echo "   已套用 Codex 設定至 $CODEX_CONFIG_DIR/config.toml"
  fi
fi

printf '\n[完成] 設定已寫入 ~/.bashrc\n'
echo "  載入：source ~/.bashrc"
echo "  開啟：proxy_on"
echo "  關閉：proxy_off"
if [[ "$INSTALL_ZELLIJ" == 1 ]]; then
  echo "  終端工作階段：zellij attach --create robot"
  echo "  首次啟動會下載 autolock 外掛；如需 Mac 代理，先執行 proxy_on。"
fi
if [[ "$INSTALL_CODEX" == 1 ]]; then
  echo "  使用：codex"
fi
