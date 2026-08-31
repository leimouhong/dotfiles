########################################
# 0. 僅互動式 shell 載入
########################################
# ble.sh 必須在最頂端 source（--noattach 模式）
[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --noattach 2>/dev/null

[[ $- != *i* ]] && return

if [[ ${BLE_VERSION-} ]]; then
  # 保留自動補全、Tab 候選選單與選單內過濾；history 搜尋直接逐行讀取 ~/.bash_history。
  bleopt complete_auto_complete=1
  bleopt complete_auto_delay=300
  bleopt complete_auto_history=1
  bleopt complete_menu_complete=1
  bleopt complete_menu_filter=1
fi

########################################
# 1. History
########################################
HISTFILE="$HOME/.bash_history"
HISTSIZE=100000
HISTFILESIZE=100000
HISTCONTROL=ignoredups
HISTIGNORE='ls:cd:pwd:exit:history'
shopt -s histappend cmdhist

if [[ ${BLE_VERSION-} ]]; then
  # 使用 ble.sh 自帶的多終端 history 同步。
  bleopt history_share=1
else
  # 沒有 ble.sh 時才使用 Bash 內建的增量同步。
  __dotfiles_history_sync() {
    builtin history -a
    builtin history -n
  }

  # 同時兼容字串和陣列形式的 PROMPT_COMMAND，並避免重複註冊。
  if [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a "* ]]; then
    __dotfiles_history_sync_registered=
    for __dotfiles_prompt_command in "${PROMPT_COMMAND[@]}"; do
      if [[ "$__dotfiles_prompt_command" == __dotfiles_history_sync ]]; then
        __dotfiles_history_sync_registered=1
        break
      fi
    done
    if [[ ! $__dotfiles_history_sync_registered ]]; then
      PROMPT_COMMAND=(__dotfiles_history_sync "${PROMPT_COMMAND[@]}")
    fi
    unset __dotfiles_history_sync_registered __dotfiles_prompt_command
  elif [[ ${PROMPT_COMMAND-} != *__dotfiles_history_sync* ]]; then
    PROMPT_COMMAND="__dotfiles_history_sync${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
  fi
fi

########################################
# 2. eza
########################################
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lh --group-directories-first'
  alias la='eza -lah --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
else
  alias ls='ls --color=auto'
fi

########################################
# 3. fzf
########################################
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --hidden --follow --exclude .git --exclude node_modules'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd -t d --hidden --follow --exclude .git'
fi

export FZF_DEFAULT_OPTS="--ansi --layout=reverse --info=inline \
  --bind '?:toggle-preview,ctrl-/:toggle-preview' \
  --preview-window=right,50%,wrap"

export FZF_CTRL_T_OPTS='--preview "if [ -d {} ]; then eza -1 --color=always --group-directories-first {}; else head -n 50 {}; fi"'
export FZF_ALT_C_OPTS='--preview "eza -1 --color=always --group-directories-first {}"'

__dotfiles_fzf_history_widget() {
  command -v fzf >/dev/null 2>&1 || return 1

  local histfile="${HISTFILE:-$HOME/.bash_history}"
  [[ -r "$histfile" ]] || return 1
  history -a 2>/dev/null || :

  local selected cmd
  selected="$(
    awk '
      $0 != "" && $0 !~ /^#[0-9]+$/ { entries[++count] = NR "\t" $0 }
      END {
        for (i = count; i >= 1; i--) print entries[i]
      }
    ' "$histfile" | fzf --scheme=history --query "${READLINE_LINE:-}" --delimiter=$'\t' --with-nth=2.. --bind 'ctrl-r:toggle-sort'
  )" || return

  [[ -n "$selected" ]] || return 0
  cmd="${selected#*$'\t'}"
  __dotfiles_history_nav_reset
  READLINE_LINE="$cmd"
  READLINE_POINT=${#READLINE_LINE}
}

__dotfiles_history_nav_reset() {
  __dotfiles_history_nav_active=
  __dotfiles_history_nav_query=
  __dotfiles_history_nav_index=
  __dotfiles_history_nav_current=
}

# ble.sh 直接搜尋記憶體中的 history，避免每按一次方向鍵都重讀整份 ~/.bash_history。
__dotfiles_ble_history_bindings() {
  ble-bind -f up history-substring-search-backward
  ble-bind -f down history-substring-search-forward
}

__dotfiles_ble_fzf_bindings() {
  ble-bind -x 'M-x' 'fzf-file-widget'
  ble-bind -c 'M-c' 'ble/util/eval-stdout "__fzf_cd__"'
  ble-bind -x 'C-r' '__dotfiles_fzf_history_widget'
}

if [[ ${BLE_VERSION-} ]]; then
  __dotfiles_ble_history_bindings
  ble-import -d integration/fzf-completion
  ble-import -d integration/fzf-key-bindings -C __dotfiles_ble_fzf_bindings
elif [[ -r ~/.fzf/shell/key-bindings.bash && -r ~/.fzf/shell/completion.bash ]]; then
  # 沒有 ble.sh 時才退回 fzf 原生 bash 綁定
  source ~/.fzf/shell/key-bindings.bash
  source ~/.fzf/shell/completion.bash

  # 重新綁定快捷鍵（需在 source 之後）
  bind -m emacs -r '\C-t' 2>/dev/null
  bind -m vi-insert -r '\C-t' 2>/dev/null

  # Alt-X 檔案搜尋（ESC+x，與 Mac 一致，無前綴等待延遲）
  bind -m emacs -x '"\ex": fzf-file-widget' 2>/dev/null
  bind -m vi-insert -x '"\ex": fzf-file-widget' 2>/dev/null

  # Alt-C 目錄跳轉（ESC+c）
  bind -m emacs -x '"\ec": __fzf_cd__' 2>/dev/null
  bind -m vi-insert -x '"\ec": __fzf_cd__' 2>/dev/null

  # Ctrl-R 歷史搜尋：直接逐行讀取 ~/.bash_history
  bind -m emacs -x '"\C-r": __dotfiles_fzf_history_widget' 2>/dev/null
  bind -m vi-insert -x '"\C-r": __dotfiles_fzf_history_widget' 2>/dev/null

  # 方向鍵 history 搜尋：使用 Readline 記憶體 history，不重讀整份檔案
  bind -m emacs '"\e[A": history-search-backward' 2>/dev/null
  bind -m emacs '"\e[B": history-search-forward' 2>/dev/null
  bind -m emacs '"\eOA": history-search-backward' 2>/dev/null
  bind -m emacs '"\eOB": history-search-forward' 2>/dev/null
  bind -m vi-insert '"\e[A": history-search-backward' 2>/dev/null
  bind -m vi-insert '"\e[B": history-search-forward' 2>/dev/null
  bind -m vi-insert '"\eOA": history-search-backward' 2>/dev/null
  bind -m vi-insert '"\eOB": history-search-forward' 2>/dev/null
fi

########################################
# 4. 環境變數（PATH 須在 zoxide 之前）
########################################
__dotfiles_path_prepend() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1${PATH:+:$PATH}" ;;
  esac
}

__dotfiles_path_dedupe() {
  local old_ifs="$IFS"
  local entry new_path=""
  IFS=:
  for entry in $PATH; do
    [[ -n "$entry" ]] || continue
    case ":$new_path:" in
      *":$entry:"*) ;;
      *) new_path="${new_path:+$new_path:}$entry" ;;
    esac
  done
  IFS="$old_ifs"
  PATH="$new_path"
}

