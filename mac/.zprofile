# 登入 shell 先載入 Homebrew，再讓 uv 的使用者 Python 命令優先。
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

typeset -U PATH path
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
export UV_MANAGED_PYTHON=1
