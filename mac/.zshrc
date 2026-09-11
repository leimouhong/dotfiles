########################################
# 0. 全域設定
########################################
# PATH 自動去重（防止子 shell 重複累加）
typeset -U PATH path

########################################
# 1. 互動式與環境
########################################
# 僅在互動式且連接終端的情況載入完整設定
if [[ $- != *i* ]] || [[ ! -t 0 || ! -t 1 ]]; then
  unsetopt promptsubst
  PROMPT='%n@%m %~ %# '
  return
fi

# Homebrew（靜態化，避免 eval fork 開銷；fork-free 偵測 Apple Silicon / Intel prefix）
if [[ -x /opt/homebrew/bin/brew ]]; then
  export HOMEBREW_PREFIX="/opt/homebrew"
elif [[ -x /usr/local/bin/brew ]]; then
  export HOMEBREW_PREFIX="/usr/local"
fi
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  export HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
  export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX"
  export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin${PATH+:$PATH}"
  export MANPATH="$HOMEBREW_PREFIX/share/man${MANPATH+:$MANPATH}:"
  export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"
fi

export EDITOR="code -w"
export LESS='-R'

########################################
# 2. zinit（安全載入）
########################################
[[ -r ${HOMEBREW_PREFIX:-/opt/homebrew}/opt/zinit/zinit.zsh ]] && source ${HOMEBREW_PREFIX:-/opt/homebrew}/opt/zinit/zinit.zsh
zstyle ':zinit:*' list-command 'eza --color=always --group-directories-first'

########################################
# 3. zoxide（快取 init 輸出；先於 Kaku，避免再載入 zsh-z）
########################################
if command -v zoxide >/dev/null 2>&1; then
  _zoxide_cache="$HOME/.cache/zoxide-init.zsh"
  if [[ ! -f "$_zoxide_cache" || "$(command -v zoxide)" -nt "$_zoxide_cache" ]]; then
    mkdir -p "$HOME/.cache"
    _zoxide_tmp="${_zoxide_cache}.$$"
    if zoxide init zsh > "$_zoxide_tmp" && mv -f "$_zoxide_tmp" "$_zoxide_cache"; then
      :
    else
      rm -f "$_zoxide_tmp"
    fi
    unset _zoxide_tmp
  fi

  if [[ -r "$_zoxide_cache" ]]; then
    source "$_zoxide_cache"
    alias j='z'
    if typeset -f __zoxide_zi >/dev/null 2>&1; then
      ji() { __zoxide_zi; }
    fi
  fi
  unset _zoxide_cache
  export _ZO_FZF_OPTS="--layout=reverse --delimiter=\"\\t\" --preview 'p={2}; p=\${p/#~/$HOME}; eza -1 --color=always --group-directories-first \"\$p\" | head -n 50'"
fi

########################################
# 4. Kaku（先載入整合，再套用個人設定）
########################################
_kaku_bin="$HOME/.config/kaku/zsh/bin"
[[ -d "$_kaku_bin" ]] && path=("$_kaku_bin" $path)
unset _kaku_bin

# 僅辨識 Kaku；保留文字選取、AI hooks、SSH 相容處理等功能。
# Tab 由 fzf-tab 管理，避免 Kaku Smart Tab 與補全外掛互相覆蓋。
if [[ "${TERM_PROGRAM:-}" == "Kaku" || "${TERM:-}" == "kaku" ]] &&
   [[ -r "$HOME/.config/kaku/zsh/kaku.zsh" ]]; then
  export KAKU_SMART_TAB_DISABLE=1
  if [[ "${_dotfiles_kaku_loaded:-0}" != 1 ]]; then
    source "$HOME/.config/kaku/zsh/kaku.zsh" && typeset -g _dotfiles_kaku_loaded=1
  fi
fi

########################################
# 5. 歷史
########################################
HISTFILE="$HOME/.zsh_history"

# 記憶體中的歷史應大於實際保存數量
HISTSIZE=120000
SAVEHIST=100000

# 多個終端即時共享歷史
# SHARE_HISTORY 已負責即時寫入；保留較舊重複項至容量不足時再清理。
unsetopt INC_APPEND_HISTORY INC_APPEND_HISTORY_TIME HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# 歷史整理
setopt HIST_IGNORE_DUPS
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS

# 以空格開頭的命令不保存
setopt HIST_IGNORE_SPACE

# ! 歷史展開後先顯示，不直接執行
setopt HIST_VERIFY

# 多終端同時寫入時使用系統檔案鎖
setopt HIST_FCNTL_LOCK

