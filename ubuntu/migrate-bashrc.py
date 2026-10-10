#!/usr/bin/env python3
"""遷移個人設定名稱與舊 Bash／Robot 代理區塊，保留既有資料。"""

import argparse
import hashlib
from datetime import datetime
import os
from pathlib import Path
import re
import shutil
import tempfile


# 本專案切換為按需環境之前的 ubuntu/.bashrc 歷史版本。
LEGACY_HASHES = {
    "46d74f78b5716c2efc664918d64dbcd2f8c2000d64d0ca48f70c19c8a1a74622",
    "471d6549c76e924a2c2b620facff5a16470db20c1b7df4d346fb3a4d24d76e40",
    "28a210fbc6eceecab09832ffa533135c45bed8721a88bb6d552b91fef17b81e4",
    "bb8b1dc2ed3007d14cd768afe93bbec4d0c79e55a1e6a173244f0bce8b8ad790",
    "e4b592d5f734f381aace07f39e783d7d9077cc9cb2316a1ed97410da517ec1b8",
    "37c9f4619fb66afb3bcedf077d3d8207063fb66ad8dc87dbf058312c1dc232b9",
    "a1284b563cad7fb94e0cda389f395344549451c8ccef06619af7108b01229411",
    "7de76564a94f39a87823945b81488f190e770c6aa9789d13c3e2b040b07b23e2",
    "213c712c374833614e1a38f113bae48101c513df01aef45d2e2a4aff80f90e65",
    "2823974cd334f66bc5cb16d74ddebcf77d14aff6b8a46aba243118d2508484b1",
    "3d5f54af36f5830bfaeb723d2c551e59663456e07a44705b4c25c21851ce1cc4",
    "8e50eb2d8104ec90ae90c02ed091745491a9a62a3962e420506a516505d63ad2",
    "887309b46da7e7b8f953c2ad96e0aa0d01cb52bbedf98a408be36cb4aab3b891",
}


def is_legacy(content):
    return hashlib.sha256(content).hexdigest() in LEGACY_HASHES


def has_personal_init(content):
    return any(marker in content for marker in (
        b"__dotfiles_", b"blesh/ble.sh", b"mouhong/bashrc", b"tom/bashrc",
    ))


def without_robot_proxy(content):
    """只移除舊安裝器明確標記的區塊；不執行其中任何命令。"""
    result = []
    inside = False
    for line in content.splitlines(keepends=True):
        marker = line.rstrip(b"\r\n")
        if marker == b"# >>> dotfiles robot proxy >>>":
            if inside:
                raise SystemExit("Robot 代理區塊標記重疊；.bashrc 未修改。")
            inside = True
        elif marker == b"# <<< dotfiles robot proxy <<<":
            if not inside:
                raise SystemExit("Robot 代理區塊缺少開始標記；.bashrc 未修改。")
            inside = False
        elif not inside:
            result.append(line)
    if inside:
        raise SystemExit("Robot 代理區塊缺少結束標記；.bashrc 未修改。")
    return b"".join(result)


def migrate(home, default=Path("/etc/skel/.bashrc")):
    bashrc = home / ".bashrc"
    if not bashrc.exists():
        return
    content = bashrc.read_bytes()
    cleaned = without_robot_proxy(content)
    original = bashrc
    if not is_legacy(cleaned):
        if has_personal_init(cleaned):
            raise SystemExit(
                "~/.bashrc 含個人環境啟動內容，但不是可核對的舊版檔案，未修改。\n"
                "請先保存自訂內容，從原有 .bashrc.backup.* 還原所需的登入設定，"
                "移除個人環境的自動載入，再重新執行安裝。"
            )
        if cleaned == content:
            return
    else:
        candidates = sorted(
            (entry for entry in home.glob(".bashrc.backup.*")
             if re.fullmatch(r"\.bashrc\.backup\.\d{8}_\d{6}(?:\.[A-Za-z0-9]{6})?", entry.name)
             and entry.is_file() and not entry.is_symlink()),
            reverse=True,
        )
        original = default
        for entry in candidates:
            candidate = without_robot_proxy(entry.read_bytes())
            if not is_legacy(candidate) and not has_personal_init(candidate):
                original = entry
                break
        if not original.is_file():
            raise SystemExit("找不到原有 .bashrc 備份或 /etc/skel/.bashrc；原檔未修改。")
        cleaned = without_robot_proxy(original.read_bytes())

    with tempfile.TemporaryDirectory(prefix=".tom-migrate.", dir=home) as stage:
        replacement = Path(stage) / "bashrc"
        replacement.write_bytes(cleaned)
        shutil.copystat(original, replacement)
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        fd, backup = tempfile.mkstemp(prefix=f".bashrc.before-tom.{stamp}.", dir=home)
        os.close(fd)
        if bashrc.is_symlink():
            Path(backup).unlink()
        shutil.copy2(bashrc, backup, follow_symlinks=False)
        replacement.replace(bashrc)
    if original == bashrc:
        print(f"已移除舊 Robot 代理及 Codex 代理包裝；其餘內容保留。備份：{backup}")
    else:
        print(f"已保存舊版個人 Bash 至 {backup}；登入設定還原自 {original}。")


def migrate_personal_paths(home, *, nvim_only=False):
    """搬移舊資料；先檢查全部目的地，衝突時不覆蓋任何一邊。"""
    roots = {
        "config": Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config"),
        "data": Path(os.environ.get("XDG_DATA_HOME") or home / ".local/share"),
        "state": Path(os.environ.get("XDG_STATE_HOME") or home / ".local/state"),
        "cache": Path(os.environ.get("XDG_CACHE_HOME") or home / ".cache"),
    }
    pairs = []
    if not nvim_only:
        pairs.extend((roots[kind] / "mouhong", roots[kind] / "tom")
                     for kind in ("config", "state"))
    pairs.extend((root / "nvim-mouhong", root / "nvim-tom")
                 for root in roots.values())
    planned = []
    for old, new in dict.fromkeys(pairs):
        if not os.path.lexists(old):
            continue
        if not old.is_dir() and not old.is_symlink():
            raise SystemExit(f"舊個人設定路徑不是目錄：{old}；未遷移。")
        if os.path.lexists(new):
            raise SystemExit(f"新舊路徑同時存在：{old}、{new}。請先整理後重跑；未遷移或覆蓋。")
        planned.append((old, new))

    moved = []
    try:
        for old, new in planned:
            old.rename(new)
            moved.append((old, new))
    except OSError:
        for old, new in reversed(moved):
            new.rename(old)
        raise
    for old, new in moved:
        print(f"已遷移 {old} → {new}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--personal", action="store_true", help="遷移個人 Shell、歷史及 Neovim 路徑")
    mode.add_argument("--nvim", action="store_true", help="只遷移 Neovim 路徑")
    args = parser.parse_args()
    if args.personal or args.nvim:
        migrate_personal_paths(Path.home(), nvim_only=args.nvim)
    else:
        migrate(Path.home())