__dotfiles_path_prepend "$HOME/.local/bin"
export PATH
export EDITOR="nvim"
export LESS='-R'

########################################
# 5. ROS 2 Humble
########################################
if [[ -f /opt/ros/humble/setup.bash ]]; then
  source /opt/ros/humble/setup.bash
fi

########################################
# 6. zoxide（快取 init 輸出）
########################################
if command -v zoxide >/dev/null 2>&1; then
  _zoxide_cache="$HOME/.cache/zoxide-init.bash"
  if [[ ! -f "$_zoxide_cache" || "$(command -v zoxide)" -nt "$_zoxide_cache" ]]; then
    mkdir -p "$HOME/.cache"
    _zoxide_tmp="${_zoxide_cache}.$$"
    if zoxide init bash > "$_zoxide_tmp" && mv -f "$_zoxide_tmp" "$_zoxide_cache"; then
      :
    else
      rm -f "$_zoxide_tmp"
    fi
    unset _zoxide_tmp
  fi
  if [[ -r "$_zoxide_cache" ]]; then
    source "$_zoxide_cache"
    alias j='z'
    if declare -F __zoxide_zi >/dev/null 2>&1; then
      ji() { __zoxide_zi; }
    fi
  fi
  unset _zoxide_cache
fi

########################################
# 7. nvm（Node 版本管理）
########################################
export NVM_DIR="$HOME/.nvm"

# 懶載入 wrapper：首次呼叫時才真正載入 nvm
_load_nvm() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { _load_nvm; nvm "$@"; }
node() { _load_nvm; node "$@"; }
npm()  { _load_nvm; npm "$@"; }
npx()  { _load_nvm; npx "$@"; }

# 預先將最新版本的 node bin 加入 PATH，確保即使 nvm 尚未載入也能找到 node
if [[ -d "$NVM_DIR/versions/node" ]]; then
  # sort -V 以版本序取最新，避免字典序把 v8 當成比 v18/v20 新
  _nvm_default_bin=$(printf '%s\n' "$NVM_DIR"/versions/node/*/bin | sort -V | tail -n1)
  __dotfiles_path_prepend "$_nvm_default_bin"
  unset _nvm_default_bin
fi

__dotfiles_path_dedupe
export PATH
unset -f __dotfiles_path_prepend __dotfiles_path_dedupe

########################################
# 8. ble.sh attach（必須在最底端）
########################################
if [[ ${BLE_VERSION-} ]]; then
  ble-attach
fi
