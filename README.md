# dotfiles

macOS 與 Ubuntu 的個人 shell、終端及開發環境設定。LazyVim 設定從 Mac 匯入，部署到 Ubuntu。

## 安裝

macOS：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/mac/install.sh)
```

Ubuntu 22.04 / 24.04（amd64 / arm64）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/ubuntu/install.sh)
```

| 平台 | 安裝內容 |
| --- | --- |
| 共用 | eza、fzf、fd、ripgrep、zoxide、zellij、Neovim、lazygit、nvm 與 Node.js LTS |
| macOS | zsh 設定、zinit、starship、fastfetch |
| Ubuntu | bash 設定、ble.sh、個人 LazyVim 設定、keyd、VS Code、SSH server、C/C++ 開發工具、Python / OpenCV 與常用科學運算套件 |

Ubuntu 22.04 另安裝 ROS 2 Humble；24.04 會略過。腳本會備份既有設定，安裝後重新開啟終端即可。

**Ubuntu 完整安裝會自動安裝 Neovim，並套用 `ubuntu/nvim/config/`，毋須再執行設定安裝腳本。** macOS 會安裝 Neovim 程式，個人設定則沿用現有環境或使用移轉輔助程式搬移。

只裝 zellij（macOS / Linux）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/zellij/install.sh)
```

以上線上命令使用 GitHub 的 `main` 分支。本機修改需先提交並推送，其他機器才會取得新版。

## 專案結構

```text
mac/
├── .zshrc
└── install.sh
ubuntu/
├── .bashrc
├── install.sh
├── keyd/default.conf
└── nvim/
    ├── install.sh
    └── config/          # init.lua、lua/、lazy-lock.json、lazyvim.json 等
zellij/
├── config.kdl
└── install.sh
```

## LazyVim（Ubuntu）

已有 Neovim、只想套用或更新設定時，先關閉 Neovim，再於 Ubuntu 的專案根目錄執行：

```bash
bash ubuntu/nvim/install.sh
```

腳本會先備份 `~/.config/nvim`，再複製專案設定；若有設定 `XDG_CONFIG_HOME`，則使用該目錄。備份位置會顯示在終端。這個腳本只套用設定，不安裝 Neovim 或系統套件，且不會在 macOS 上執行。

不論使用完整安裝或單獨套用，首次開啟 `nvim` 後，等待外掛安裝完成，再執行：

```vim
:Lazy restore
:LazyHealth
```

[`Lazy restore`](https://lazy.folke.io/usage/lockfile) 會按 `lazy-lock.json` 還原外掛版本。缺少的 tree-sitter CLI、語言工具或圖片功能依賴，可依 `LazyHealth` 結果補齊。外掛資料、Python 環境及快取不納入 Git。

## 從 Mac 同步 LazyVim 設定

在 Mac 修改設定後，於專案根目錄回存 Lua 設定、Extras 與外掛版本：

```bash
rsync -av --delete "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lua/" ubuntu/nvim/config/lua/
cp "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lazy-lock.json" \
   "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lazyvim.json" ubuntu/nvim/config/
git diff -- ubuntu/nvim/
git add ubuntu/nvim/
git commit -m "Update LazyVim configuration"
git push
```

`--delete` 會讓專案的 Lua 目錄同步刪除來源已移除的檔案。若修改 `init.lua`、`.neoconf.json` 或 `stylua.toml`，也需回存對應檔案；保留專案 `init.lua` 中依家目錄判斷 Python provider 的寫法。

接著在 Ubuntu 的專案根目錄執行：

```bash
git pull
bash ubuntu/nvim/install.sh
```

## 常用快捷鍵

| 快捷鍵 | 功能 |
| --- | --- |
| `Opt-X` / `Alt-X` | 搜尋檔案，將路徑插入命令列 |
| `Opt-C` / `Alt-C` | 搜尋目錄並切換過去 |
| `↑` / `↓` | 依已輸入文字搜尋 shell 歷史 |
| `Ctrl-R`（Ubuntu） | 用 fzf 搜尋 shell 歷史 |
| 按住 `Tab` + `h/j/k/l`（Ubuntu） | 透過 keyd 輸出方向鍵；單按仍是 Tab |

zellij 使用 tokyo-night 主題；autolock 會在 Neovim、fzf 等程式執行時讓快捷鍵直接傳給程式。
