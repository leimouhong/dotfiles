#!/usr/bin/env bash
# 清理 Mac、Ubuntu、Robot、Codex、zellij 與 LazyVim 安裝腳本產生的備份。
set -euo pipefail

CLEANUP_DRY_RUN=0
CLEANUP_COUNT=0

remove_backup() {
  local backup="$1" flags="$2"

  if [[ "$CLEANUP_DRY_RUN" == 1 ]]; then
    printf '   [預覽] %s\n' "$backup"
  else
    # 一般備份以目前使用者刪除；只有 keyd 備份可能需要 sudo。
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
  local suffix_regex='^[0-9]{8}_[0-9]{6}$'
  suffix_regex="${2:-$suffix_regex}"

  for backup in "$original".backup.*; do
    [[ -f "$backup" || -L "$backup" ]] || continue
    suffix="${backup#"$original.backup."}"
    [[ "$suffix" =~ $suffix_regex ]] || continue
    remove_backup "$backup" -f
  done
}

cleanup_tinyproxy_backups() {
  local brew_prefix
  local suffix_regex='^[0-9]{8}_[0-9]{6}\.[[:alnum:]]{6}$'

  if command -v brew >/dev/null 2>&1; then
    brew_prefix=$(brew --prefix)
    cleanup_file_backups "$brew_prefix/etc/tinyproxy/tinyproxy.conf" "$suffix_regex"
  else
    # brew 未載入 PATH 或已移除時，仍檢查兩種 Mac 的標準安裝位置。
    for brew_prefix in /opt/homebrew /usr/local; do
      cleanup_file_backups "$brew_prefix/etc/tinyproxy/tinyproxy.conf" "$suffix_regex"
    done
  fi
}

cleanup_nvim_backups() {
  local config_home="$1" backup suffix app
  local suffix_regex='^[0-9]{8}_[0-9]{6}\.[[:alnum:]]{6}$'

  for app in nvim nvim-mouhong; do
    for backup in "$config_home/$app".backup.*; do
      [[ -d "$backup" && ! -L "$backup" ]] || continue
      suffix="${backup#"$config_home/$app.backup."}"
      [[ "$suffix" =~ $suffix_regex ]] || continue
      [[ -e "$backup/nvim" || -L "$backup/nvim" ]] || continue
      remove_backup "$backup" -rf
    done
  done
}

cleanup_config_directory_backups() {
  local config_dir="$1" marker="$2" backup suffix
  local suffix_regex='^[0-9]{8}_[0-9]{6}\.[[:alnum:]]{6}$'

  # 只接受安裝器的命名規則，且必須含對應設定檔；不跟隨備份目錄連結。
  for backup in "$config_dir"/backup.*; do
    [[ -d "$backup" && ! -L "$backup" ]] || continue
    suffix="${backup#"$config_dir/backup."}"
    [[ "$suffix" =~ $suffix_regex ]] || continue
    [[ -f "$backup/$marker" || -L "$backup/$marker" ]] || continue
    remove_backup "$backup" -rf
  done
}

cleanup_personal_backups() {
  local config_home="$1" name
  for name in bashrc profile zellij/config.kdl; do
    cleanup_file_backups "$config_home/mouhong/$name" '^[0-9]{8}_[0-9]{6}\.[[:alnum:]]{6}$'
  done
  cleanup_file_backups "$config_home/zellij/config.kdl"
  cleanup_config_directory_backups "$config_home/zellij" config.kdl
  cleanup_config_directory_backups "$config_home/mouhong/zellij" config.kdl
  cleanup_nvim_backups "$config_home"
}

cleanup_bash_migration_backups() {
  local backup suffix
  # 時間戳 + Python tempfile 的八位尾碼；符號連結只刪連結本身。
  for backup in "$HOME"/.bashrc.before-mouhong.*; do
    [[ -f "$backup" || -L "$backup" ]] || continue
    suffix="${backup#"$HOME/.bashrc.before-mouhong."}"
    [[ "$suffix" =~ ^[0-9]{8}_[0-9]{6}\.[a-z0-9_]{8}$ ]] || continue
    remove_backup "$backup" -f
  done
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) CLEANUP_DRY_RUN=1 ;;
      -h|--help)
        cat <<'EOF'
用法：bash scripts/clean-backups.sh [--dry-run]

自動刪除 Mac、Ubuntu、Robot、Codex、zellij 與 LazyVim 安裝腳本產生的設定備份。
包括 mouhong 個人設定、舊 Robot 代理遷移、Fcitx5 輸入法選擇的備份。
不刪除目前設定、歷史記錄、登入資料、Tailscale 狀態或 /opt/neovim 執行檔。
Codex 備份目錄使用 CODEX_HOME，未設定時使用 ~/.codex。
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
  cleanup_file_backups "$HOME/.zprofile"
  cleanup_file_backups "$HOME/.bashrc" '^[0-9]{8}_[0-9]{6}(\.[[:alnum:]]{6})?$'
  cleanup_file_backups "$HOME/.xinputrc" '^[0-9]{8}_[0-9]{6}\.[[:alnum:]]{6}$'
  cleanup_bash_migration_backups
  cleanup_personal_backups "${XDG_CONFIG_HOME:-$HOME/.config}"
  if [[ ${XDG_CONFIG_HOME:-$HOME/.config} != "$HOME/.config" ]]; then
    cleanup_personal_backups "$HOME/.config"
  fi
  cleanup_file_backups /etc/keyd/default.conf '^[0-9]{8}_[0-9]{6}(\.[[:alnum:]]{6})?$'
  cleanup_tinyproxy_backups
  cleanup_config_directory_backups "${CODEX_HOME:-$HOME/.codex}" config.toml

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