########################################
# 6. fzf
########################################
# fd 作為預設搜尋（有 fallback）
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --hidden --follow --strip-cwd-prefix --exclude .git --exclude node_modules'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd -t d --hidden --follow --strip-cwd-prefix --exclude .git'
else
  export FZF_DEFAULT_COMMAND='find . -type f'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='find . -type d'
fi

export FZF_DEFAULT_OPTS="--ansi --layout=reverse --info=inline --keep-right --bind '?:toggle-preview,ctrl-/:toggle-preview' --preview-window=right,50%,wrap"
export FZF_CTRL_T_OPTS='--preview '\''if [ -d {} ]; then eza -1 --color=always --group-directories-first {} | head -n 50; else head -n 50 {}; fi'\'''
export FZF_ALT_C_OPTS='--preview "eza -1 --color=always --group-directories-first {} | head -n 50"'

# 直接用路徑，避免每次 fork brew --prefix
[[ -r ${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/key-bindings.zsh ]] && source ${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/key-bindings.zsh

# 修改快捷鍵（需在 source key-bindings.zsh 之後）
# 刪除原有的 Ctrl-T 綁定
bindkey -r '^T'
# Opt-X 檔案搜尋（M-x，發送 ESC+x，無前綴等待延遲）
bindkey '\ex' fzf-file-widget
# Opt-C 目錄跳轉（發送 ESC+c，即 \ec）
bindkey '\ec' fzf-cd-widget

########################################
# 7. eza（替換 ls）
########################################
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lh --group-directories-first'
  alias la='eza -lah --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
else
  # macOS BSD ls 不支援 --color，使用 -G
  alias ls='ls -G'
fi

########################################
# 8. 外掛 + 補全系統（Kaku 已提供的跳過，其餘 turbo 延遲載入）
########################################
# 僅在 zinit 成功載入時設定外掛，避免缺 zinit 時噴 command not found
if command -v zinit >/dev/null 2>&1; then
  _kaku_completions="$HOME/.config/kaku/zsh/plugins/zsh-completions/src"
  if (( ${fpath[(Ie)$_kaku_completions]} == 0 )); then
    # 單引號讓檢查在延遲載入時執行，而非排程時展開。
    zinit ice wait"0" silent atinit'
      if ! (( ${+_comps} )); then
        autoload -Uz compinit
        if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
          compinit
        else
          compinit -C
        fi
        [[ ~/.zcompdump -nt ~/.zcompdump.zwc ]] && { zcompile ~/.zcompdump } &!
      fi
      zicdreplay
    '
    zinit light zsh-users/zsh-completions
  else
    zinit cdreplay -q
  fi
  unset _kaku_completions

  # fzf-tab：增強 Tab 補全
  zinit ice wait"0" silent atload'
    zstyle ":fzf-tab:*" fzf-preview "eza -1 --color=always --group-directories-first \$realpath | head -n 50"
    zstyle ":completion:*" menu select
    zstyle ":fzf-tab:*" switch-group "Tab" "Shift-Tab"
  '
  zinit light Aloxaf/fzf-tab

  # 自動建議
  if ! (( ${+functions[_zsh_autosuggest_start]} )); then
    zinit ice wait"0" silent atload"_zsh_autosuggest_start"
    zinit light zsh-users/zsh-autosuggestions
  fi

  # 歷史子字串搜尋（上下鍵）
  zinit ice wait"0" silent atload'
    for _history_keymap in emacs viins; do
      bindkey -M "$_history_keymap" "^[[A" history-substring-search-up
      bindkey -M "$_history_keymap" "^[[B" history-substring-search-down
      bindkey -M "$_history_keymap" "^[OA" history-substring-search-up
      bindkey -M "$_history_keymap" "^[OB" history-substring-search-down
    done
    unset _history_keymap
  '
  zinit light zsh-users/zsh-history-substring-search

  # Kaku 的高亮可能已排到首個 prompt，尚未出現 _zsh_highlight 函式。
  if ! (( ${+functions[_zsh_highlight]} )) &&
     (( ${precmd_functions[(Ie)zsh_syntax_highlighting_defer]} == 0 )) &&
     (( ${precmd_functions[(Ie)fast_syntax_highlighting_defer]} == 0 )); then
    zinit ice wait"1" silent
    zinit light zsh-users/zsh-syntax-highlighting
  fi
else
  # zinit 缺失時的最小補全 fallback，確保仍有 Tab 補全
  if ! (( ${+_comps} )); then
    autoload -Uz compinit && compinit -C
  fi
fi

########################################
# 9. 主題（Kaku 已初始化時沿用，其餘使用快取）
########################################
if (( ${+functions[prompt_starship_precmd]} )); then
  : # 保留 Kaku 的 Starship 初始化與 RPROMPT 修正，避免再註冊 hooks。
elif command -v starship >/dev/null 2>&1 && [[ "${TERM:-}" != "dumb" ]]; then
  _starship_cache="$HOME/.cache/starship-init.zsh"
  if [[ ! -f "$_starship_cache" || "$(command -v starship)" -nt "$_starship_cache" ]]; then
    mkdir -p "$HOME/.cache"
    _starship_tmp="${_starship_cache}.$$"
    if starship init zsh > "$_starship_tmp" && mv -f "$_starship_tmp" "$_starship_cache"; then
      :
    else
      rm -f "$_starship_tmp"
    fi
    unset _starship_tmp
  fi
  if [[ -r "$_starship_cache" ]]; then
    source "$_starship_cache"
  fi
  unset _starship_cache
else
  autoload -Uz promptinit && promptinit
  prompt bart
  unsetopt promptsubst
fi

########################################
# 10. 快捷鍵模式
########################################
bindkey -e
bindkey -M emacs '^[[1;3D' backward-word
bindkey -M emacs '^[[1;3C' forward-word

########################################
# 11. Conda（懶載入，大幅加速啟動）
########################################
conda() {
  unfunction conda
  __conda_setup="$('/opt/anaconda3/bin/conda' 'shell.zsh' 'hook' 2>/dev/null)"
  if [ $? -eq 0 ]; then
    eval "$__conda_setup"
  elif [ -f "/opt/anaconda3/etc/profile.d/conda.sh" ]; then
    . "/opt/anaconda3/etc/profile.d/conda.sh"
  else
    export PATH="/opt/anaconda3/bin:$PATH"
  fi
  unset __conda_setup
  conda "$@"
}

########################################
# 12. NVM（懶載入，大幅加速啟動）
########################################
export NVM_DIR="$HOME/.nvm"

# 懶載入 wrapper：首次呼叫時才真正載入 nvm
_load_nvm() {
  unfunction nvm node npm npx 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { _load_nvm; nvm "$@"; }
node() { _load_nvm; node "$@"; }
npm()  { _load_nvm; npm "$@"; }
npx()  { _load_nvm; npx "$@"; }

# 預先將最新版本的 node bin 加入 PATH，確保即使 nvm 尚未載入也能找到 node
if [[ -d "$NVM_DIR/versions/node" ]]; then
  # (Nn) = NULL_GLOB + 數字排序，避免字典序把 v8 當成比 v18/v20 新
  _nvm_bins=("$NVM_DIR"/versions/node/*/bin(Nn))
  if (( ${#_nvm_bins[@]} )); then
    _nvm_default_bin="${_nvm_bins[-1]}"
    path=($_nvm_default_bin $path)
  fi
  unset _nvm_bins
  unset _nvm_default_bin
fi

########################################
# 13. 其他 PATH
########################################
# /usr/local/bin（VS Code `code` 指令等）
[[ -d /usr/local/bin ]] && path=($path /usr/local/bin)

# Antigravity
[[ -d "$HOME/.antigravity/antigravity/bin" ]] && path=("$HOME/.antigravity/antigravity/bin" $path)

# bun
export BUN_INSTALL="$HOME/.bun"
[[ -d "$BUN_INSTALL/bin" ]] && path=("$BUN_INSTALL/bin" $path)
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# pipx
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)

# 移除不存在的 PATH
path=( ${path:#} )
path=( ${^path}(N-/) )

########################################
# 14. fastfetch
########################################
# 只在頂層互動式 shell 顯示一次，避免每開一個子 shell 都付出啟動成本
if [[ ${SHLVL:-1} -eq 1 ]] && [[ -z ${TMUX-} ]] && [[ -z ${ZELLIJ-} ]] && command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi

########################################
# 15. 機器人網線路由
########################################
proxy_robot() {
  brew services restart tinyproxy || return

  local listen_address
  read -r "listen_address?Mac 已設定的網線 IP（例如 192.168.10.10）： " || return 1
  if ! ifconfig | awk -v ip="$listen_address" '$1 == "inet" && $2 == ip {found=1} END {exit !found}'; then
    print -u2 "此 Mac 未設定 IP：$listen_address，請先設定網線 IP。"
    return 1
  fi

  sudo -v || return
  if ! sudo route -n add -host 192.168.10.102 -interface "$listen_address" >/dev/null 2>&1; then
    sudo route -n change -host 192.168.10.102 -interface "$listen_address" >/dev/null || return
  fi
  printf 'proxy robot\n  Mac   ：%s\n  Robot ：192.168.10.102\n' "$listen_address"
}
