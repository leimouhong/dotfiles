#!/usr/bin/env bash
# 清理 mac/install.sh、ubuntu/install.sh（含 LazyVim）產生的備份。
set -euo pipefail

CLEANUP_DRY_RUN=0
CLEANUP_COUNT=0

remove_backup() {
  local backup="$1" flags="$2"

  if [[ "$CLEANUP_DRY_RUN" == 1 ]]; then
    printf '   [預覽] %s\n' "$backup"
  else
    # 家目錄的備份以目前使用者刪除；只有 keyd 備份可能需要 sudo。
    if [[ "$backup" == /etc/keyd/* && ! -w /etc/keyd ]]; then
      sudo rm "$flags" -- "$backup"
    else
      rm "$flags" -- "$backup"
    fi
    printf '   已刪除 %s\n' "$backup"
  fi
  CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
}

cleanup_file_backups() {
  local original="$1" backup suffix
  local timestamp_regex='^[0-9]{8}_[0-9]{6}$'

  for backup in "$original".backup.*; do
    [[ -f "$backup" || -L "$backup" ]] || continue
    suffix="${backup#"$original.backup."}"
    [[ "$suffix" =~ $timestamp_regex ]] || continue
    remove_backup "$backup" -f
  done
}

cleanup_nvim_backups() {
  local config_home="$1" backup suffix
  local suffix_regex='^[0-9]{8}_[0-9]{6}\.[[:alnum:]]{6}$'

  # LazyVim 使用 mktemp 建立 nvim.backup.<時間戳>.<六位隨機字元> 目錄。
  for backup in "$config_home"/nvim.backup.*; do
    [[ -d "$backup" && ! -L "$backup" ]] || continue
    suffix="${backup#"$config_home/nvim.backup."}"
    [[ "$suffix" =~ $suffix_regex ]] || continue
    remove_backup "$backup" -rf
  done
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) CLEANUP_DRY_RUN=1 ;;
      -h|--help)
        cat <<'EOF'
用法：bash cleanup-backups.sh [--dry-run]

自動刪除 macOS 與 Ubuntu 安裝腳本產生的設定備份。
  --dry-run  只列出符合條件的備份，不刪除
  -h, --help 顯示說明
EOF
        return
        ;;
      *) printf '不支援的參數：%s\n' "$1" >&2; return 1 ;;
    esac
    shift
  done

  echo "==> 檢查安裝腳本產生的備份"
  cleanup_file_backups "$HOME/.zshrc"
  cleanup_file_backups "$HOME/.bashrc"
  cleanup_file_backups "$HOME/.config/zellij/config.kdl"
  cleanup_file_backups /etc/keyd/default.conf
  cleanup_nvim_backups "${XDG_CONFIG_HOME:-$HOME/.config}"

  if [[ "$CLEANUP_COUNT" == 0 ]]; then
    echo "沒有找到符合條件的備份。"
  elif [[ "$CLEANUP_DRY_RUN" == 1 ]]; then
    printf '共找到 %s 個備份，未刪除任何項目。\n' "$CLEANUP_COUNT"
  else
    printf '✅ 已刪除 %s 個備份。\n' "$CLEANUP_COUNT"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
