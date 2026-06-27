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
# 3. 歷史
########################################
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_DUPS HIST_REDUCE_BLANKS HIST_VERIFY INC_APPEND_HISTORY SHARE_HISTORY
setopt HIST_IGNORE_SPACE HIST_EXPIRE_DUPS_FIRST
setopt EXTENDED_GLOB AUTO_CD

########################################
# 4. fzf
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
# 5. eza（替換 ls）
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
# 6. zoxide（快取 init 輸出）
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
  export _ZO_FZF_OPTS="--layout=reverse --delimiter=\"\\t\" --with-nth=2.. --preview 'p={2}; p=\${p/#~/$HOME}; eza -1 --color=always --group-directories-first \"\$p\" | head -n 50'"
fi

########################################
# 7. 外掛 + 補全系統（全部 turbo 延遲載入）
########################################
# 僅在 zinit 成功載入時設定外掛，避免缺 zinit 時噴 command not found
if command -v zinit >/dev/null 2>&1; then
  # atinit 在外掛 source 前執行 compinit
  zinit ice wait"0" silent atinit"
    autoload -Uz compinit
    if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
      compinit
    else
      compinit -C
    fi
    # 背景編譯 zcompdump 加速後續啟動
    [[ ~/.zcompdump -nt ~/.zcompdump.zwc ]] && { zcompile ~/.zcompdump } &!
    zinit cdreplay -q
  "
  zinit light zsh-users/zsh-completions

  # fzf-tab：增強 Tab 補全
  zinit ice wait"0" silent atload'
    zstyle ":fzf-tab:*" fzf-preview "eza -1 --color=always --group-directories-first \$realpath | head -n 50"
    zstyle ":completion:*" menu select
    zstyle ":fzf-tab:*" switch-group "Tab" "Shift-Tab"
  '
  zinit light Aloxaf/fzf-tab

  # 自動建議
  zinit ice wait"0" silent atload"_zsh_autosuggest_start"
  zinit light zsh-users/zsh-autosuggestions

  # 歷史子字串搜尋（上下鍵）
  zinit ice wait"0" silent atload'bindkey "^[[A" history-substring-search-up; bindkey "^[[B" history-substring-search-down'
  zinit light zsh-users/zsh-history-substring-search

  # 語法高亮（最後載入）
  zinit ice wait"1" silent
  zinit light zsh-users/zsh-syntax-highlighting
else
  # zinit 缺失時的最小補全 fallback，確保仍有 Tab 補全
  autoload -Uz compinit && compinit -C
fi

########################################
# 8. 主題（快取 starship init 輸出）
########################################
if command -v starship >/dev/null 2>&1 && [[ "${TERM:-}" != "dumb" ]]; then
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
# 9. 快捷鍵模式
########################################
bindkey -e
bindkey -M emacs '^[[1;3D' backward-word
bindkey -M emacs '^[[1;3C' forward-word

########################################
# 10. Conda（懶載入，大幅加速啟動）
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
# 11. NVM（懶載入，大幅加速啟動）
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
# 12. 其他 PATH
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
# 13. fastfetch
########################################
# 只在頂層互動式 shell 顯示一次
# 避免每開一個子 shell 都付出啟動成本
if [[ ${SHLVL:-1} -eq 1 ]] && [[ -z ${TMUX-} ]] && command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi

########################################
# 14. Kaku
########################################
# 只保留 Kaku 的 bin 路徑，方便直接使用其包裝指令
_kaku_bin="$HOME/.config/kaku/zsh/bin"
[[ -d "$_kaku_bin" ]] && path=("$_kaku_bin" $path)
unset _kaku_bin

# 完整的 Kaku shell integration 僅在 Kaku 內載入，避免在其他終端造成不必要的開銷
if [[ -f "$HOME/.config/kaku/zsh/kaku.zsh" ]] && {
  [[ "${TERM_PROGRAM:-}" == "Kaku" ]] || [[ "${TERM:-}" == "kaku" ]] || [[ -n "${WEZTERM_PANE:-}" ]]
}; then
  source "$HOME/.config/kaku/zsh/kaku.zsh"
fi
